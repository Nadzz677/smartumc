import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/academics/academic_models.dart';
import 'package:smartumc/core/academics/academic_repository.dart';
import 'package:smartumc/core/authentication/auth_repository.dart';
import 'package:smartumc/core/authentication/auth_service.dart';
import 'package:smartumc/core/authentication/auth_state.dart';
import 'package:smartumc/core/authentication/auth_user.dart';
import 'package:smartumc/core/constants/user_role.dart';
import 'package:smartumc/features/student/screens/student_screens.dart';
import 'package:smartumc/features/student/student_application.dart';
import 'package:smartumc/main.dart';

class _FakeAuthRepository implements AuthRepository {
  final controller = StreamController<AuthState>.broadcast();
  AuthUser? user;

  @override
  Stream<AuthState> get authStateChanges => controller.stream;

  @override
  Future<AuthUser?> getCurrentUser() async => user;

  @override
  Future<AuthUser> signInWithMatricNumber({
    required String matricNumber,
    required String password,
  }) async => user!;

  @override
  Future<AuthUser> signInWithStaffCredentials({
    required String email,
    required String password,
  }) async => user!;

  @override
  Future<void> signOut() async {
    user = null;
    controller.add(const Unauthenticated());
  }
}

class _FakeAcademicRepository implements AcademicRepository {
  List<TimetableEntry> timetable = const [];
  Completer<AcademicLoadState<List<TimetableEntry>>>? timetableCompleter;
  bool timetableFails = false;

  @override
  Future<AcademicLoadState<List<AcademicSemester>>>
  getStudentSemesters() async => const AcademicLoadState.empty([]);

  @override
  Future<AcademicLoadState<List<CourseOffering>>> getStudentOfferings({
    String? semesterId,
  }) async => const AcademicLoadState.empty([]);

  @override
  Future<AcademicLoadState<List<TimetableEntry>>> getStudentTimetable({
    String? semesterId,
  }) {
    if (timetableCompleter != null) return timetableCompleter!.future;
    if (timetableFails) {
      return Future.value(
        AcademicLoadState.error(Exception('synthetic failure')),
      );
    }
    return Future.value(
      timetable.isEmpty
          ? const AcademicLoadState.empty([])
          : AcademicLoadState.data(timetable),
    );
  }

  @override
  Future<AcademicLoadState<List<CourseOffering>>> getLecturerOfferings({
    String? semesterId,
  }) async => const AcademicLoadState.empty([]);
}

void main() {
  testWidgets(
    'does not show a protected experience until authorization resolves',
    (tester) async {
      final repository = _FakeAuthRepository();
      final service = AuthService(repository: repository);
      final academic = _FakeAcademicRepository();
      repository.controller.add(const AuthLoading());

      await tester.pumpWidget(
        SmartUMCApp(authService: service, academicRepository: academic),
      );
      await tester.pump();
      expect(find.text('Welcome'), findsNothing);
      expect(find.text('Log in to access your student portal.'), findsNothing);

      repository.user = const AuthUser(
        uid: 'synthetic-uid',
        role: UserRole.student,
        matricNumber: 'dit2026001',
      );
      repository.controller.add(Authenticated(repository.user!));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('dit2026001'), findsOneWidget);
      expect(find.text('No timetable available'), findsOneWidget);

      await service.logout();
      await tester.pumpAndSettle();
      expect(
        find.text('Log in to access your student portal.'),
        findsOneWidget,
      );
      await repository.controller.close();
    },
  );

  testWidgets('restores lecturer routing only after a trusted state arrives', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final service = AuthService(repository: repository);
    await tester.pumpWidget(
      SmartUMCApp(
        authService: service,
        academicRepository: _FakeAcademicRepository(),
      ),
    );
    await tester.pump();
    repository.controller.add(const Unauthenticated());
    await tester.pump();
    expect(find.text('Log in to access your student portal.'), findsOneWidget);

    repository.user = const AuthUser(
      uid: 'synthetic-lecturer',
      role: UserRole.lecturer,
    );
    repository.controller.add(Authenticated(repository.user!));
    await tester.pump();
    expect(find.text('Lecturer experience'), findsOneWidget);
    await repository.controller.close();
  });

  testWidgets('does not expose a Super Admin dashboard in Mission 09', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final service = AuthService(repository: repository);
    await tester.pumpWidget(
      SmartUMCApp(
        authService: service,
        academicRepository: _FakeAcademicRepository(),
      ),
    );
    repository.user = const AuthUser(
      uid: 'synthetic-admin',
      role: UserRole.superAdmin,
    );
    repository.controller.add(Authenticated(repository.user!));
    await tester.pump();

    expect(
      find.text('Super Admin tools are not included in Mission 09.'),
      findsOneWidget,
    );
    expect(find.text('Super Admin experience'), findsNothing);
    await repository.controller.close();
  });

  testWidgets('student navigation keeps role-specific screens and empty states', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final service = AuthService(repository: authRepository);
    authRepository.user = const AuthUser(
      uid: 'synthetic-student',
      role: UserRole.student,
      matricNumber: 'dit2026002',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudentApplication(
          user: authRepository.user!,
          authService: service,
          academicRepository: _FakeAcademicRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('student-tab-activities')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('student-screen-activities')),
      findsOneWidget,
    );
    expect(
      find.text('Your academic life, organised in one place.'),
      findsOneWidget,
    );
    expect(find.text('Academic Progress'), findsOneWidget);
    await tester.tap(find.text('Academic Progress'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('student-screen-academic-progress')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Grades, GPA and CGPA are not provided by the current SmartUMC backend.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('student-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Academic Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('No academic dates available'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('student-back')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Attendance History'));
    await tester.tap(find.text('Attendance History'));
    await tester.pumpAndSettle();
    expect(find.text('Attendance history unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('student-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('student-tab-events')));
    await tester.pumpAndSettle();
    expect(find.text('No university bulletins'), findsOneWidget);
    await tester.tap(find.text('Club Bulletins'));
    await tester.pumpAndSettle();
    expect(find.text('No club bulletins'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('student-tab-qr')));
    await tester.pumpAndSettle();
    expect(find.text('Scanner not connected'), findsOneWidget);

    await authRepository.controller.close();
  });

  testWidgets('timetable shows enrolled recurring templates only', (
    tester,
  ) async {
    final academics = _FakeAcademicRepository()
      ..timetable = [
        TimetableEntry(
          scheduleType: 'recurring_weekly',
          scheduleDay: 'Tuesday',
          startTime: '09:00',
          endTime: '11:00',
          courseName: 'Synthetic Web Programming',
          courseCode: 'SYN1001',
          groupId: 'G01',
          venue: 'Synthetic Lab',
          lecturerUid: 'synthetic-lecturer-uid',
        ),
        TimetableEntry(
          scheduleType: 'dated_occurrence',
          scheduleDay: 'Monday',
          startTime: '09:00',
          endTime: '11:00',
          classDate: DateTime(2026, 10, 12),
          courseName: 'Dated Synthetic Occurrence',
          courseCode: 'SYN1002',
          groupId: 'G01',
          venue: 'Synthetic Hall',
          lecturerUid: 'synthetic-lecturer-uid',
        ),
      ];
    final authRepository = _FakeAuthRepository()
      ..user = const AuthUser(
        uid: 'synthetic-student',
        role: UserRole.student,
        matricNumber: 'dit2026002',
      );
    final service = AuthService(repository: authRepository);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentApplication(
          user: authRepository.user!,
          authService: service,
          academicRepository: academics,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('student-tab-activities')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Class Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic Web Programming'), findsOneWidget);
    expect(find.text('Dated Synthetic Occurrence'), findsNothing);
    expect(find.textContaining('Group G01'), findsOneWidget);
    expect(find.text('synthetic-lecturer-uid'), findsNothing);
    await authRepository.controller.close();
  });

  testWidgets(
    'profile uses available identity and marks guardian data absent',
    (tester) async {
      final authRepository = _FakeAuthRepository()
        ..user = const AuthUser(
          uid: 'synthetic-student',
          role: UserRole.student,
          displayName: 'Synthetic Student',
          matricNumber: 'dit2026003',
        );
      final service = AuthService(repository: authRepository);
      await tester.pumpWidget(
        MaterialApp(
          home: StudentApplication(
            user: authRepository.user!,
            authService: service,
            academicRepository: _FakeAcademicRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('student-tab-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Student'), findsOneWidget);
      expect(find.text('dit2026003'), findsOneWidget);
      expect(find.text('Not provided in the current profile'), findsOneWidget);
      expect(find.text('0000000000'), findsNothing);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('student-screen-settings')),
        findsOneWidget,
      );
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.text('Theme preference not connected'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('student-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications unavailable'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('student-back')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();
      expect(authRepository.user, isNull);
      await authRepository.controller.close();
    },
  );

  testWidgets('activity card invokes its route callback', (tester) async {
    String? selectedRoute;
    await tester.pumpWidget(
      MaterialApp(
        home: ActivitiesScreen(onOpen: (route) => selectedRoute = route),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Academic Progress'), findsOneWidget);
    await tester.tap(find.text('Academic Progress'));
    expect(selectedRoute, isNotNull);
  });

  testWidgets('home shows loading and repository error states', (tester) async {
    final loadingRepository = _FakeAcademicRepository()
      ..timetableCompleter =
          Completer<AcademicLoadState<List<TimetableEntry>>>();
    const user = AuthUser(
      uid: 'synthetic-student',
      role: UserRole.student,
      matricNumber: 'dit2026004',
    );
    final service = AuthService(repository: _FakeAuthRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: StudentApplication(
          user: user,
          authService: service,
          academicRepository: loadingRepository,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    loadingRepository.timetableCompleter!.complete(
      const AcademicLoadState.empty([]),
    );
    await tester.pumpAndSettle();
    expect(find.text('No timetable available'), findsOneWidget);

    final failedRepository = _FakeAcademicRepository()..timetableFails = true;
    await tester.pumpWidget(
      MaterialApp(
        home: StudentApplication(
          user: user,
          authService: service,
          academicRepository: failedRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Information unavailable'), findsOneWidget);
  });
}
