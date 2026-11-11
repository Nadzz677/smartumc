import 'package:flutter/material.dart';

import '../../core/authentication/auth_service.dart';
import '../../core/authentication/auth_state.dart';
import '../../core/academics/academic_repository.dart';
import '../../core/routing/role_application_shell.dart';
import 'login_screen.dart';

/// Keeps every protected experience behind resolved Firebase identity,
/// trusted role claims, and an active matching user profile.
class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({
    required this.authService,
    required this.academicRepository,
    super.key,
  });

  final AuthService authService;
  final AcademicRepository academicRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      initialData: const AuthLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state is Authenticated) {
          return RoleApplicationShell(
            user: state.user,
            authService: authService,
            academicRepository: academicRepository,
          );
        }
        if (state is Unauthenticated) {
          return LoginScreen(authService: authService, message: state.message);
        }
        if (state is AuthFailure || snapshot.hasError) {
          return LoginScreen(
            authService: authService,
            message: 'Unable to verify your account. Please try again.',
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
