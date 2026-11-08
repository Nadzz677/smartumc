import 'package:flutter/material.dart';

import '../../core/authentication/auth_service.dart';
import '../../core/authentication/auth_state.dart';
import '../../core/authentication/auth_user.dart';
import '../../core/constants/user_role.dart';
import '../../core/routing/app_routes.dart';
import 'login_screen.dart';

/// Keeps every protected experience behind resolved Firebase identity,
/// trusted role claims, and an active matching user profile.
class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({required this.authService, super.key});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      initialData: const AuthLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state is Authenticated) {
          return _roleExperience(context, state.user, authService);
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
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

Widget _roleExperience(BuildContext context, AuthUser user, AuthService authService) {
  final title = switch (user.role) {
    UserRole.student => 'Student',
    UserRole.lecturer => 'Lecturer',
    UserRole.superAdmin => 'Super Admin',
  };
  final destination = AppRoutes.getDestinationForRole(user.role);
  return Scaffold(
    appBar: AppBar(
      title: const Text('SmartUMC'),
      actions: [
        TextButton(onPressed: authService.logout, child: const Text('Log out')),
      ],
    ),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$title experience', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(destination),
          if (user.displayName case final name?) Text(name),
          if (user.matricNumber case final matric?) Text(matric),
        ],
      ),
    ),
  );
}
