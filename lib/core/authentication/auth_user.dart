import '../constants/user_role.dart';

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

  /// Factory constructor to instantiate an [AuthUser] from backend-verified records.
  factory AuthUser.fromVerifiedRecord({
    required String uid,
    required String roleString,
    String? email,
    String? matricNumber,
    String? displayName,
  }) {
    return AuthUser(
      uid: uid,
      role: UserRole.fromString(roleString),
      email: email,
      matricNumber: matricNumber,
      displayName: displayName,
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
