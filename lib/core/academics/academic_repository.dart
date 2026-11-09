import 'academic_models.dart';
import '../constants/user_role.dart';

class AcademicIdentity {
  const AcademicIdentity({
    required this.uid,
    required this.active,
    required this.role,
  });

  final String uid;
  final bool active;
  final UserRole? role;
}

abstract interface class AcademicIdentityProvider {
  Future<AcademicIdentity?> getCurrentIdentity();
}

abstract interface class AcademicDataSource {
  Future<List<AcademicEnrollment>> getStudentEnrollments(String studentUid);
  Future<AcademicSemester?> getSemester(String semesterId);
  Future<CourseOffering?> getOffering(String offeringId);
  Future<List<CourseOffering>> getLecturerOfferings(String lecturerUid);
}

abstract interface class AcademicRepository {
  Future<AcademicLoadState<List<AcademicSemester>>> getStudentSemesters();
  Future<AcademicLoadState<List<CourseOffering>>> getStudentOfferings({
    String? semesterId,
  });
  Future<AcademicLoadState<List<TimetableEntry>>> getStudentTimetable({
    String? semesterId,
  });
  Future<AcademicLoadState<List<CourseOffering>>> getLecturerOfferings({
    String? semesterId,
  });
}
