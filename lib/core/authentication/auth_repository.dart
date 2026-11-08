import 'auth_state.dart';
import 'auth_user.dart';

/// Abstract contract defining the core authentication operations for SmartUMC.
///
/// Concrete implementations will integrate with Firebase Authentication and
/// Cloud Firestore in subsequent development phases.
abstract class AuthRepository {
  /// Stream emitting real-time [AuthState] updates as session status changes.
  Stream<AuthState> get authStateChanges;

  /// Retrieves the currently authenticated [AuthUser], or null if unauthenticated.
  Future<AuthUser?> getCurrentUser();

  /// Authenticates a student using their Matric Number and Password.
  ///
  /// Conforms to the approved SmartUMC student login interface requirements.
  /// The backend maps the student matric number to their canonical Firebase identity.
  Future<AuthUser> signInWithMatricNumber({
    required String matricNumber,
    required String password,
  });

  /// Authenticates lecturers and provisioned Super Admins using their Firebase
  /// Authentication email and password.
  Future<AuthUser> signInWithStaffCredentials({
    required String email,
    required String password,
  });

  /// Terminates the current session and clears cached authorization state.
  Future<void> signOut();
}
