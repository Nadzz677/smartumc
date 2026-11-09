import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicSemester {
  const AcademicSemester({
    required this.id,
    required this.academicSession,
    required this.semesterNumber,
    required this.displayName,
    required this.status,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String academicSession;
  final int semesterNumber;
  final String displayName;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  factory AcademicSemester.fromFirestore(String id, Map<String, dynamic> data) {
    final session = data['academicSession'];
    final number = data['semesterNumber'];
    final name = data['displayName'];
    final status = data['status'];
    if (session is! String ||
        number is! int ||
        name is! String ||
        status is! String) {
      throw const FormatException('Invalid semester document.');
    }
    return AcademicSemester(
      id: id,
      academicSession: session,
      semesterNumber: number,
      displayName: name,
      status: status,
      startDate: _date(data['startDate']),
      endDate: _date(data['endDate']),
    );
  }
}

class AcademicCourse {
  const AcademicCourse({
    required this.id,
    required this.courseName,
    required this.programme,
    this.courseCode,
    this.creditHours,
    this.description,
    required this.confirmationStatus,
  });

  final String id;
  final String? courseCode;
  final String courseName;
  final int? creditHours;
  final String programme;
  final String? description;
  final String confirmationStatus;

  factory AcademicCourse.fromFirestore(String id, Map<String, dynamic> data) {
    if (data['courseName'] is! String ||
        data['programme'] is! String ||
        data['confirmationStatus'] is! String) {
      throw const FormatException('Invalid course document.');
    }
    final code = data['courseCode'];
    final credits = data['creditHours'];
    if ((code != null && code is! String) ||
        (credits != null && credits is! int) ||
        (credits is int && credits <= 0)) {
      throw const FormatException('Invalid optional course reference fields.');
    }
    return AcademicCourse(
      id: id,
      courseCode: code is String ? code : null,
      courseName: data['courseName'] as String,
      creditHours: credits is int ? credits : null,
      programme: data['programme'] as String,
      description: data['description'] is String
          ? data['description'] as String
          : null,
      confirmationStatus: data['confirmationStatus'] as String,
    );
  }
}

class TimetableEntry {
  const TimetableEntry({
    required this.scheduleType,
    required this.scheduleDay,
    required this.startTime,
    required this.endTime,
    required this.courseName,
    required this.groupId,
    required this.venue,
    required this.lecturerUid,
    this.classDate,
    this.courseCode,
    this.attendanceStatus,
    this.notes,
  });

  final String scheduleType;
  final String scheduleDay;
  final String startTime;
  final String endTime;
  final String courseName;
  final String groupId;
  final String venue;
  final String lecturerUid;
  final DateTime? classDate;
  final String? courseCode;
  final String? attendanceStatus;
  final String? notes;

  factory TimetableEntry.fromMap(Map<String, dynamic> data) {
    for (final key in [
      'scheduleType',
      'scheduleDay',
      'startTime',
      'endTime',
      'courseName',
      'groupId',
      'venue',
      'lecturerUid',
    ]) {
      if (data[key] is! String) {
        throw FormatException('Invalid timetable field: $key.');
      }
    }
    if (!_timePattern.hasMatch(data['startTime'] as String) ||
        !_timePattern.hasMatch(data['endTime'] as String) ||
        (data['startTime'] as String).compareTo(data['endTime'] as String) >=
            0) {
      throw const FormatException(
        'Timetable times must use a valid 24-hour interval.',
      );
    }
    final scheduleType = data['scheduleType'] as String;
    final classDate = _date(data['classDate']);
    if ((scheduleType == 'recurring_weekly' && classDate != null) ||
        (scheduleType == 'dated_occurrence' && classDate == null) ||
        !const {
          'recurring_weekly',
          'dated_occurrence',
        }.contains(scheduleType)) {
      throw const FormatException(
        'Timetable type and class date do not match.',
      );
    }
    for (final key in ['courseCode', 'attendanceStatus', 'notes']) {
      if (data[key] != null && data[key] is! String) {
        throw FormatException('Invalid optional timetable field: $key.');
      }
    }
    return TimetableEntry(
      scheduleType: scheduleType,
      scheduleDay: data['scheduleDay'] as String,
      startTime: data['startTime'] as String,
      endTime: data['endTime'] as String,
      courseName: data['courseName'] as String,
      groupId: data['groupId'] as String,
      venue: data['venue'] as String,
      lecturerUid: data['lecturerUid'] as String,
      classDate: classDate,
      courseCode: data['courseCode'] is String
          ? data['courseCode'] as String
          : null,
      attendanceStatus: data['attendanceStatus'] is String
          ? data['attendanceStatus'] as String
          : null,
      notes: data['notes'] is String ? data['notes'] as String : null,
    );
  }
}

class CourseOffering {
  const CourseOffering({
    required this.id,
    required this.courseId,
    required this.semesterId,
    required this.groupId,
    required this.lecturerUid,
    required this.status,
    required this.schedule,
  });

  final String id;
  final String courseId;
  final String semesterId;
  final String groupId;
  final String lecturerUid;
  final String status;
  final List<TimetableEntry> schedule;

  factory CourseOffering.fromFirestore(String id, Map<String, dynamic> data) {
    for (final key in [
      'courseId',
      'semesterId',
      'groupId',
      'lecturerUid',
      'status',
    ]) {
      if (data[key] is! String) {
        throw FormatException('Invalid course offering field: $key.');
      }
    }
    final rawSchedule = data['schedule'];
    if (rawSchedule is! List) {
      throw const FormatException('Invalid course offering schedule.');
    }
    final offering = CourseOffering(
      id: id,
      courseId: data['courseId'] as String,
      semesterId: data['semesterId'] as String,
      groupId: data['groupId'] as String,
      lecturerUid: data['lecturerUid'] as String,
      status: data['status'] as String,
      schedule: rawSchedule
          .map((entry) {
            if (entry is! Map) {
              throw const FormatException('Invalid timetable entry.');
            }
            return TimetableEntry.fromMap(Map<String, dynamic>.from(entry));
          })
          .toList(growable: false),
    );
    if (offering.schedule.any(
      (entry) =>
          entry.groupId != offering.groupId ||
          entry.lecturerUid != offering.lecturerUid,
    )) {
      throw const FormatException(
        'Timetable group and lecturer must match the course offering.',
      );
    }
    return offering;
  }
}

class AcademicEnrollment {
  const AcademicEnrollment({
    required this.id,
    required this.studentUid,
    required this.courseOfferingId,
    required this.courseId,
    required this.semesterId,
    required this.groupId,
    required this.status,
  });

  final String id;
  final String studentUid;
  final String courseOfferingId;
  final String courseId;
  final String semesterId;
  final String groupId;
  final String status;

  factory AcademicEnrollment.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    for (final key in [
      'studentUid',
      'courseOfferingId',
      'courseId',
      'semesterId',
      'groupId',
      'status',
    ]) {
      if (data[key] is! String) {
        throw FormatException('Invalid enrollment field: $key.');
      }
    }
    return AcademicEnrollment(
      id: id,
      studentUid: data['studentUid'] as String,
      courseOfferingId: data['courseOfferingId'] as String,
      courseId: data['courseId'] as String,
      semesterId: data['semesterId'] as String,
      groupId: data['groupId'] as String,
      status: data['status'] as String,
    );
  }
}

enum AcademicLoadStatus { loading, data, empty, error }

class AcademicLoadState<T> {
  const AcademicLoadState._(this.status, {this.value, this.error});
  const AcademicLoadState.loading() : this._(AcademicLoadStatus.loading);
  const AcademicLoadState.data(T value)
    : this._(AcademicLoadStatus.data, value: value);
  const AcademicLoadState.empty(T value)
    : this._(AcademicLoadStatus.empty, value: value);
  const AcademicLoadState.error(Object error)
    : this._(AcademicLoadStatus.error, error: error);

  final AcademicLoadStatus status;
  final T? value;
  final Object? error;
}

final RegExp _timePattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  throw const FormatException('Invalid academic date.');
}
