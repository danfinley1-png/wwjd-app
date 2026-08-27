import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/auth/password_strength.dart';
import 'package:wwjd_app/models/user_profile.dart';

void main() {
  group('PasswordStrength', () {
    test('rejects short passwords', () {
      expect(PasswordStrength.validate('abc1'), isNotNull);
    });

    test('rejects passwords without letters', () {
      expect(PasswordStrength.validate('12345678'), isNotNull);
    });

    test('rejects passwords without numbers', () {
      expect(PasswordStrength.validate('abcdefgh'), isNotNull);
    });

    test('accepts valid passwords', () {
      expect(PasswordStrength.validate('SecurePass1'), isNull);
    });
  });

  group('UserProfile institutional onboarding', () {
    test('needsPasswordSetup when mustChangePassword is true', () {
      const profile = UserProfile(
        uid: 'u1',
        mustChangePassword: true,
      );
      expect(profile.needsPasswordSetup, isTrue);
      expect(profile.shouldShowInstitutionalWelcome, isFalse);
    });

    test('shouldShowInstitutionalWelcome after password setup', () {
      const profile = UserProfile(
        uid: 'u1',
        mustChangePassword: false,
        hasSeenInstitutionalWelcome: false,
        provisionedByOrgId: 'org1',
      );
      expect(profile.needsPasswordSetup, isFalse);
      expect(profile.shouldShowInstitutionalWelcome, isTrue);
    });

    test('welcome hidden after seen', () {
      const profile = UserProfile(
        uid: 'u1',
        hasSeenInstitutionalWelcome: true,
      );
      expect(profile.shouldShowInstitutionalWelcome, isFalse);
    });
  });
}
