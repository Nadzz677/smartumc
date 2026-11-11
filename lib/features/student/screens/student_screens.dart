import 'package:flutter/material.dart';

import '../../../core/academics/academic_models.dart';
import '../../../core/academics/academic_repository.dart';
import '../../../core/authentication/auth_user.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';
import '../student_routes.dart';
import '../widgets/student_page_scaffold.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({
    required this.user,
    required this.repository,
    required this.onOpenTimetable,
    required this.onOpenActivities,
    required this.onOpenEvents,
    super.key,
  });
  final AuthUser user;
  final AcademicRepository repository;
  final VoidCallback onOpenTimetable;
  final VoidCallback onOpenActivities;
  final VoidCallback onOpenEvents;

  @override
  Widget build(BuildContext context) => StudentPageScaffold(
    title: 'Home',
    showAppBar: false,
    body: FutureBuilder<AcademicLoadState<List<TimetableEntry>>>(
      future: repository.getStudentTimetable(),
      builder: (context, snapshot) => _scroll([
        StudentCard(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.paleBlue,
                child: Icon(Icons.person_outline, color: AppColors.brandCyan),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
                    ),
                    Text(
                      user.displayName?.trim().isNotEmpty == true
                          ? user.displayName!
                          : user.matricNumber ?? 'Student',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const StudentSectionHeading('Enrolled weekly schedule'),
        if (!snapshot.hasData)
          const StudentLoadingState()
        else
          _academicState<List<TimetableEntry>>(snapshot.data!, (entries) {
            final recurring = entries
                .where((entry) => entry.scheduleType == 'recurring_weekly')
                .toList();
            if (recurring.isEmpty) {
              return const StudentEmptyState(
                title: 'No timetable available',
                message:
                    'No enrolled weekly schedule templates are available for this account.',
                icon: Icons.calendar_today_outlined,
              );
            }
            return StudentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly timetable',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: onOpenTimetable,
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const Text(
                    'Recurring templates · not dated class occurrences',
                    style: TextStyle(color: AppColors.slate),
                  ),
                  const Divider(height: AppSpacing.lg),
                  ...recurring
                      .take(3)
                      .map((entry) => _TimetableSummary(entry: entry)),
                ],
              ),
            );
          }),
        const StudentSectionHeading('Quick links'),
        _LinkCard(
          icon: Icons.menu_book_outlined,
          title: 'Academic activities',
          subtitle: 'Timetable and academic information',
          onTap: onOpenActivities,
        ),
        const SizedBox(height: AppSpacing.sm),
        _LinkCard(
          icon: Icons.campaign_outlined,
          title: 'Events',
          subtitle: 'University and club bulletin areas',
          onTap: onOpenEvents,
        ),
      ]),
    ),
  );
}

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({required this.onOpen, super.key});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => StudentPageScaffold(
    title: 'Activities',
    body: _scroll([
      Text(
        'Your academic life, organised in one place.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
      ),
      const SizedBox(height: AppSpacing.md),
      _LinkCard(
        icon: Icons.calendar_month_outlined,
        title: 'My Class Schedule',
        subtitle: 'View enrolled recurring timetable templates',
        onTap: () => onOpen(StudentRoutes.timetable),
      ),
      _LinkCard(
        icon: Icons.format_list_numbered,
        title: 'Academic Progress',
        subtitle: 'Grades and GPA are not available',
        onTap: () => onOpen(StudentRoutes.academicProgress),
      ),
      _LinkCard(
        icon: Icons.event_note_outlined,
        title: 'Academic Calendar',
        subtitle: 'Academic dates are not available',
        onTap: () => onOpen(StudentRoutes.academicCalendar),
      ),
      _LinkCard(
        icon: Icons.fact_check_outlined,
        title: 'Attendance History',
        subtitle: 'Student attendance history is not connected',
        onTap: () => onOpen(StudentRoutes.attendanceHistory),
      ),
    ]),
  );
}

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({required this.repository, super.key});
  final AcademicRepository repository;

  @override
  Widget build(BuildContext context) => StudentPageScaffold(
    title: 'My Class Schedule',
    body: FutureBuilder<AcademicLoadState<List<TimetableEntry>>>(
      future: repository.getStudentTimetable(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const StudentLoadingState();
        return _academicState<List<TimetableEntry>>(snapshot.data!, (entries) {
          final templates = entries
              .where((entry) => entry.scheduleType == 'recurring_weekly')
              .toList();
          if (templates.isEmpty) {
            return const StudentEmptyState(
              title: 'No classes available',
              message:
                  'No recurring timetable templates were found in your enrolled offerings.',
              icon: Icons.event_busy_outlined,
            );
          }
          return _scroll([
            const StudentCard(
              child: Text(
                'These are recurring weekly templates. They do not confirm that a class is scheduled on a particular date.',
              ),
            ),
            const StudentSectionHeading('Enrolled group timetable'),
            ...templates.map((entry) => _TimetableCard(entry: entry)),
          ]);
        });
      },
    ),
  );
}

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({
    required this.user,
    required this.onOpenSettings,
    super.key,
  });
  final AuthUser user;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => StudentPageScaffold(
    title: 'Profile',
    actions: [
      IconButton(
        onPressed: onOpenSettings,
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined),
      ),
    ],
    body: _scroll([
      StudentCard(
        child: Column(
          children: [
            const CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.paleBlue,
              child: Icon(
                Icons.person_outline,
                size: 52,
                color: AppColors.brandCyan,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!
                  : 'Name unavailable',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Student',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
      ),
      _ProfileSection(
        title: 'Student information',
        rows: [
          ('Matric number', user.matricNumber ?? 'Unavailable'),
          ('Email', user.email ?? 'Unavailable'),
        ],
      ),
      _ProfileSection(
        title: 'Academic information',
        rows: const [('Programme', 'Not available in the current profile')],
      ),
      _ProfileSection(
        title: 'Parents & Guardians',
        rows: const [('Information', 'Not provided in the current profile')],
      ),
    ]),
  );
}

class AcademicProgressScreen extends StatelessWidget {
  const AcademicProgressScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Academic Progress',
    body: Center(
      child: StudentEmptyState(
        title: 'Results unavailable',
        message:
            'Grades, GPA and CGPA are not provided by the current SmartUMC backend.',
        icon: Icons.query_stats_outlined,
      ),
    ),
  );
}

class AcademicCalendarScreen extends StatelessWidget {
  const AcademicCalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Academic Calendar',
    body: Center(
      child: StudentEmptyState(
        title: 'No academic dates available',
        message:
            'Official semester dates and academic events have not been provided.',
        icon: Icons.calendar_month_outlined,
      ),
    ),
  );
}

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Attendance History',
    body: Center(
      child: StudentEmptyState(
        title: 'Attendance history unavailable',
        message:
            'A student attendance-history endpoint is not available yet. Attendance records are not read directly from Firestore.',
        icon: Icons.fact_check_outlined,
      ),
    ),
  );
}

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'QR Scanner',
    body: Center(
      child: StudentEmptyState(
        title: 'Scanner not connected',
        message:
            'Camera scanning and location capture are not implemented in this screen yet.',
        icon: Icons.qr_code_scanner,
      ),
    ),
  );
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _selected = 0;
  @override
  Widget build(BuildContext context) => StudentPageScaffold(
    title: 'Events',
    body: Column(
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('University Bulletin')),
            ButtonSegment(value: 1, label: Text('Club Bulletins')),
          ],
          selected: {_selected},
          onSelectionChanged: (value) =>
              setState(() => _selected = value.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Center(
            child: StudentEmptyState(
              title: _selected == 0
                  ? 'No university bulletins'
                  : 'No club bulletins',
              message:
                  'Bulletin content is not available yet. No announcements are being shown.',
              icon: Icons.campaign_outlined,
            ),
          ),
        ),
      ],
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.onOpen,
    required this.onLogout,
    super.key,
  });
  final ValueChanged<String> onOpen;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => StudentPageScaffold(
    title: 'Settings',
    body: _scroll([
      const StudentSectionHeading('Preferences'),
      _LinkCard(
        icon: Icons.palette_outlined,
        title: 'Appearance',
        subtitle: 'Theme and display preferences',
        onTap: () => onOpen(StudentRoutes.appearance),
      ),
      _LinkCard(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        subtitle: 'Notification controls are not connected',
        onTap: () => onOpen(StudentRoutes.notifications),
      ),
      const StudentSectionHeading('Privacy & security'),
      _LinkCard(
        icon: Icons.location_on_outlined,
        title: 'Location & Privacy',
        subtitle: 'Location is used for attendance evidence when available',
        onTap: () => onOpen(StudentRoutes.locationPrivacy),
      ),
      _LinkCard(
        icon: Icons.shield_outlined,
        title: 'Security & Password',
        subtitle: 'Account security information',
        onTap: () => onOpen(StudentRoutes.securityPassword),
      ),
      const StudentSectionHeading('Support'),
      _LinkCard(
        icon: Icons.help_outline,
        title: 'Help & Support',
        subtitle: 'Information about current app capabilities',
        onTap: () => onOpen(StudentRoutes.helpSupport),
      ),
      _LinkCard(
        icon: Icons.info_outline,
        title: 'About SmartUMC',
        subtitle: 'Application information',
        onTap: () => onOpen(StudentRoutes.about),
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD9232E)),
      ),
    ]),
  );
}

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Appearance',
    body: Center(
      child: StudentEmptyState(
        title: 'Theme preference not connected',
        message:
            'SmartUMC currently uses the approved light theme. Theme selection is not saved or applied yet.',
        icon: Icons.palette_outlined,
      ),
    ),
  );
}

class LocationPrivacyScreen extends StatelessWidget {
  const LocationPrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Location & Privacy',
    body: Center(
      child: StudentEmptyState(
        title: 'Location use',
        message:
            'Location is not continuously tracked. Physical attendance may collect a location reading when the student submits attendance and the device provides it. This page does not read or change device permission status.',
        icon: Icons.location_on_outlined,
      ),
    ),
  );
}

class SecurityPasswordScreen extends StatelessWidget {
  const SecurityPasswordScreen({
    required this.onContactAdministrator,
    required this.onLogout,
    super.key,
  });
  final VoidCallback onContactAdministrator;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => StudentPageScaffold(
    title: 'Security & Password',
    body: _scroll([
      const StudentCard(
        child: Text(
          'Keep your account secure. Never share your password with anyone.',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      const StudentCard(
        child: Text(
          'Password reset is not available in SmartUMC. The student sign-in alias is not a real email address.',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton.icon(
        onPressed: onContactAdministrator,
        icon: const Icon(Icons.support_agent),
        label: const Text('Administrator help'),
      ),
      TextButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ]),
  );
}

class ContactAdministratorScreen extends StatelessWidget {
  const ContactAdministratorScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Contact University Administrator',
    body: Center(
      child: StudentEmptyState(
        title: 'Contact details unavailable',
        message:
            'An approved university administrator contact channel has not been configured.',
        icon: Icons.support_agent_outlined,
      ),
    ),
  );
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Help & Support',
    body: Center(
      child: StudentEmptyState(
        title: 'Support information',
        message:
            'QR camera scanning, student attendance history, password recovery, and support contact details are not connected yet.',
        icon: Icons.help_outline,
      ),
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'About SmartUMC',
    body: Center(
      child: StudentCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: AppColors.paleBlue,
              child: Icon(
                Icons.school_outlined,
                size: 40,
                color: AppColors.brandCyan,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'SmartUMC',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'A student application for academic information and campus activities.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Notifications',
    body: Center(
      child: StudentEmptyState(
        title: 'Notifications unavailable',
        message:
            'Notification delivery and preference storage are not implemented.',
        icon: Icons.notifications_none_outlined,
      ),
    ),
  );
}

class UnknownStudentScreen extends StatelessWidget {
  const UnknownStudentScreen({super.key});
  @override
  Widget build(BuildContext context) => const StudentPageScaffold(
    title: 'Unavailable',
    body: Center(child: Text('This screen is unavailable.')),
  );
}

Widget _academicState<T>(
  AcademicLoadState<T> state,
  Widget Function(T value) builder,
) {
  if (state.status == AcademicLoadStatus.error || state.value == null) {
    return const StudentErrorState();
  }
  return builder(state.value as T);
}

Widget _scroll(List<Widget> children) => SingleChildScrollView(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.md),
        children[i],
      ],
    ],
  ),
);

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.paleBlue,
                child: Icon(icon, color: AppColors.brandCyan),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: AppColors.slate,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TimetableSummary extends StatelessWidget {
  const _TimetableSummary({required this.entry});
  final TimetableEntry entry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${entry.scheduleDay} · ${entry.startTime}–${entry.endTime}',
          style: const TextStyle(
            color: AppColors.brandCyan,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(entry.courseName, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${entry.courseCode ?? 'Course code unavailable'} · Group ${entry.groupId}',
          style: const TextStyle(color: AppColors.slate),
        ),
        Text(entry.venue, style: const TextStyle(color: AppColors.slate)),
      ],
    ),
  );
}

class _TimetableCard extends StatelessWidget {
  const _TimetableCard({required this.entry});
  final TimetableEntry entry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: StudentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.scheduleDay} · ${entry.startTime}–${entry.endTime}',
            style: const TextStyle(
              color: AppColors.brandCyan,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(entry.courseName, style: Theme.of(context).textTheme.titleLarge),
          Text(
            '${entry.courseCode ?? 'Course code unavailable'} · Group ${entry.groupId}',
            style: const TextStyle(color: AppColors.slate),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lecturer details unavailable',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
              ),
              Flexible(
                child: Text(
                  entry.venue,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: AppColors.slate),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => StudentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Divider(height: AppSpacing.lg),
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: const TextStyle(color: AppColors.slate),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(row.$2, textAlign: TextAlign.end)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
