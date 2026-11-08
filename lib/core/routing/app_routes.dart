import '../constants/user_role.dart';

/// Defines route path constants and role-based destination resolution for SmartUMC.
class AppRoutes {
  AppRoutes._();

  /// Default route for unauthenticated users.
  static const String login = '/login';

  /// Destination interface for students (Android mobile application).
  static const String studentMobile = '/student';

  /// Destination dashboard for lecturers (attendance web dashboard).
  static const String lecturerDashboard = '/lecturer';

  /// Destination dashboard for Super Admin (university information & records).
  static const String adminDashboard = '/admin';

  /// Maps an authenticated [UserRole] to its designated interface route.
  static String getDestinationForRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        return studentMobile;
      case UserRole.lecturer:
        return lecturerDashboard;
      case UserRole.superAdmin:
        return adminDashboard;
    }
  }

  /// Determines the landing route based on whether a valid role is present.
  ///
  /// Unauthenticated users (null role) are routed to [login].
  static String resolveRoute({UserRole? authenticatedRole}) {
    if (authenticatedRole == null) {
      return login;
    }
    return getDestinationForRole(authenticatedRole);
  }

  /// Verifies whether the provided [userRole] has permission to access [route].
  static bool canAccessRoute({
    required String route,
    required UserRole? userRole,
  }) {
    if (route == login) {
      return true;
    }
    if (userRole == null) {
      return false;
    }
    switch (route) {
      case studentMobile:
        return userRole == UserRole.student;
      case lecturerDashboard:
        return userRole == UserRole.lecturer;
      case adminDashboard:
        return userRole == UserRole.superAdmin;
      default:
        return false;
    }
  }
}
