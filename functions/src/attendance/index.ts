import { createHash } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { parseUserRole } from '../authorization';
import {
  AttendanceDomainError,
  buildLocationEvidence,
  createQrToken,
  indicatorForSubmission,
  validateOccurrence,
  validateQrToken,
  validateQrMode,
  validateSessionMode,
} from './domain';

const qrSigningSecret = defineSecret('ATTENDANCE_QR_SIGNING_SECRET');
const firestore = getFirestore();

type Role = 'student' | 'lecturer';

async function requireActiveIdentity(request: CallableRequest<unknown>, role: Role): Promise<string> {
  const authContext = request.auth;
  if (!authContext) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const uid = authContext.uid;
  if (authContext.token.active !== true || parseUserRole(authContext.token.role) !== role) {
    throw new HttpsError('permission-denied', 'The account is not authorized for this operation.');
  }
  const [authUser, profileSnapshot] = await Promise.all([
    getAuth().getUser(uid),
    firestore.collection('users').doc(uid).get(),
  ]);
  const profile = profileSnapshot.data();
  if (
    authUser.disabled || authUser.customClaims?.active !== true ||
    parseUserRole(authUser.customClaims?.role) !== role ||
    !profileSnapshot.exists || profile?.status !== 'active' || profile.role !== role
  ) {
    throw new HttpsError('permission-denied', 'The account is inactive or its trusted role is invalid.');
  }
  return uid;
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim() === '' || value.includes('/')) {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  return value.trim();
}

function rethrow(error: unknown): never {
  if (error instanceof HttpsError) throw error;
  if (error instanceof AttendanceDomainError) throw new HttpsError(error.code, error.message);
  throw new HttpsError('internal', 'Attendance operation failed.');
}

export const createAttendanceSession = onCall(async (request) => {
  try {
    const lecturerUid = await requireActiveIdentity(request, 'lecturer');
    const offeringId = requiredString(request.data?.courseOfferingId, 'courseOfferingId');
    const attendanceMode = validateSessionMode(request.data?.attendanceMode);
    const qrMode = validateQrMode(request.data?.qrMode);
    const offeringSnapshot = await firestore.collection('courseOfferings').doc(offeringId).get();
    if (!offeringSnapshot.exists) throw new HttpsError('not-found', 'Course offering was not found.');
    const offering = offeringSnapshot.data()!;
    if (offering.lecturerUid !== lecturerUid) {
      throw new HttpsError('permission-denied', 'The lecturer is not assigned to this course offering.');
    }
    if (typeof offering.semesterId !== 'string' || offering.semesterId === '') {
      throw new HttpsError('failed-precondition', 'The offering has no valid semester reference.');
    }
    const semesterSnapshot = await firestore.collection('semesters').doc(offering.semesterId).get();
    if (!semesterSnapshot.exists) throw new HttpsError('failed-precondition', 'The offering semester does not exist.');
    const occurrence = validateOccurrence(request.data?.occurrence, offering, semesterSnapshot.data()!);
    const reference = firestore.collection('attendanceSessions').doc();
    const now = FieldValue.serverTimestamp();
    await reference.create({
      courseOfferingId: offeringId,
      semesterId: offering.semesterId,
      lecturerUid,
      attendanceMode,
      qrMode,
      status: 'created',
      occurrence,
      createdAt: now,
      openedAt: null,
      closedAt: null,
      dataClassification: offering.dataClassification === 'synthetic_demo' ? 'synthetic_demo' : null,
    });
    return { sessionId: reference.id, status: 'created', occurrence };
  } catch (error) {
    return rethrow(error);
  }
});

export const openAttendanceSession = onCall(async (request) => {
  try {
    const lecturerUid = await requireActiveIdentity(request, 'lecturer');
    const sessionId = requiredString(request.data?.sessionId, 'sessionId');
    const reference = firestore.collection('attendanceSessions').doc(sessionId);
    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new HttpsError('not-found', 'Attendance session was not found.');
      const session = snapshot.data()!;
      if (session.lecturerUid !== lecturerUid) throw new HttpsError('permission-denied', 'This session belongs to another lecturer.');
      if (session.status !== 'created') throw new HttpsError('failed-precondition', 'Only a newly created session can be opened.');
      transaction.update(reference, { status: 'open', openedAt: FieldValue.serverTimestamp() });
    });
    return { sessionId, status: 'open' };
  } catch (error) {
    return rethrow(error);
  }
});

export const closeAttendanceSession = onCall(async (request) => {
  try {
    const lecturerUid = await requireActiveIdentity(request, 'lecturer');
    const sessionId = requiredString(request.data?.sessionId, 'sessionId');
    const reference = firestore.collection('attendanceSessions').doc(sessionId);
    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new HttpsError('not-found', 'Attendance session was not found.');
      const session = snapshot.data()!;
      if (session.lecturerUid !== lecturerUid) throw new HttpsError('permission-denied', 'This session belongs to another lecturer.');
      if (session.status !== 'open' && session.status !== 'created') {
        throw new HttpsError('failed-precondition', 'Attendance session is already closed.');
      }
      transaction.update(reference, { status: 'closed', closedAt: FieldValue.serverTimestamp() });
    });
    return { sessionId, status: 'closed' };
  } catch (error) {
    return rethrow(error);
  }
});

export const getAttendanceQr = onCall({ secrets: [qrSigningSecret] }, async (request) => {
  try {
    const lecturerUid = await requireActiveIdentity(request, 'lecturer');
    const sessionId = requiredString(request.data?.sessionId, 'sessionId');
    const snapshot = await firestore.collection('attendanceSessions').doc(sessionId).get();
    if (!snapshot.exists) throw new HttpsError('not-found', 'Attendance session was not found.');
    const session = snapshot.data()!;
    if (session.lecturerUid !== lecturerUid) throw new HttpsError('permission-denied', 'This session belongs to another lecturer.');
    if (session.status !== 'open') throw new HttpsError('failed-precondition', 'QR codes are available only for open sessions.');
    if (session.qrMode !== 'static' && session.qrMode !== 'dynamic') {
      throw new HttpsError('failed-precondition', 'Session QR configuration is invalid.');
    }
    const now = Date.now();
    const qr = createQrToken(sessionId, session.qrMode, qrSigningSecret.value(), now);
    return { sessionId, mode: session.qrMode, token: qr.token, validUntil: qr.validUntil };
  } catch (error) {
    return rethrow(error);
  }
});

export const submitAttendance = onCall({ secrets: [qrSigningSecret] }, async (request) => {
  try {
    const studentUid = await requireActiveIdentity(request, 'student');
    const sessionId = requiredString(request.data?.sessionId, 'sessionId');
    const token = request.data?.qrToken;
    if (typeof token !== 'string') throw new HttpsError('invalid-argument', 'qrToken is required.');
    const reference = firestore.collection('attendanceSessions').doc(sessionId);
    const now = Date.now();
    const secret = qrSigningSecret.value();
    const outcome = await firestore.runTransaction(async (transaction) => {
      const sessionSnapshot = await transaction.get(reference);
      if (!sessionSnapshot.exists) throw new HttpsError('not-found', 'Attendance session was not found.');
      const session = sessionSnapshot.data()!;
      if (session.status !== 'open') throw new HttpsError('failed-precondition', 'Attendance session is not open.');
      if (session.qrMode !== 'static' && session.qrMode !== 'dynamic') {
        throw new HttpsError('failed-precondition', 'Session QR configuration is invalid.');
      }
      if (!validateQrToken(token, sessionId, session.qrMode, secret, now)) {
        throw new HttpsError('permission-denied', 'QR token is invalid or expired.');
      }
      const offeringId = requiredString(session.courseOfferingId, 'courseOfferingId');
      const offeringReference = firestore.collection('courseOfferings').doc(offeringId);
      const enrollmentReference = firestore.collection('enrollments').doc(`${offeringId}_${studentUid}`);
      const recordReference = firestore.collection('attendanceRecords').doc(`${sessionId}_${studentUid}`);
      const [offeringSnapshot, enrollmentSnapshot, recordSnapshot] = await Promise.all([
        transaction.get(offeringReference),
        transaction.get(enrollmentReference),
        transaction.get(recordReference),
      ]);
      if (!offeringSnapshot.exists || offeringSnapshot.data()!.semesterId !== session.semesterId) {
        throw new HttpsError('failed-precondition', 'The session course offering is no longer valid.');
      }
      const offering = offeringSnapshot.data()!;
      if (offering.groupId !== session.occurrence?.groupId) {
        throw new HttpsError('failed-precondition', 'The session offering group no longer matches its occurrence.');
      }
      if (!enrollmentSnapshot.exists) throw new HttpsError('permission-denied', 'The student is not enrolled in this offering.');
      const enrollment = enrollmentSnapshot.data()!;
      if (
        enrollment.studentUid !== studentUid || enrollment.courseOfferingId !== offeringId ||
        enrollment.courseId !== offering.courseId || enrollment.semesterId !== session.semesterId ||
        enrollment.groupId !== offering.groupId ||
        enrollment.status !== 'enrolled'
      ) {
        throw new HttpsError('permission-denied', 'The student is not eligible for this session.');
      }
      if (recordSnapshot.exists) throw new HttpsError('already-exists', 'Attendance has already been submitted for this session.');

      const attendanceMode = validateSessionMode(session.attendanceMode);
      const locationEvidence = buildLocationEvidence(attendanceMode, request.data?.locationEvidence, now);
      transaction.create(recordReference, {
        sessionId,
        courseOfferingId: offeringId,
        semesterId: session.semesterId,
        studentUid,
        groupId: enrollment.groupId,
        submissionStatus: 'submitted',
        scanAt: FieldValue.serverTimestamp(),
        qrMode: session.qrMode,
        qrTokenDigest: createHash('sha256').update(token).digest('hex'),
        attendanceMode,
        locationEvidence,
        displayIndicator: indicatorForSubmission(attendanceMode, locationEvidence),
        lecturerJudgement: { status: 'pending', reviewedByUid: null, reviewedAt: null },
      });
      return { sessionId, submissionStatus: 'submitted', locationEvidenceStatus: locationEvidence.status };
    });
    return outcome;
  } catch (error) {
    return rethrow(error);
  }
});

export const getLecturerSessionAttendance = onCall(async (request) => {
  try {
    const lecturerUid = await requireActiveIdentity(request, 'lecturer');
    const sessionId = requiredString(request.data?.sessionId, 'sessionId');
    const sessionSnapshot = await firestore.collection('attendanceSessions').doc(sessionId).get();
    if (!sessionSnapshot.exists) throw new HttpsError('not-found', 'Attendance session was not found.');
    const session = sessionSnapshot.data()!;
    if (session.lecturerUid !== lecturerUid) throw new HttpsError('permission-denied', 'This session belongs to another lecturer.');
    const offeringSnapshot = await firestore.collection('courseOfferings').doc(requiredString(session.courseOfferingId, 'courseOfferingId')).get();
    if (!offeringSnapshot.exists || offeringSnapshot.data()!.lecturerUid !== lecturerUid) {
      throw new HttpsError('permission-denied', 'The lecturer is no longer assigned to this offering.');
    }
    const offeringId = session.courseOfferingId as string;
    const enrollmentsSnapshot = await firestore.collection('enrollments')
      .where('courseOfferingId', '==', offeringId)
      .get();
    const rows = await Promise.all(enrollmentsSnapshot.docs
      .filter((document) => {
        const enrollment = document.data();
        return enrollment.status === 'enrolled'
          && enrollment.semesterId === session.semesterId
          && enrollment.groupId === offeringSnapshot.data()!.groupId
          && typeof enrollment.studentUid === 'string';
      })
      .map(async (enrollmentDoc) => {
      const enrollment = enrollmentDoc.data();
      const studentUid = enrollment.studentUid as string;
      const [recordSnapshot, profileSnapshot] = await Promise.all([
        firestore.collection('attendanceRecords').doc(`${sessionId}_${studentUid}`).get(),
        firestore.collection('users').doc(studentUid).get(),
      ]);
      const record = recordSnapshot.data();
      const profile = profileSnapshot.data();
      const displayIndicator = record
        ? (record.displayIndicator as 'green' | 'yellow' | null)
        : session.status === 'closed' ? 'red' : null;
      const indicatorContext = record
        ? (session.attendanceMode === 'online' ? 'not_applicable_online' : displayIndicator === null ? 'location_outcome_unmapped' : 'submitted')
        : session.status === 'closed' ? 'closed_without_submission' : 'awaiting_submission';
      return {
        studentUid,
        displayName: typeof profile?.displayName === 'string' ? profile.displayName : null,
        matricNumber: typeof profile?.matricNumber === 'string' ? profile.matricNumber : null,
        enrollmentEligible: enrollment.status === 'enrolled',
        attendanceSubmissionStatus: record ? 'submitted' : session.status === 'closed' ? 'not_submitted' : 'pending',
        scanAt: record?.scanAt?.toDate?.().toISOString() ?? null,
        locationEvidence: record?.locationEvidence ?? null,
        displayIndicator,
        indicatorContext,
        lecturerJudgement: record?.lecturerJudgement ?? null,
      };
    }));
    return { sessionId, status: session.status, attendanceMode: session.attendanceMode, students: rows };
  } catch (error) {
    return rethrow(error);
  }
});
