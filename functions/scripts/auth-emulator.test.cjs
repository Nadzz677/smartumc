const test = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp, getApps, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { provisionSyntheticUser } = require('../lib/authentication');

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const localEndpoint = (host) => /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host);

if (projectId !== 'demo-smartumc' || !localEndpoint(authHost) || !localEndpoint(firestoreHost)) {
  throw new Error('Auth integration tests require local Auth and Firestore emulators with project demo-smartumc.');
}

const app = getApps()[0] ?? initializeApp({ projectId }, 'smartumc-auth-tests');
const auth = getAuth(app);
const firestore = getFirestore(app);
const studentMatric = 'DIT9999001';
const studentEmail = 'dit9999001@students.smartumc.invalid';
const otherEmail = 'lecturer-test@staff.smartumc.invalid';
const testPassword = 'Synthetic-Only-2026';
let studentUid;
let otherUid;

async function provision(role, identity) {
  return provisionSyntheticUser(
    {
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
        get: async (uid) => {
          const snapshot = await firestore.collection('users').doc(uid).get();
          return snapshot.exists ? snapshot.data() ?? null : null;
        },
        set: (uid, profile) => firestore.collection('users').doc(uid).set(profile, { merge: true }),
        delete: async (uid) => { await firestore.collection('users').doc(uid).delete(); },
      },
      serverTimestamp: () => FieldValue.serverTimestamp(),
    },
    { ...identity, role, password: testPassword, displayName: `Synthetic ${role}` },
  );
}

async function signIn(email) {
  const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: testPassword, returnSecureToken: true }),
  });
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  return body.idToken;
}

async function firestoreRequest(path, { token, method = 'GET', body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return fetch(`http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/${path}`, {
    method,
    headers,
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
}

test('provisions synthetic accounts, issues trusted claims and enforces own-profile reads', async (t) => {
  t.after(async () => {
    for (const uid of [studentUid, otherUid]) {
      if (uid) {
        await firestore.collection('users').doc(uid).delete().catch(() => {});
        await auth.deleteUser(uid).catch(() => {});
      }
    }
    await deleteApp(app);
  });

  const student = await provision('student', { matricNumber: studentMatric });
  const other = await provision('lecturer', { email: otherEmail });
  studentUid = student.uid;
  otherUid = other.uid;

  const studentToken = await signIn(studentEmail);
  const otherToken = await signIn(otherEmail);
  const tokenClaims = JSON.parse(Buffer.from(studentToken.split('.')[1], 'base64url').toString());
  assert.equal(tokenClaims.role, 'student');
  assert.equal(tokenClaims.active, true);

  const anonymousRead = await firestoreRequest(`users/${studentUid}`);
  assert.equal(anonymousRead.status, 403);

  const ownRead = await firestoreRequest(`users/${studentUid}`, { token: studentToken });
  assert.equal(ownRead.status, 200, await ownRead.text());

  const otherRead = await firestoreRequest(`users/${otherUid}`, { token: studentToken });
  assert.equal(otherRead.status, 403);

  const createAttempt = await firestoreRequest('users?documentId=client-created', {
    token: studentToken,
    method: 'POST',
    body: { fields: { role: { stringValue: 'super_admin' }, status: { stringValue: 'active' } } },
  });
  assert.equal(createAttempt.status, 403);

  const updateUrl = `users/${studentUid}?updateMask.fieldPaths=role`;
  const roleChange = await firestoreRequest(updateUrl, {
    token: studentToken,
    method: 'PATCH',
    body: { fields: { role: { stringValue: 'super_admin' } } },
  });
  assert.equal(roleChange.status, 403);

  const profileChange = await firestoreRequest(`users/${studentUid}?updateMask.fieldPaths=displayName`, {
    token: studentToken,
    method: 'PATCH',
    body: { fields: { displayName: { stringValue: 'Forged name' } } },
  });
  assert.equal(profileChange.status, 403);
});
