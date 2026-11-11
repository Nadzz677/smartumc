import 'package:flutter/material.dart';

import '../../core/academics/academic_repository.dart';
import '../../core/authentication/auth_service.dart';
import '../../core/authentication/auth_user.dart';
import 'screens/student_screens.dart';
import 'student_routes.dart';
import 'widgets/student_bottom_navigation.dart';
import 'widgets/student_page_scaffold.dart';

/// Authenticated student shell. Each tab owns its own navigator so switching
/// tabs preserves that tab's nested screen stack and the auth gate remains above it.
class StudentApplication extends StatefulWidget {
  const StudentApplication({
    required this.user,
    required this.authService,
    required this.academicRepository,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final AcademicRepository academicRepository;

  @override
  State<StudentApplication> createState() => _StudentApplicationState();
}

class _StudentApplicationState extends State<StudentApplication> {
  int _selectedIndex = 0;
  final List<String> _routeStack = [StudentRoutes.home];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StudentNavigationScope(
        onBack: _routeStack.length > 1 ? _pop : null,
        child: _pageFor(_routeStack.last),
      ),
      bottomNavigationBar: StudentBottomNavigation(
        selectedIndex: _selectedIndex,
        onSelected: _selectTab,
      ),
    );
  }

  void _selectTab(int index) {
    final route = switch (index) {
      0 => StudentRoutes.home,
      1 => StudentRoutes.activities,
      2 => StudentRoutes.qrScanner,
      3 => StudentRoutes.events,
      _ => StudentRoutes.profile,
    };
    _selectTabAndRoute(index, route);
  }

  void _selectTabAndRoute(int index, String route) {
    setState(() {
      _selectedIndex = index;
      _routeStack
        ..clear()
        ..add(route);
    });
  }

  void _push(String route) => setState(() => _routeStack.add(route));

  void _pop() {
    if (_routeStack.length < 2) return;
    setState(() => _routeStack.removeLast());
  }

  Widget _pageFor(String route) {
    return switch (route) {
      StudentRoutes.home => StudentHomeScreen(
        user: widget.user,
        repository: widget.academicRepository,
        onOpenTimetable: () => _selectTabAndRoute(1, StudentRoutes.timetable),
        onOpenActivities: () => _selectTabAndRoute(1, StudentRoutes.activities),
        onOpenEvents: () => _selectTabAndRoute(3, StudentRoutes.events),
      ),
      StudentRoutes.activities => ActivitiesScreen(onOpen: _push),
      StudentRoutes.timetable => TimetableScreen(
        repository: widget.academicRepository,
      ),
      StudentRoutes.academicProgress => const AcademicProgressScreen(),
      StudentRoutes.academicCalendar => const AcademicCalendarScreen(),
      StudentRoutes.attendanceHistory => const AttendanceHistoryScreen(),
      StudentRoutes.qrScanner => const QrScannerScreen(),
      StudentRoutes.events => const EventsScreen(),
      StudentRoutes.profile => StudentProfileScreen(
        user: widget.user,
        onOpenSettings: () => _push(StudentRoutes.settings),
      ),
      StudentRoutes.settings => SettingsScreen(
        onOpen: _push,
        onLogout: _confirmLogout,
      ),
      StudentRoutes.appearance => const AppearanceScreen(),
      StudentRoutes.locationPrivacy => const LocationPrivacyScreen(),
      StudentRoutes.securityPassword => SecurityPasswordScreen(
        onContactAdministrator: () => _push(StudentRoutes.contactAdministrator),
        onLogout: _confirmLogout,
      ),
      StudentRoutes.helpSupport => const HelpSupportScreen(),
      StudentRoutes.about => const AboutScreen(),
      StudentRoutes.notifications => const NotificationsScreen(),
      StudentRoutes.contactAdministrator => const ContactAdministratorScreen(),
      _ => const UnknownStudentScreen(),
    };
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Sign out of SmartUMC?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.authService.logout();
  }
}
