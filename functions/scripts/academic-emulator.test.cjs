const test = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp, getApps, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { provisionSyntheticUser } = require('../lib/authentication');
const { buildSyntheticAcademicDataset, enrollmentDocumentId, seedSyntheticAcademicDataset } = require('../lib/academics');

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const localEndpoint = (host) => /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host);
if (projectId !== 'demo-smartumc' || !localEndpoint(authHost) || !localEndpoint(firestoreHost)) {
  throw new Error('Academic integration tests require local Auth and Firestore emulators using demo-smartumc.');
}

const app = getApps()[0] ?? initializeApp({ projectId }, 'smartumc-academic-tests');
const auth = getAuth(app);
const db = getFirestore(app);
const password = 'Synthetic-Only-2026';
const identities = [
  { role: 'lecturer', email: 'academic-lecturer@staff.smartumc.invalid', displayName: 'Synthetic Lecturer' },
  { role: 'lecturer', email: 'academic-other@staff.smartumc.invalid', displayName: 'Synthetic Other Lecturer' },
  { role: 'student', matricNumber: 'DIT9999101', displayName: 'Synthetic Student G01' },
  { role: 'student', matricNumber: 'DIT9999102', displayName: 'Synthetic Student G02' },
];
const provisioned = [];

async function provision(identity) {
  return provisionSyntheticUser({
    auth: {
      getUserByEmail: async (email) => {
        try { return await auth.getUserByEmail(email); }
        catch (error) { if (error.code === 'auth/user-not-found') return null; throw error; }
      },
      createUser: (input) => auth.createUser(input),
      setCustomUserClaims: (uid, claims) => auth.setCustomUserClaims(uid, claims),
      deleteUser: (uid) => auth.deleteUser(uid),
    },
    profiles: {
      get: async (uid) => { const snap = await db.collection('users').doc(uid).get(); return snap.exists ? snap.data() : null; },
      set: (uid, profile) => db.collection('users').doc(uid).set(profile, { merge: true }),
      delete: (uid) => db.collection('users').doc(uid).delete(),
    },
    serverTimestamp: () => FieldValue.serverTimestamp(),
  }, { ...identity, password });
}

async function signIn(email) {
  const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  return body.idToken;
}

function documentUrl(path) {
  return `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/${path}`;
}

async function getDocument(path, token) {
  return fetch(documentUrl(path), { headers: token ? { Authorization: `Bearer ${token}` } : {} });
}

async function runQuery(collectionId, field, value, token) {
  return fetch(`http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:runQuery`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ structuredQuery: {
      from: [{ collectionId }],
      where: { fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: { stringValue: value } } },
    } }),
  });
}

test('academic emulator seed, query boundaries, profile regression, and write denial', async (t) => {
  t.after(async () => {
    const docs = buildSyntheticAcademicDataset({ lecturerUid: provisioned[0]?.uid ?? 'none', studentUids: [provisioned[2]?.uid ?? 's1', provisioned[3]?.uid ?? 's2'] });
    await Promise.all(docs.map((doc) => db.collection(doc.collection).doc(doc.id).delete().catch(() => {})));
    for (const user of provisioned) {
      await db.collection('users').doc(user.uid).delete().catch(() => {});
      await auth.deleteUser(user.uid).catch(() => {});
    }
    await deleteApp(app);
  });

  for (const identity of identities) provisioned.push(await provision(identity));
  const lecturer = provisioned[0];
  const otherLecturer = provisioned[1];
  const student = provisioned[2];
  const otherStudent = provisioned[3];
  const documents = buildSyntheticAcademicDataset({ lecturerUid: lecturer.uid, studentUids: [student.uid, otherStudent.uid] });
  const store = {
    get: async (collection, id) => { const snap = await db.collection(collection).doc(id).get(); return snap.exists ? snap.data() : null; },
    create: (collection, id, data) => db.collection(collection).doc(id).create(data),
  };
  assert.deepEqual(await seedSyntheticAcademicDataset(store, documents), { created: 32, alreadyPresent: 0 });
  assert.deepEqual(await seedSyntheticAcademicDataset(store, documents), { created: 0, alreadyPresent: 32 });
  await assert.rejects(db.collection('enrollments').doc(enrollmentDocumentId(documents.find((d) => d.collection === 'courseOfferings').id, student.uid)).create({}), (error) => error.code === 6);

  const studentToken = await signIn(student.email);
  const otherStudentToken = await signIn(otherStudent.email);
  const lecturerToken = await signIn(lecturer.email);
  const otherLecturerToken = await signIn(otherLecturer.email);
  const enrollmentQuery = await runQuery('enrollments', 'studentUid', student.uid, studentToken);
  const enrollmentBody = await enrollmentQuery.text();
  assert.equal(enrollmentQuery.status, 200, enrollmentBody);
  const ownEnrollments = JSON.parse(enrollmentBody);
  assert.equal(ownEnrollments.filter((entry) => entry.document).length, 6);
  assert.equal((await runQuery('enrollments', 'studentUid', otherStudent.uid, studentToken)).status, 403);
  const ownOffering = documents.find((doc) => doc.collection === 'courseOfferings' && doc.data.groupId === 'G01');
  const unrelatedOffering = documents.find((doc) => doc.collection === 'courseOfferings' && doc.data.groupId === 'G02');
  assert.equal((await getDocument(`courseOfferings/${ownOffering.id}`, studentToken)).status, 200);
  assert.equal((await getDocument(`courseOfferings/${unrelatedOffering.id}`, studentToken)).status, 403);
  assert.equal((await runQuery('courseOfferings', 'lecturerUid', lecturer.uid, lecturerToken)).status, 200);
  assert.equal((await getDocument(`courseOfferings/${ownOffering.id}`, lecturerToken)).status, 200);
  assert.equal((await getDocument(`courseOfferings/${ownOffering.id}`, otherLecturerToken)).status, 403);

  assert.equal((await getDocument(`users/${student.uid}`)).status, 403);
  assert.equal((await getDocument(`users/${student.uid}`, studentToken)).status, 200);
  assert.equal((await getDocument(`users/${otherStudent.uid}`, studentToken)).status, 403);
  assert.equal((await getDocument('semesters/DIT-2026-2027-S1')).status, 403);
  assert.equal((await getDocument('semesters/DIT-2026-2027-S1', studentToken)).status, 200);
  assert.equal((await getDocument('courses/BBA1152', studentToken)).status, 200);

  const createAcademic = await fetch(documentUrl('courses?documentId=client-course'), {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
    body: JSON.stringify({ fields: { courseName: { stringValue: 'Forged' } } }),
  });
  assert.equal(createAcademic.status, 403);
  const selfAssignedOffering = await fetch(documentUrl('courseOfferings?documentId=lecturer-self-assigned'), {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${lecturerToken}` },
    body: JSON.stringify({ fields: {
      lecturerUid: { stringValue: lecturer.uid },
      courseId: { stringValue: 'BBA1152' },
      semesterId: { stringValue: 'DIT-2026-2027-S1' },
    } }),
  });
  assert.equal(selfAssignedOffering.status, 403);
  const changeOffering = await fetch(documentUrl(`courseOfferings/${ownOffering.id}?updateMask.fieldPaths=lecturerUid`), {
    method: 'PATCH', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${lecturerToken}` },
    body: JSON.stringify({ fields: { lecturerUid: { stringValue: lecturer.uid } } }),
  });
  assert.equal(changeOffering.status, 403);
  const createEnrollment = await fetch(documentUrl(`enrollments?documentId=${enrollmentDocumentId(ownOffering.id, otherStudent.uid)}`), {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentToken}` },
    body: JSON.stringify({ fields: { studentUid: { stringValue: student.uid } } }),
  });
  assert.equal(createEnrollment.status, 403);
  assert.equal((await getDocument('attendanceSessions/test', lecturerToken)).status, 403);
  assert.equal((await getDocument('bulletins/test', studentToken)).status, 403);
});
