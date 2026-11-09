import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/academics/academic_models.dart';
import 'package:smartumc/core/academics/academic_repository.dart';
import 'package:smartumc/core/academics/firebase_academic_repository.dart';
import 'package:smartumc/core/constants/user_role.dart';

void main() {
  group('FirebaseAcademicRepository', () {
    test('uses the authenticated student UID to retrieve semesters', () async {
      final source = _FakeAcademicDataSource(
        enrollments: [
          _enrollment(studentUid: 'student-1', semesterId: 'S2'),
          _enrollment(studentUid: 'student-1', semesterId: 'S1'),
          _enrollment(
            studentUid: 'student-1',
            semesterId: 'S3',
            status: 'withdrawn',
          ),
          _enrollment(studentUid: 'student-2', semesterId: 'S3'),
        ],
        semesters: {
          'S1': _semester('S1', 1),
          'S2': _semester('S2', 2),
          'S3': _semester('S3', 3),
        },
      );
      final repository = _repository(
        role: UserRole.student,
        uid: 'student-1',
        source: source,
      );

      final result = await repository.getStudentSemesters();

      expect(result.status, AcademicLoadStatus.data);
      expect(result.value!.map((semester) => semester.id), ['S1', 'S2']);
      expect(source.studentQueryUids, ['student-1']);
      expect(source.requestedSemesterIds, {'S1', 'S2'});
    });

    test(
      'filters student enrollments by UID, status, and selected semester',
      () async {
        final source = _FakeAcademicDataSource(
          enrollments: [
            _enrollment(
              studentUid: 'student-1',
              offeringId: 'own-s1',
              semesterId: 'S1',
            ),
            _enrollment(
              studentUid: 'student-1',
              offeringId: 'own-s2',
              semesterId: 'S2',
            ),
            _enrollment(
              studentUid: 'student-1',
              offeringId: 'withdrawn',
              semesterId: 'S1',
              status: 'withdrawn',
            ),
            _enrollment(
              studentUid: 'student-2',
              offeringId: 'other-user',
              semesterId: 'S1',
            ),
          ],
          offerings: {
            'own-s1': _offering('own-s1', semesterId: 'S1'),
            'own-s2': _offering('own-s2', semesterId: 'S2'),
            'withdrawn': _offering('withdrawn', semesterId: 'S1'),
            'other-user': _offering('other-user', semesterId: 'S1'),
          },
        );
        final repository = _repository(
          role: UserRole.student,
          uid: 'student-1',
          source: source,
        );

        final result = await repository.getStudentOfferings(semesterId: 'S1');

        expect(result.status, AcademicLoadStatus.data);
        expect(result.value!.map((offering) => offering.id), ['own-s1']);
        expect(source.studentQueryUids, ['student-1']);
        expect(source.requestedOfferingIds, ['own-s1']);
      },
    );

    test(
      'returns timetable entries only through the student group enrollment',
      () async {
        final entry = _timetableEntry(
          groupId: 'G01',
          lecturerUid: 'lecturer-1',
        );
        final source = _FakeAcademicDataSource(
          enrollments: [
            _enrollment(
              studentUid: 'student-1',
              offeringId: 'G01-offering',
              groupId: 'G01',
            ),
          ],
          offerings: {
            'G01-offering': _offering(
              'G01-offering',
              groupId: 'G01',
              schedule: [entry],
            ),
          },
        );
        final repository = _repository(
          role: UserRole.student,
          uid: 'student-1',
          source: source,
        );

        final result = await repository.getStudentTimetable();

        expect(result.status, AcademicLoadStatus.data);
        expect(result.value, [entry]);
        expect(source.requestedOfferingIds, ['G01-offering']);
      },
    );

    test(
      'filters lecturer offerings to the authenticated lecturer and semester',
      () async {
        final source = _FakeAcademicDataSource(
          lecturerOfferings: [
            _offering(
              'assigned-s1',
              lecturerUid: 'lecturer-1',
              semesterId: 'S1',
            ),
            _offering(
              'assigned-s2',
              lecturerUid: 'lecturer-1',
              semesterId: 'S2',
            ),
            _offering(
              'other-lecturer',
              lecturerUid: 'lecturer-2',
              semesterId: 'S1',
            ),
          ],
        );
        final repository = _repository(
          role: UserRole.lecturer,
          uid: 'lecturer-1',
          source: source,
        );

        final result = await repository.getLecturerOfferings(semesterId: 'S1');

        expect(result.status, AcademicLoadStatus.data);
        expect(result.value!.map((offering) => offering.id), ['assigned-s1']);
        expect(source.lecturerQueryUids, ['lecturer-1']);
      },
    );

    test(
      'returns empty states when a student has no enrollments or a lecturer has no offerings',
      () async {
        final studentSource = _FakeAcademicDataSource();
        final lecturerSource = _FakeAcademicDataSource();
        final studentResult = await _repository(
          role: UserRole.student,
          uid: 'student-empty',
          source: studentSource,
        ).getStudentSemesters();
        final lecturerResult = await _repository(
          role: UserRole.lecturer,
          uid: 'lecturer-empty',
          source: lecturerSource,
        ).getLecturerOfferings();

        expect(studentResult.status, AcademicLoadStatus.empty);
        expect(lecturerResult.status, AcademicLoadStatus.empty);
      },
    );

    test('returns a Firestore data-source failure as an error state', () async {
      final source = _FakeAcademicDataSource(error: StateError('offline'));
      final result = await _repository(
        role: UserRole.student,
        uid: 'student-1',
        source: source,
      ).getStudentSemesters();

      expect(result.status, AcademicLoadStatus.error);
      expect(result.error, isA<StateError>());
    });

    test(
      'rejects missing or unauthorized identity before querying data',
      () async {
        final source = _FakeAcademicDataSource();
        final signedOut = FirebaseAcademicRepository.withDataSources(
          identityProvider: const _FakeAcademicIdentityProvider(null),
          dataSource: source,
        );
        final wrongRole = _repository(
          role: UserRole.lecturer,
          uid: 'lecturer-1',
          source: source,
        );

        expect(
          (await signedOut.getStudentSemesters()).status,
          AcademicLoadStatus.error,
        );
        expect(
          (await wrongRole.getStudentSemesters()).status,
          AcademicLoadStatus.error,
        );
        expect(source.studentQueryUids, isEmpty);
      },
    );

    test(
      'returns an error for an enrollment that conflicts with its offering',
      () async {
        final source = _FakeAcademicDataSource(
          enrollments: [
            _enrollment(
              studentUid: 'student-1',
              offeringId: 'offering-1',
              groupId: 'G01',
            ),
          ],
          offerings: {'offering-1': _offering('offering-1', groupId: 'G02')},
        );
        final result = await _repository(
          role: UserRole.student,
          uid: 'student-1',
          source: source,
        ).getStudentOfferings();

        expect(result.status, AcademicLoadStatus.error);
        expect(result.error, isA<FormatException>());
      },
    );
  });
}

FirebaseAcademicRepository _repository({
  required UserRole role,
  required String uid,
  required _FakeAcademicDataSource source,
}) {
  return FirebaseAcademicRepository.withDataSources(
    identityProvider: _FakeAcademicIdentityProvider(
      AcademicIdentity(uid: uid, active: true, role: role),
    ),
    dataSource: source,
  );
}

AcademicEnrollment _enrollment({
  required String studentUid,
  String offeringId = 'offering-1',
  String courseId = 'course-1',
  String semesterId = 'S1',
  String groupId = 'G01',
  String status = 'enrolled',
}) => AcademicEnrollment(
  id: '${offeringId}_$studentUid',
  studentUid: studentUid,
  courseOfferingId: offeringId,
  courseId: courseId,
  semesterId: semesterId,
  groupId: groupId,
  status: status,
);

AcademicSemester _semester(String id, int number) => AcademicSemester(
  id: id,
  academicSession: '2026/2027',
  semesterNumber: number,
  displayName: 'Synthetic semester $number',
  status: 'pending_official_dates',
);

CourseOffering _offering(
  String id, {
  String courseId = 'course-1',
  String semesterId = 'S1',
  String groupId = 'G01',
  String lecturerUid = 'lecturer-1',
  List<TimetableEntry> schedule = const [],
}) => CourseOffering(
  id: id,
  courseId: courseId,
  semesterId: semesterId,
  groupId: groupId,
  lecturerUid: lecturerUid,
  status: 'representative_synthetic',
  schedule: schedule,
);

TimetableEntry _timetableEntry({
  required String groupId,
  required String lecturerUid,
}) => TimetableEntry(
  scheduleType: 'recurring_weekly',
  scheduleDay: 'Tuesday',
  startTime: '09:00',
  endTime: '10:00',
  courseName: 'Synthetic course',
  groupId: groupId,
  venue: 'BK A1',
  lecturerUid: lecturerUid,
);

class _FakeAcademicIdentityProvider implements AcademicIdentityProvider {
  const _FakeAcademicIdentityProvider(this.identity);

  final AcademicIdentity? identity;

  @override
  Future<AcademicIdentity?> getCurrentIdentity() async => identity;
}

class _FakeAcademicDataSource implements AcademicDataSource {
  _FakeAcademicDataSource({
    this.enrollments = const [],
    this.semesters = const {},
    this.offerings = const {},
    this.lecturerOfferings = const [],
    this.error,
  });

  final List<AcademicEnrollment> enrollments;
  final Map<String, AcademicSemester> semesters;
  final Map<String, CourseOffering> offerings;
  final List<CourseOffering> lecturerOfferings;
  final Object? error;
  final List<String> studentQueryUids = [];
  final List<String> lecturerQueryUids = [];
  final Set<String> requestedSemesterIds = {};
  final List<String> requestedOfferingIds = [];

  void _throwIfNeeded() {
    if (error != null) throw error!;
  }

  @override
  Future<List<AcademicEnrollment>> getStudentEnrollments(
    String studentUid,
  ) async {
    _throwIfNeeded();
    studentQueryUids.add(studentUid);
    return enrollments;
  }

  @override
  Future<AcademicSemester?> getSemester(String semesterId) async {
    _throwIfNeeded();
    requestedSemesterIds.add(semesterId);
    return semesters[semesterId];
  }

  @override
  Future<CourseOffering?> getOffering(String offeringId) async {
    _throwIfNeeded();
    requestedOfferingIds.add(offeringId);
    return offerings[offeringId];
  }

  @override
  Future<List<CourseOffering>> getLecturerOfferings(String lecturerUid) async {
    _throwIfNeeded();
    lecturerQueryUids.add(lecturerUid);
    return lecturerOfferings;
  }
}
