import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/authentication/auth_user.dart';
import 'package:smartumc/core/constants/user_role.dart';

void main() {
  test('requires canonical active trusted claims and a matching active profile', () {
    expect(
      () => AuthUser.fromTrustedSources(
        uid: 'synthetic-uid',
        claims: const {},
        profile: const {'role': 'student', 'status': 'active', 'matricNumber': 'dit2026001'},
      ),
      throwsA(isA<AuthAuthorizationException>()),
    );
    expect(
      () => AuthUser.fromTrustedSources(
        uid: 'synthetic-uid',
        claims: const {'role': 'owner', 'active': true},
        profile: const {'role': 'owner', 'status': 'active'},
      ),
      throwsA(isA<AuthAuthorizationException>()),
    );
    expect(
      () => AuthUser.fromTrustedSources(
        uid: 'synthetic-uid',
        claims: const {'role': 'student', 'active': false},
        profile: const {'role': 'student', 'status': 'active', 'matricNumber': 'dit2026001'},
      ),
      throwsA(isA<AuthAuthorizationException>()),
    );
  });

  test('accepts matching claims and profile but rejects malformed role and matric data', () {
    final user = AuthUser.fromTrustedSources(
      uid: 'synthetic-uid',
      claims: const {'role': 'student', 'active': true},
      profile: const {'role': 'student', 'status': 'active', 'matricNumber': 'DIT2026001'},
    );
    expect(user.role, UserRole.student);
    expect(user.matricNumber, 'dit2026001');

    expect(
      () => AuthUser.fromTrustedSources(
        uid: 'synthetic-uid',
        claims: const {'role': ' Student ', 'active': true},
        profile: const {'role': 'student', 'status': 'active', 'matricNumber': 'dit2026001'},
      ),
      throwsA(isA<AuthAuthorizationException>()),
    );
  });
}
