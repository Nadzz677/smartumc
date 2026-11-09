import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/user_role.dart';
import 'academic_models.dart';
import 'academic_repository.dart';

/// Read-only repository for academic records. The Firebase adapters below
/// keep SDK details at the data boundary and allow the repository behavior to
/// be tested with small local fakes.
class FirebaseAcademicRepository implements AcademicRepository {
  FirebaseAcademicRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : this.withDataSources(
         identityProvider: _FirebaseAcademicIdentityProvider(auth),
         dataSource: _FirestoreAcademicDataSource(firestore),
       );

  FirebaseAcademicRepository.withDataSources({
    required AcademicIdentityProvider identityProvider,
    required AcademicDataSource dataSource,
  }) : _identityProvider = identityProvider,
       _dataSource = dataSource;

  final AcademicIdentityProvider _identityProvider;
  final AcademicDataSource _dataSource;

  Future<String> _requireRole(UserRole expected) async {
    final identity = await _identityProvider.getCurrentIdentity();
    if (identity == null) throw StateError('Authentication is required.');
    if (!identity.active || identity.role != expected) {
      throw StateError(
        'The signed-in account is not authorized for this academic data.',
      );
    }
    return identity.uid;
  }

  AcademicLoadState<T> _state<T>(T value) => value is List && value.isEmpty
      ? AcademicLoadState<T>.empty(value)
      : AcademicLoadState<T>.data(value);

  @override
  Future<AcademicLoadState<List<AcademicSemester>>>
  getStudentSemesters() async {
    try {
      final uid = await _requireRole(UserRole.student);
      final enrollments = await _dataSource.getStudentEnrollments(uid);
      final semesterIds = enrollments
          .where(
            (enrollment) =>
                enrollment.studentUid == uid && enrollment.status == 'enrolled',
          )
          .map((enrollment) => enrollment.semesterId)
          .toSet();
      final semesters = <AcademicSemester>[];
      for (final id in semesterIds) {
        final semester = await _dataSource.getSemester(id);
        if (semester == null) {
          throw FormatException('Enrollment references missing semester $id.');
        }
        semesters.add(semester);
      }
      semesters.sort((a, b) => a.semesterNumber.compareTo(b.semesterNumber));
      return _state(semesters);
    } catch (error) {
      return AcademicLoadState<List<AcademicSemester>>.error(error);
    }
  }

  @override
  Future<AcademicLoadState<List<CourseOffering>>> getStudentOfferings({
    String? semesterId,
  }) async {
    try {
      final uid = await _requireRole(UserRole.student);
      final enrollments = await _dataSource.getStudentEnrollments(uid);
      final eligible = enrollments.where(
        (entry) =>
            entry.studentUid == uid &&
            entry.status == 'enrolled' &&
            (semesterId == null || entry.semesterId == semesterId),
      );
      final offerings = <CourseOffering>[];
      for (final enrollment in eligible) {
        final offering = await _dataSource.getOffering(
          enrollment.courseOfferingId,
        );
        if (offering == null) {
          throw FormatException(
            'Enrollment references missing offering ${enrollment.courseOfferingId}.',
          );
        }
        if (offering.id != enrollment.courseOfferingId ||
            offering.courseId != enrollment.courseId ||
            offering.semesterId != enrollment.semesterId ||
            offering.groupId != enrollment.groupId) {
          throw FormatException(
            'Enrollment does not match offering ${enrollment.courseOfferingId}.',
          );
        }
        offerings.add(offering);
      }
      offerings.sort((a, b) => a.id.compareTo(b.id));
      return _state(offerings);
    } catch (error) {
      return AcademicLoadState<List<CourseOffering>>.error(error);
    }
  }

  @override
  Future<AcademicLoadState<List<TimetableEntry>>> getStudentTimetable({
    String? semesterId,
  }) async {
    final offerings = await getStudentOfferings(semesterId: semesterId);
    if (offerings.status == AcademicLoadStatus.error) {
      return AcademicLoadState<List<TimetableEntry>>.error(offerings.error!);
    }
    final entries =
        offerings.value
            ?.expand((offering) => offering.schedule)
            .toList(growable: false) ??
        const <TimetableEntry>[];
    const weekdayOrder = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };
    entries.sort((a, b) {
      final day = (weekdayOrder[a.scheduleDay] ?? 8).compareTo(
        weekdayOrder[b.scheduleDay] ?? 8,
      );
      return day == 0 ? a.startTime.compareTo(b.startTime) : day;
    });
    return _state(entries);
  }

  @override
  Future<AcademicLoadState<List<CourseOffering>>> getLecturerOfferings({
    String? semesterId,
  }) async {
    try {
      final uid = await _requireRole(UserRole.lecturer);
      final assignedOfferings = await _dataSource.getLecturerOfferings(uid);
      final offerings =
          assignedOfferings
              .where(
                (offering) =>
                    offering.lecturerUid == uid &&
                    (semesterId == null || offering.semesterId == semesterId),
              )
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      return _state(offerings);
    } catch (error) {
      return AcademicLoadState<List<CourseOffering>>.error(error);
    }
  }
}

class _FirebaseAcademicIdentityProvider implements AcademicIdentityProvider {
  const _FirebaseAcademicIdentityProvider(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<AcademicIdentity?> getCurrentIdentity() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final token = await user.getIdTokenResult();
    return AcademicIdentity(
      uid: user.uid,
      active: token.claims?['active'] == true,
      role: UserRole.tryFromClaim(token.claims?['role']),
    );
  }
}

class _FirestoreAcademicDataSource implements AcademicDataSource {
  const _FirestoreAcademicDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<AcademicEnrollment>> getStudentEnrollments(
    String studentUid,
  ) async {
    final snapshot = await _firestore
        .collection('enrollments')
        .where('studentUid', isEqualTo: studentUid)
        .get();
    return snapshot.docs
        .map((doc) => AcademicEnrollment.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<AcademicSemester?> getSemester(String semesterId) async {
    final snapshot = await _firestore
        .collection('semesters')
        .doc(semesterId)
        .get();
    return snapshot.exists
        ? AcademicSemester.fromFirestore(semesterId, snapshot.data()!)
        : null;
  }

  @override
  Future<CourseOffering?> getOffering(String offeringId) async {
    final snapshot = await _firestore
        .collection('courseOfferings')
        .doc(offeringId)
        .get();
    return snapshot.exists
        ? CourseOffering.fromFirestore(offeringId, snapshot.data()!)
        : null;
  }

  @override
  Future<List<CourseOffering>> getLecturerOfferings(String lecturerUid) async {
    final snapshot = await _firestore
        .collection('courseOfferings')
        .where('lecturerUid', isEqualTo: lecturerUid)
        .get();
    return snapshot.docs
        .map((doc) => CourseOffering.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
  }
}
