import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/auth/password_strength.dart';

void main() {
  group('Password change validation', () {
    test('accepts strong password', () {
      expect(PasswordStrength.validate('SecurePass1'), isNull);
    });

    test('rejects short password', () {
      expect(PasswordStrength.validate('Ab1'), isNotNull);
    });
  });
}
