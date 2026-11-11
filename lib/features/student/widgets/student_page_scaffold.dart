import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';

class StudentPageScaffold extends StatelessWidget {
  const StudentPageScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    this.showAppBar = true,
    this.leading,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool showAppBar;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final backAction = StudentNavigationScope.maybeOf(context);
    return Scaffold(
      key: ValueKey(
        'student-screen-${title.toLowerCase().replaceAll(' ', '-')}',
      ),
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: AppColors.white,
              surfaceTintColor: AppColors.white,
              elevation: 1,
              shadowColor: AppColors.ink.withValues(alpha: 0.08),
              centerTitle: true,
              title: Text(title),
              leading:
                  leading ??
                  (backAction == null
                      ? null
                      : IconButton(
                          key: const ValueKey('student-back'),
                          tooltip: 'Back',
                          onPressed: backAction,
                          icon: const Icon(Icons.arrow_back),
                        )),
              actions: actions,
            )
          : null,
      body: SafeArea(
        top: !showAppBar,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class StudentNavigationScope extends InheritedWidget {
  const StudentNavigationScope({
    required this.onBack,
    required super.child,
    super.key,
  });

  final VoidCallback? onBack;

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StudentNavigationScope>()
      ?.onBack;

  @override
  bool updateShouldNotify(StudentNavigationScope oldWidget) =>
      onBack != oldWidget.onBack;
}

class StudentCard extends StatelessWidget {
  const StudentCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      elevation: 2,
      shadowColor: AppColors.ink.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

class StudentSectionHeading extends StatelessWidget {
  const StudentSectionHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.slate,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class StudentEmptyState extends StatelessWidget {
  const StudentEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => StudentCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: AppColors.brandCyan),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}

class StudentLoadingState extends StatelessWidget {
  const StudentLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.xl),
    child: Center(child: CircularProgressIndicator()),
  );
}

class StudentErrorState extends StatelessWidget {
  const StudentErrorState({
    this.message = 'We could not load this information.',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) => StudentEmptyState(
    title: 'Information unavailable',
    message: message,
    icon: Icons.cloud_off_outlined,
  );
}
