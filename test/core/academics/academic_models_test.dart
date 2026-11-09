import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/academics/academic_models.dart';

void main() {
  test('maps pending semester dates without inventing values', () {
    final semester = AcademicSemester.fromFirestore('DIT-2026-2027-S1', {
      'academicSession': '2026/2027',
      'semesterNumber': 1,
      'displayName': 'Representative Semester 1',
      'status': 'pending_official_dates',
      'startDate': null,
      'endDate': null,
    });

    expect(semester.semesterNumber, 1);
    expect(semester.startDate, isNull);
    expect(semester.endDate, isNull);
  });

  test('maps unconfirmed course references with nullable code and credits', () {
    final course = AcademicCourse.fromFirestore('computer-forensic', {
      'courseName': 'Computer Forensic',
      'programme': 'DIT',
      'confirmationStatus': 'pending_confirmation',
      'courseCode': null,
      'creditHours': null,
    });

    expect(course.courseCode, isNull);
    expect(course.creditHours, isNull);
    expect(
      () => AcademicCourse.fromFirestore('invalid', {
        'courseName': 'Synthetic',
        'programme': 'DIT',
        'confirmationStatus': 'pending_confirmation',
        'creditHours': -1,
      }),
      throwsFormatException,
    );
  });

  test('maps a weekly timetable template and rejects malformed times', () {
    final entry = TimetableEntry.fromMap({
      'scheduleType': 'recurring_weekly',
      'scheduleDay': 'Tuesday',
      'classDate': null,
      'startTime': '09:00',
      'endTime': '10:00',
      'courseName': 'Advanced English II',
      'courseCode': 'BBA1152',
      'groupId': 'G01',
      'venue': 'BK A1',
      'lecturerUid': 'synthetic-lecturer',
      'attendanceStatus': null,
    });
    expect(entry.classDate, isNull);
    expect(entry.scheduleType, 'recurring_weekly');
    expect(
      () => TimetableEntry.fromMap({
        'scheduleType': 'recurring_weekly',
        'scheduleDay': 'Tuesday',
        'startTime': '25:00',
        'endTime': '26:00',
        'courseName': 'Synthetic',
        'groupId': 'G01',
        'venue': 'BK A1',
        'lecturerUid': 'synthetic',
      }),
      throwsFormatException,
    );
    expect(
      () => TimetableEntry.fromMap({
        'scheduleType': 'recurring_weekly',
        'scheduleDay': 'Tuesday',
        'startTime': '09:00',
        'endTime': '09:00',
        'courseName': 'Synthetic',
        'groupId': 'G01',
        'venue': 'BK A1',
        'lecturerUid': 'synthetic',
        'classDate': DateTime(2026, 11, 9),
      }),
      throwsFormatException,
    );
  });

  test('rejects timetable group or lecturer mismatches with its offering', () {
    final offeringData = <String, dynamic>{
      'courseId': 'BBA1152',
      'semesterId': 'DIT-2026-2027-S1',
      'groupId': 'G01',
      'lecturerUid': 'lecturer-1',
      'status': 'representative_synthetic',
      'schedule': [
        {
          'scheduleType': 'recurring_weekly',
          'scheduleDay': 'Tuesday',
          'startTime': '09:00',
          'endTime': '10:00',
          'courseName': 'Advanced English II',
          'groupId': 'G01',
          'venue': 'BK A1',
          'lecturerUid': 'lecturer-1',
        },
      ],
    };

    expect(
      CourseOffering.fromFirestore('offering-1', offeringData).schedule,
      hasLength(1),
    );
    final mismatchedGroup = Map<String, dynamic>.from(offeringData);
    mismatchedGroup['schedule'] = [
      Map<String, dynamic>.from(offeringData['schedule'][0] as Map)
        ..['groupId'] = 'G02',
    ];
    expect(
      () => CourseOffering.fromFirestore('offering-1', mismatchedGroup),
      throwsFormatException,
    );
    final mismatchedLecturer = Map<String, dynamic>.from(offeringData);
    mismatchedLecturer['schedule'] = [
      Map<String, dynamic>.from(offeringData['schedule'][0] as Map)
        ..['lecturerUid'] = 'lecturer-2',
    ];
    expect(
      () => CourseOffering.fromFirestore('offering-1', mismatchedLecturer),
      throwsFormatException,
    );
  });

  test('academic result supports explicit loading, empty and error states', () {
    expect(
      AcademicLoadState<List<String>>.loading().status,
      AcademicLoadStatus.loading,
    );
    expect(
      AcademicLoadState<List<String>>.empty(const []).status,
      AcademicLoadStatus.empty,
    );
    expect(
      AcademicLoadState<List<String>>.error(StateError('offline')).status,
      AcademicLoadStatus.error,
    );
  });
}
