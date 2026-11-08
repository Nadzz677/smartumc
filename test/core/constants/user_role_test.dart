import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/constants/user_role.dart';

void main() {
  test('parses only the three canonical authorization claims', () {
    expect(UserRole.tryFromClaim('student'), UserRole.student);
    expect(UserRole.tryFromClaim('lecturer'), UserRole.lecturer);
    expect(UserRole.tryFromClaim('super_admin'), UserRole.superAdmin);
    expect(UserRole.tryFromClaim(null), isNull);
    expect(UserRole.tryFromClaim('admin'), isNull);
    expect(UserRole.tryFromClaim('STUDENT'), isNull);
  });
}
