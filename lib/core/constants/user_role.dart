/// Centralized user role definitions for SmartUMC.
///
/// SmartUMC enforces three distinct user roles sharing one codebase:
/// - [student]: Android mobile application interface.
/// - [lecturer]: Desktop-first web dashboard for attendance and QR management.
/// - [superAdmin]: Limited synthetic-data administration interface.
///
/// Security note:
/// Roles must be verified using trusted backend-controlled data (e.g. Firebase
/// custom claims or Cloud Firestore user documents). Clients must never be
/// permitted to assign or alter their own roles.
enum UserRole {
  student('student'),
  lecturer('lecturer'),
  superAdmin('super_admin');

  final String value;

  const UserRole(this.value);

  /// Resolves a [UserRole] from a backend string value.
  ///
  /// Throws an [ArgumentError] if the provided role string is unrecognized.
  static UserRole fromString(String role) {
    final normalized = role.trim().toLowerCase();
    for (final r in UserRole.values) {
      if (r.value == normalized) {
        return r;
      }
    }
    throw ArgumentError('Invalid or unsupported user role: $role');
  }

  /// Safely resolves a [UserRole] from a string, returning null if invalid.
  static UserRole? tryFromString(String? role) {
    if (role == null) return null;
    try {
      return fromString(role);
    } catch (_) {
      return null;
    }
  }

  /// Parses a claim without case folding or aliases; claims must use the
  /// canonical trusted values assigned by the backend.
  static UserRole? tryFromClaim(Object? value) {
    if (value is! String) return null;
    for (final role in UserRole.values) {
      if (role.value == value) return role;
    }
    return null;
  }

  bool get isStudent => this == UserRole.student;
  bool get isLecturer => this == UserRole.lecturer;
  bool get isAdmin => this == UserRole.superAdmin;
  bool get isSuperAdmin => this == UserRole.superAdmin;
}
