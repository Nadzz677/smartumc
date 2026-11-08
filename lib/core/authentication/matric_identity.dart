import '../constants/user_role.dart';

/// Centralized validation and deterministic Firebase Auth email alias mapping.
///
/// The alias is an identifier only; it is not a recovery email address.
class MatricIdentity {
  MatricIdentity._();

  static final RegExp _acceptedFormat = RegExp(r'^[a-z0-9][a-z0-9-]{3,19}$');

  static String normalize(String value) {
    final normalized = value.trim().toLowerCase();
    if (!_acceptedFormat.hasMatch(normalized)) {
      throw const FormatException('Enter a valid matric number.');
    }
    return normalized;
  }

  static String emailAlias(String value) =>
      '${normalize(value)}@students.smartumc.invalid';

  static bool matchesAuthProfile({
    required String? authEmail,
    required String profileEmail,
    required UserRole role,
    required String? matricNumber,
  }) {
    final normalizedEmail = authEmail?.trim().toLowerCase();
    if (normalizedEmail == null || normalizedEmail != profileEmail.trim().toLowerCase()) {
      return false;
    }
    if (role != UserRole.student) return true;
    if (matricNumber == null) return false;
    try {
      return normalizedEmail == emailAlias(matricNumber);
    } on FormatException {
      return false;
    }
  }
}
