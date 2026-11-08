import 'package:flutter/material.dart';
import '../constants/user_role.dart';
import 'app_routes.dart';

/// Handles route generation and role-based route decisions for SmartUMC.
///
/// Operates exclusively with Flutter's built-in navigation primitives without
/// third-party dependencies.
class AppRouter {
  AppRouter._();

  /// Determines the initial route destination from the current authentication state.
  static String decideInitialRoute({UserRole? authenticatedRole}) {
    return AppRoutes.resolveRoute(authenticatedRole: authenticatedRole);
  }

  /// Generates the appropriate [Route] for the given [RouteSettings].
  ///
  /// Actual dashboard and login screen widgets will be bound in subsequent missions.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return _buildPlaceholderRoute(
          title: 'SmartUMC Login',
          route: AppRoutes.login,
        );

      case AppRoutes.studentMobile:
        return _buildPlaceholderRoute(
          title: 'Student Mobile Interface',
          route: AppRoutes.studentMobile,
        );

      case AppRoutes.lecturerDashboard:
        return _buildPlaceholderRoute(
          title: 'Lecturer Dashboard',
          route: AppRoutes.lecturerDashboard,
        );

      case AppRoutes.adminDashboard:
        return _buildPlaceholderRoute(
          title: 'Super Admin Dashboard',
          route: AppRoutes.adminDashboard,
        );

      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }

  /// Temporary route placeholder until dedicated feature screens are implemented.
  static MaterialPageRoute<void> _buildPlaceholderRoute({
    required String title,
    required String route,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: route),
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text('$title (Implementation pending)'),
        ),
      ),
    );
  }
}
