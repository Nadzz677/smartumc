import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/authentication/auth_repository.dart';
import 'package:smartumc/core/authentication/auth_service.dart';
import 'package:smartumc/core/authentication/auth_state.dart';
import 'package:smartumc/core/authentication/auth_user.dart';
import 'package:smartumc/core/constants/user_role.dart';
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

void main() {
  testWidgets(
    'does not show a protected experience until authorization resolves',
    (tester) async {
      final repository = _FakeAuthRepository();
      final service = AuthService(repository: repository);
      repository.controller.add(const AuthLoading());

      await tester.pumpWidget(SmartUMCApp(authService: service));
      await tester.pump();
      expect(find.text('Student experience'), findsNothing);
      expect(find.text('Log in to access your student portal.'), findsNothing);

      repository.user = const AuthUser(
        uid: 'synthetic-uid',
        role: UserRole.student,
        matricNumber: 'dit2026001',
      );
      repository.controller.add(Authenticated(repository.user!));
      await tester.pump();
      expect(find.text('Student experience'), findsOneWidget);
      expect(find.text('dit2026001'), findsOneWidget);

      await tester.tap(find.text('Log out'));
      await tester.pump();
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
    await tester.pumpWidget(SmartUMCApp(authService: service));
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
    await tester.pumpWidget(SmartUMCApp(authService: service));
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
}
