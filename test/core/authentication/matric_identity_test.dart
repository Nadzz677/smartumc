import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/authentication/matric_identity.dart';
import 'package:smartumc/core/constants/user_role.dart';

void main() {
  test('normalizes matric identifiers and generates the fixed internal alias', () {
    expect(MatricIdentity.normalize(' DIT2026001 '), 'dit2026001');
    expect(MatricIdentity.emailAlias('DIT2026001'), 'dit2026001@students.smartumc.invalid');
  });

  test('rejects malformed matric identifiers before Auth is called', () {
    for (final input in ['', 'dit 2026001', 'student@example.com', '!invalid']) {
      expect(() => MatricIdentity.emailAlias(input), throwsFormatException);
    }
  });

  test('binds a student profile matric to its Firebase Auth email alias', () {
    expect(
      MatricIdentity.matchesAuthProfile(
        authEmail: 'dit2026001@students.smartumc.invalid',
        profileEmail: 'dit2026001@students.smartumc.invalid',
        role: UserRole.student,
        matricNumber: 'DIT2026001',
      ),
      isTrue,
    );
    expect(
      MatricIdentity.matchesAuthProfile(
        authEmail: 'dit2026001@students.smartumc.invalid',
        profileEmail: 'dit2026001@students.smartumc.invalid',
        role: UserRole.student,
        matricNumber: 'DIT2026002',
      ),
      isFalse,
    );
    expect(
      MatricIdentity.matchesAuthProfile(
        authEmail: 'lecturer@staff.smartumc.invalid',
        profileEmail: 'lecturer@staff.smartumc.invalid',
        role: UserRole.lecturer,
        matricNumber: null,
      ),
      isTrue,
    );
  });
}
