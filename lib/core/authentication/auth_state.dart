import 'auth_user.dart';

/// Base class representing the authentication states of the application.
sealed class AuthState {
  const AuthState();
}

/// Initial state when the application launches and authentication status is undetermined.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// State indicating an active authentication or role verification process is occurring.
class AuthLoading extends AuthState {
  final String? message;

  const AuthLoading({this.message});
}

/// State representing a successfully authenticated user with a backend-verified role.
class Authenticated extends AuthState {
  final AuthUser user;

  const Authenticated(this.user);
}

/// State representing an unauthenticated session (e.g. initial landing or after logout).
class Unauthenticated extends AuthState {
  final String? message;

  const Unauthenticated({this.message});
}

/// State representing an authentication error (e.g. invalid credentials or communication failure).
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);
}
