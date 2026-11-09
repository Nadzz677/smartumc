const test = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp, getApps, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { signQrToken } = require('../lib/attendance/domain');

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const loopback = (host) => /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host);
if (projectId !== 'demo-smartumc' || !loopback(authHost) || !loopback(firestoreHost)) {
  throw new Error('Attendance integration tests require local Auth and Firestore emulators on demo-smartumc.');
}
const functionsHost = process.env.SMARTUMC_FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
if (!loopback(functionsHost)) throw new Error('Attendance tests require a loopback Functions Emulator endpoint.');

const runId = Date.now().toString();
const app = getApps()[0] ?? initializeApp({ projectId }, `smartumc-attendance-${runId}`);
const auth = getAuth(app);
const db = getFirestore(app);
const password = 'Synthetic-Only-2026';
const qrSecret = process.env.ATTENDANCE_QR_SIGNING_SECRET;
const identities = [
  { role: 'lecturer', email: `lecturer-${runId}@staff.smartumc.invalid`, displayName: 'Synthetic Lecturer' },
  { role: 'lecturer', email: `other-lecturer-${runId}@staff.smartumc.invalid`, displayName: 'Synthetic Other Lecturer' },
  ...Array.from({ length: 7 }, (_, index) => {
    const matricNumber = `DIT${runId.slice(-5)}${index + 1}`;
    return {
      role: 'student',
      email: `${matricNumber.toLowerCase()}@students.smartumc.invalid`,
      displayName: `Synthetic Student ${index + 1}`,
      matricNumber,
    };
  }),
];
const users = [];
const sessions = [];
const offeringId = `attendance-demo-${runId}`;
const invalidSemesterOfferingId = `attendance-invalid-semester-${runId}`;
const semesterId = `attendance-semester-${runId}`;

async function createIdentity(identity, active = true) {
  const user = await auth.createUser({ email: identity.email, password, displayName: identity.displayName });
  await auth.setCustomUserClaims(user.uid, { role: identity.role, active });
  await db.collection('users').doc(user.uid).set({
    role: identity.role,
    status: active ? 'active' : 'inactive',
    email: identity.email,
    displayName: identity.displayName,
    ...(identity.matricNumber ? { matricNumber: identity.matricNumber } : {}),
    dataClassification: 'synthetic_demo',
  });
  users.push(user);
  return user;
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

function errorCode(error) {
  return error?.body?.error?.status?.toLowerCase().replaceAll('_', '-') ?? '';
}

async function call(name, data, token) {
  const response = await fetch(`http://${functionsHost}/${projectId}/us-central1/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const body = await response.json();
  if (!response.ok || body.error) {
    const error = new Error(body.error?.message ?? `Functions emulator returned HTTP ${response.status}.`);
    error.body = body;
    error.httpStatus = response.status;
    throw error;
  }
  return body.result;
}

async function expectCallError(name, data, token, expectedCode) {
  await assert.rejects(call(name, data, token), (error) => {
    assert.equal(errorCode(error), expectedCode, JSON.stringify(error.body));
    return true;
  });
}

async function createSession(lecturerToken, attendanceMode = 'physical', qrMode = 'static', classDate = '2026-11-10') {
  const result = await call('createAttendanceSession', {
    courseOfferingId: offeringId,
    attendanceMode,
    qrMode,
    occurrence: { classDate, scheduleIndex: 0 },
  }, lecturerToken);
  sessions.push(result.sessionId);
  return result.sessionId;
}

function firestoreDocumentUrl(path) {
  return `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/${path}`;
}

test('attendance callable lifecycle, QR integrity, eligibility, evidence, retrieval, and rules', async (t) => {
  t.after(async () => {
    await Promise.all(sessions.flatMap((sessionId) => users.map((user) =>
      db.collection('attendanceRecords').doc(`${sessionId}_${user.uid}`).delete().catch(() => {}))));
    await Promise.all(sessions.map((sessionId) => db.collection('attendanceSessions').doc(sessionId).delete().catch(() => {})));
    await db.collection('courseOfferings').doc(offeringId).delete().catch(() => {});
    await db.collection('courseOfferings').doc(invalidSemesterOfferingId).delete().catch(() => {});
    await db.collection('semesters').doc(semesterId).delete().catch(() => {});
    await Promise.all(users.flatMap((user) => [
      db.collection('enrollments').doc(`${offeringId}_${user.uid}`).delete().catch(() => {}),
      db.collection('users').doc(user.uid).delete().catch(() => {}),
      auth.deleteUser(user.uid).catch(() => {}),
    ]));
    await deleteApp(app);
  });

  assert.ok(typeof qrSecret === 'string' && Buffer.byteLength(qrSecret) >= 32, 'emulator test needs an ephemeral local QR signing secret');
  const lecturer = await createIdentity(identities[0]);
  const otherLecturer = await createIdentity(identities[1]);
  const students = await Promise.all(identities.slice(2).map((identity) => createIdentity(identity)));
  const inactiveMatric = `DIT${runId.slice(-5)}9`;
  const inactiveEmail = `${inactiveMatric.toLowerCase()}@students.smartumc.invalid`;
  await createIdentity({
    role: 'student', email: inactiveEmail, displayName: 'Synthetic Inactive', matricNumber: inactiveMatric,
  }, false);
  const lecturerToken = await signIn(identities[0].email);
  const otherLecturerToken = await signIn(identities[1].email);
  const studentTokens = await Promise.all(identities.slice(2).map((identity) => signIn(identity.email)));
  const inactiveToken = await signIn(inactiveEmail);

  await db.collection('semesters').doc(semesterId).set({
    academicSession: '2026/2027', semesterNumber: 1, displayName: 'Synthetic attendance test semester',
    startDate: null, endDate: null, status: 'pending_official_dates', dataClassification: 'synthetic_demo',
  });
  await db.collection('courseOfferings').doc(offeringId).set({
    courseId: 'BBA1152', semesterId, lecturerUid: lecturer.uid, groupId: 'G01',
    status: 'representative_synthetic', dataClassification: 'synthetic_demo',
    schedule: [{ scheduleType: 'recurring_weekly', scheduleDay: 'Tuesday', startTime: '09:00', endTime: '10:00', venue: 'BK A1', groupId: 'G01', lecturerUid: lecturer.uid }],
  });
  await db.collection('courseOfferings').doc(invalidSemesterOfferingId).set({
    courseId: 'BBA1152', semesterId: `missing-semester-${runId}`, lecturerUid: lecturer.uid,
    groupId: 'G01', schedule: [{ scheduleType: 'recurring_weekly', scheduleDay: 'Tuesday', startTime: '09:00', endTime: '10:00', venue: 'BK A1', groupId: 'G01', lecturerUid: lecturer.uid }],
  });
  for (const student of students.slice(0, 6)) {
    await db.collection('enrollments').doc(`${offeringId}_${student.uid}`).set({
      studentUid: student.uid, courseOfferingId: offeringId, courseId: 'BBA1152', semesterId,
      groupId: 'G01', status: 'enrolled', dataClassification: 'synthetic_demo',
    });
  }

  await expectCallError('createAttendanceSession', {
    courseOfferingId: offeringId, attendanceMode: 'physical', qrMode: 'static',
    occurrence: { classDate: '2026-11-10', scheduleIndex: 0 },
  }, undefined, 'unauthenticated');
  await expectCallError('createAttendanceSession', {
    courseOfferingId: offeringId, attendanceMode: 'physical', qrMode: 'static',
    occurrence: { classDate: '2026-11-11', scheduleIndex: 0 },
  }, lecturerToken, 'invalid-argument');
  await expectCallError('createAttendanceSession', {
    courseOfferingId: 'missing-offering', attendanceMode: 'physical', qrMode: 'static',
    occurrence: { classDate: '2026-11-10', scheduleIndex: 0 },
  }, lecturerToken, 'not-found');
  await expectCallError('createAttendanceSession', {
    courseOfferingId: invalidSemesterOfferingId, attendanceMode: 'physical', qrMode: 'static',
    occurrence: { classDate: '2026-11-10', scheduleIndex: 0 },
  }, lecturerToken, 'failed-precondition');
  await expectCallError('createAttendanceSession', {
    courseOfferingId: offeringId, attendanceMode: 'physical', qrMode: 'static',
    occurrence: { classDate: '2026-11-10', scheduleIndex: 0 },
  }, studentTokens[0], 'permission-denied');
  await expectCallError('createAttendanceSession', {
    courseOfferingId: offeringId, attendanceMode: 'physical', qrMode: 'static',
    occurrence: { classDate: '2026-11-10', scheduleIndex: 0 },
  }, otherLecturerToken, 'permission-denied');
  await expectCallError('createAttendanceSession', {
    courseOfferingId: offeringId, attendanceMode: 'physical', qrMode: 'static',
    occurrence: { classDate: '2026-11-10', scheduleIndex: 0 },
  }, inactiveToken, 'permission-denied');

  const staticSession = await createSession(lecturerToken);
  await expectCallError('getAttendanceQr', { sessionId: staticSession }, lecturerToken, 'failed-precondition');
  await expectCallError('openAttendanceSession', { sessionId: staticSession }, otherLecturerToken, 'permission-denied');
  assert.equal((await call('openAttendanceSession', { sessionId: staticSession }, lecturerToken)).status, 'open');
  const staticQr = await call('getAttendanceQr', { sessionId: staticSession }, lecturerToken);
  assert.equal(staticQr.mode, 'static');
  assert.equal(staticQr.validUntil, null);
  assert.deepEqual(await call('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: {
    status: 'captured', latitude: 3.139, longitude: 101.687, accuracyMeters: 18, capturedAt: Date.now() - 1000,
  } }, studentTokens[0]), {
    sessionId: staticSession, submissionStatus: 'submitted', locationEvidenceStatus: 'captured',
  });
  await expectCallError('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: { status: 'not_opened' } }, studentTokens[0], 'already-exists');
  await expectCallError('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: { status: 'captured', latitude: 1000, longitude: 2, accuracyMeters: 1, capturedAt: Date.now() } }, studentTokens[1], 'invalid-argument');
  await expectCallError('submitAttendance', { sessionId: staticSession, qrToken: `${staticQr.token}altered`, locationEvidence: { status: 'not_opened' } }, studentTokens[1], 'permission-denied');
  await expectCallError('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: { status: 'not_opened' } }, studentTokens[6], 'permission-denied');
  await call('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: { status: 'not_opened' } }, studentTokens[1]);
  await call('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: { status: 'unavailable' } }, studentTokens[2]);
  await call('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: { status: 'unreliable', latitude: 3.1, longitude: 101.6, accuracyMeters: 2500, capturedAt: Date.now() - 1000 } }, studentTokens[3]);
  await call('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: { status: 'permission_denied' } }, studentTokens[4]);
  await expectCallError('getLecturerSessionAttendance', { sessionId: staticSession }, otherLecturerToken, 'permission-denied');
  const staticRows = await call('getLecturerSessionAttendance', { sessionId: staticSession }, lecturerToken);
  assert.equal(staticRows.students.length, 6);
  assert.equal(staticRows.students.find((row) => row.studentUid === students[0].uid).displayIndicator, 'green');
  assert.equal(staticRows.students.find((row) => row.studentUid === students[1].uid).displayIndicator, 'yellow');
  assert.equal(staticRows.students.find((row) => row.studentUid === students[2].uid).displayIndicator, null);
  await call('closeAttendanceSession', { sessionId: staticSession }, lecturerToken);
  const closedRows = await call('getLecturerSessionAttendance', { sessionId: staticSession }, lecturerToken);
  assert.equal(closedRows.students.find((row) => row.studentUid === students[5].uid).displayIndicator, 'red');
  await expectCallError('openAttendanceSession', { sessionId: staticSession }, lecturerToken, 'failed-precondition');
  await expectCallError('submitAttendance', { sessionId: staticSession, qrToken: staticQr.token, locationEvidence: { status: 'not_opened' } }, studentTokens[5], 'failed-precondition');
  await expectCallError('getAttendanceQr', { sessionId: staticSession }, lecturerToken, 'failed-precondition');

  const dynamicSession = await createSession(lecturerToken, 'physical', 'dynamic');
  await call('openAttendanceSession', { sessionId: dynamicSession }, lecturerToken);
  const dynamicQr = await call('getAttendanceQr', { sessionId: dynamicSession }, lecturerToken);
  assert.equal(dynamicQr.mode, 'dynamic');
  assert.ok(dynamicQr.validUntil > Date.now());
  const expiredToken = signQrToken({ v: 1, sid: dynamicSession, mode: 'dynamic', bucket: Math.floor(Date.now() / 60000) - 1 }, qrSecret);
  await expectCallError('submitAttendance', { sessionId: dynamicSession, qrToken: expiredToken, locationEvidence: { status: 'unavailable' } }, studentTokens[0], 'permission-denied');
  await expectCallError('submitAttendance', { sessionId: dynamicSession, qrToken: dynamicQr.token.slice(0, -1) + 'x', locationEvidence: { status: 'unavailable' } }, studentTokens[0], 'permission-denied');
  const simultaneousSubmissions = await Promise.allSettled([
    call('submitAttendance', { sessionId: dynamicSession, qrToken: dynamicQr.token, locationEvidence: { status: 'unavailable' } }, studentTokens[0]),
    call('submitAttendance', { sessionId: dynamicSession, qrToken: dynamicQr.token, locationEvidence: { status: 'unavailable' } }, studentTokens[0]),
  ]);
  assert.equal(simultaneousSubmissions.filter((result) => result.status === 'fulfilled').length, 1);
  const duplicateResult = simultaneousSubmissions.find((result) => result.status === 'rejected');
  assert.equal(errorCode(duplicateResult.reason), 'already-exists');
  await call('submitAttendance', { sessionId: dynamicSession, qrToken: dynamicQr.token, locationEvidence: { status: 'unreliable' } }, studentTokens[1]);

  const onlineSession = await createSession(lecturerToken, 'online', 'static');
  await call('openAttendanceSession', { sessionId: onlineSession }, lecturerToken);
  const onlineQr = await call('getAttendanceQr', { sessionId: onlineSession }, lecturerToken);
  const onlineResult = await call('submitAttendance', { sessionId: onlineSession, qrToken: onlineQr.token }, studentTokens[0]);
  assert.equal(onlineResult.locationEvidenceStatus, 'not_required');
  const onlineRows = await call('getLecturerSessionAttendance', { sessionId: onlineSession }, lecturerToken);
  assert.equal(onlineRows.students.find((row) => row.studentUid === students[0].uid).displayIndicator, null);
  assert.equal(onlineRows.students.find((row) => row.studentUid === students[0].uid).indicatorContext, 'not_applicable_online');
  await expectCallError('submitAttendance', { sessionId: onlineSession, qrToken: onlineQr.token, locationEvidence: { status: 'captured' } }, studentTokens[1], 'invalid-argument');

  const unauthenticatedRead = await fetch(firestoreDocumentUrl(`attendanceSessions/${staticSession}`));
  const studentRead = await fetch(firestoreDocumentUrl(`attendanceRecords/${staticSession}_${students[0].uid}`), {
    headers: { Authorization: `Bearer ${studentTokens[0]}` },
  });
  const lecturerRead = await fetch(firestoreDocumentUrl(`attendanceRecords/${staticSession}_${students[0].uid}`), {
    headers: { Authorization: `Bearer ${lecturerToken}` },
  });
  assert.equal(unauthenticatedRead.status, 403);
  assert.equal(studentRead.status, 403);
  assert.equal(lecturerRead.status, 403);
  const directStudentWrite = await fetch(`${firestoreDocumentUrl('attendanceRecords?documentId=forged-student-record')}`, {
    method: 'POST', headers: { Authorization: `Bearer ${studentTokens[0]}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { studentUid: { stringValue: students[0].uid } } }),
  });
  const directLecturerWrite = await fetch(`${firestoreDocumentUrl('attendanceRecords?documentId=forged-lecturer-record')}`, {
    method: 'POST', headers: { Authorization: `Bearer ${lecturerToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { studentUid: { stringValue: students[0].uid } } }),
  });
  const directUnauthenticatedWrite = await fetch(`${firestoreDocumentUrl('attendanceSessions?documentId=forged-unauthenticated-session')}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { status: { stringValue: 'open' } } }),
  });
  assert.equal(directStudentWrite.status, 403);
  assert.equal(directLecturerWrite.status, 403);
  assert.equal(directUnauthenticatedWrite.status, 403);
});
