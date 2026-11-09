import 'package:flutter/material.dart';

import '../authentication/auth_service.dart';
import '../authentication/auth_user.dart';
import '../constants/user_role.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_spacing.dart';
import '../design_system/widgets/app_card.dart';

/// Minimal role destinations mounted only after trusted authentication resolves.
/// These are navigation shells, not implementations of the future dashboards.
class RoleApplicationShell extends StatelessWidget {
  const RoleApplicationShell({
    required this.user,
    required this.authService,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return switch (user.role) {
      UserRole.student => _ExperienceShell(
        title: 'Student experience',
        subtitle: 'Student mobile application',
        contentMaxWidth: 480,
        user: user,
        authService: authService,
      ),
      UserRole.lecturer => _ExperienceShell(
        title: 'Lecturer experience',
        subtitle: 'Lecturer web dashboard',
        contentMaxWidth: 1120,
        user: user,
        authService: authService,
      ),
      UserRole.superAdmin => _SuperAdminUnavailable(authService: authService),
    };
  }
}

class _ExperienceShell extends StatelessWidget {
  const _ExperienceShell({
    required this.title,
    required this.subtitle,
    required this.contentMaxWidth,
    required this.user,
    required this.authService,
  });

  final String title;
  final String subtitle;
  final double contentMaxWidth;
  final AuthUser user;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartUMC'),
        actions: [
          TextButton(
            onPressed: authService.logout,
            child: const Text('Log out'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'The role-specific screens will be added in later Mission 09 stages.',
                    style: TextStyle(color: AppColors.slate),
                  ),
                  if (user.displayName case final name?) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(name),
                  ],
                  if (user.matricNumber case final matric?) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(matric),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuperAdminUnavailable extends StatelessWidget {
  const _SuperAdminUnavailable({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SmartUMC')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Super Admin tools are not included in Mission 09.'),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: authService.logout,
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
