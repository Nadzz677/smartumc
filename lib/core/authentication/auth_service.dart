import '../constants/user_role.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'auth_user.dart';
import 'matric_identity.dart';

/// Application service coordinating authentication workflows and role management.
///
/// Communicates through [AuthRepository] to enforce separation of concerns,
/// ensuring feature UI layers interact exclusively with a clean application-level API.
class AuthService {
  final AuthRepository _repository;

  AuthService({required AuthRepository repository}) : _repository = repository;

  /// Stream of authentication state transitions.
  Stream<AuthState> get authStateChanges => _repository.authStateChanges;

  /// Retrieves the currently authenticated [AuthUser], if any.
  Future<AuthUser?> getCurrentUser() => _repository.getCurrentUser();

  /// Verifies whether an active authenticated session exists.
  Future<bool> isAuthenticated() async {
    final user = await _repository.getCurrentUser();
    return user != null;
  }

  /// Retrieves the role assigned to the active user session.
  Future<UserRole?> getCurrentUserRole() async {
    final user = await _repository.getCurrentUser();
    return user?.role;
  }

  /// Handles student login using Matric Number and Password.
  ///
  /// Preserves the required student matric number authentication contract.
  Future<AuthUser> loginStudent({
    required String matricNumber,
    required String password,
  }) async {
    final sanitizedMatric = MatricIdentity.normalize(matricNumber);
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }

    return _repository.signInWithMatricNumber(
      matricNumber: sanitizedMatric,
      password: password,
    );
  }

  /// Handles lecturer and Super Admin login using provisioned email credentials.
  Future<AuthUser> loginStaff({
    required String email,
    required String password,
  }) async {
    final sanitizedEmail = email.trim().toLowerCase();
    if (!sanitizedEmail.contains('@') || sanitizedEmail.contains(' ')) {
      throw const FormatException('Enter a valid staff email address.');
    }
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }

    return _repository.signInWithStaffCredentials(
      email: sanitizedEmail,
      password: password,
    );
  }

  /// Terminates the current authenticated session.
  Future<void> logout() => _repository.signOut();
}
