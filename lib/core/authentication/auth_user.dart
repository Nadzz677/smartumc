import '../constants/user_role.dart';
import 'matric_identity.dart';

/// Represents an authenticated user in SmartUMC.
///
/// In compliance with SmartUMC security principles:
/// - The [uid] corresponds directly to the canonical Firebase Authentication UID.
/// - The [role] is verified against trusted backend-controlled data.
/// - Client applications cannot modify or elevate their assigned role.
class AuthUser {
  /// The canonical unique user identifier from Firebase Authentication.
  final String uid;

  /// The backend-verified authorization role.
  final UserRole role;

  /// Optional email address associated with the user account.
  final String? email;

  /// Student matriculation number (applicable for [UserRole.student]).
  final String? matricNumber;

  /// Display name of the user.
  final String? displayName;

  const AuthUser({
    required this.uid,
    required this.role,
    this.email,
    this.matricNumber,
    this.displayName,
  });

  /// Constructs the app identity only when trusted token claims and the
  /// server-read profile agree and the account is active.
  factory AuthUser.fromTrustedSources({
    required String uid,
    required Map<String, dynamic> claims,
    required Map<String, dynamic> profile,
    String? email,
  }) {
    final roleValue = claims['role'];
    if (claims['active'] != true || roleValue is! String) {
      throw const AuthAuthorizationException();
    }

    final role = UserRole.tryFromClaim(roleValue);
    if (role == null || profile['role'] != role.value || profile['status'] != 'active') {
      throw const AuthAuthorizationException();
    }

    final matricNumber = profile['matricNumber'];
    if (role == UserRole.student && matricNumber is! String) {
      throw const AuthAuthorizationException();
    }

    String? normalizedMatric;
    if (role == UserRole.student) {
      try {
        normalizedMatric = MatricIdentity.normalize(matricNumber as String);
      } on FormatException {
        throw const AuthAuthorizationException();
      }
    }

    return AuthUser(
      uid: uid,
      role: role,
      email: email,
      matricNumber: normalizedMatric,
      displayName: profile['displayName'] is String ? profile['displayName'] as String : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          role == other.role;

  @override
  int get hashCode => uid.hashCode ^ role.hashCode;

  @override
  String toString() => 'AuthUser(uid: $uid, role: ${role.value})';
}

class AuthAuthorizationException implements Exception {
  const AuthAuthorizationException();
}
