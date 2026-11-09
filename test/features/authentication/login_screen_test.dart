import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/authentication/auth_repository.dart';
import 'package:smartumc/core/authentication/auth_service.dart';
import 'package:smartumc/core/authentication/auth_state.dart';
import 'package:smartumc/core/authentication/auth_user.dart';
import 'package:smartumc/core/constants/user_role.dart';
import 'package:smartumc/core/design_system/app_theme.dart';
import 'package:smartumc/features/authentication/login_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  final StreamController<AuthState> states =
      StreamController<AuthState>.broadcast();

  String? studentMatric;
  String? studentPassword;
  String? staffEmail;
  String? staffPassword;
  Object? failure;

  @override
  Stream<AuthState> get authStateChanges => states.stream;

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<AuthUser> signInWithMatricNumber({
    required String matricNumber,
    required String password,
  }) async {
    studentMatric = matricNumber;
    studentPassword = password;
    if (failure != null) throw failure!;
    return AuthUser(
      uid: 'synthetic-student',
      role: UserRole.student,
      matricNumber: matricNumber,
    );
  }

  @override
  Future<AuthUser> signInWithStaffCredentials({
    required String email,
    required String password,
  }) async {
    staffEmail = email;
    staffPassword = password;
    if (failure != null) throw failure!;
    return const AuthUser(uid: 'synthetic-lecturer', role: UserRole.lecturer);
  }

  @override
  Future<void> signOut() async {
    states.add(const Unauthenticated());
  }

  Future<void> dispose() => states.close();
}

void main() {
  late _FakeAuthRepository repository;
  late AuthService authService;

  setUp(() {
    repository = _FakeAuthRepository();
    authService = AuthService(repository: repository);
  });

  tearDown(() async {
    await repository.dispose();
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    Size size = const Size(393, 852),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(authService: authService),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Figma student login and keeps recovery unavailable', (
    tester,
  ) async {
    await pumpLogin(tester);

    expect(find.text('SmartUMC'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Matric Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);

    await tester.tap(find.text('Forgot Password?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Password recovery is not available yet. Contact UMC Support.'),
      findsOneWidget,
    );
    expect(repository.studentMatric, isNull);
    expect(repository.staffEmail, isNull);
  });

  testWidgets('validates matric and password before calling authentication', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'DIT');
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid matric number.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'DIT2026001');
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repository.studentMatric, isNull);
  });

  testWidgets('submits normalized matric credentials through AuthService', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).at(0), ' DIT2026001 ');
    await tester.enterText(find.byType(TextFormField).at(1), 'synthetic-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle();

    expect(repository.studentMatric, 'dit2026001');
    expect(repository.studentPassword, 'synthetic-pass');
  });

  testWidgets('preserves staff email and password sign-in', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Lecturer / staff sign-in'));
    await tester.pumpAndSettle();

    expect(find.text('Staff Email'), findsOneWidget);
    expect(
      find.text('Log in to access your lecturer dashboard.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      ' STAFF@EXAMPLE.INVALID ',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'synthetic-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle();

    expect(repository.staffEmail, 'staff@example.invalid');
    expect(repository.staffPassword, 'synthetic-pass');
  });

  testWidgets(
    'shows generic credential errors without exposing account state',
    (tester) async {
      repository.failure = StateError('synthetic test failure');
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'DIT2026001');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-pass',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to sign in with those credentials.'),
        findsOneWidget,
      );
      expect(find.textContaining('synthetic test failure'), findsNothing);
    },
  );

  testWidgets('keeps the login usable on a narrow mobile viewport', (
    tester,
  ) async {
    await pumpLogin(tester, size: const Size(320, 640));

    expect(find.text('Matric Number'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
