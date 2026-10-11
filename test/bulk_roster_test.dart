import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/services/platform_admin_service.dart';
import 'package:wwjd_app/models/user_profile.dart';

void main() {
  group('BulkRosterRow', () {
    test('parses created vs invited vs email honestly', () {
      final invited = BulkRosterRow.fromJson({
        'email': 'a@example.com',
        'created': false,
        'invited': true,
        'emailSent': true,
        'emailFailed': false,
        'skipped': false,
      });
      expect(invited.created, isFalse);
      expect(invited.invited, isTrue);
      expect(invited.emailSent, isTrue);

      final createdMailFail = BulkRosterRow.fromJson({
        'email': 'b@example.com',
        'created': true,
        'invited': true,
        'emailSent': false,
        'emailFailed': true,
        'emailError': 'Resend 403',
        'temporaryPassword': 'WwjdTemp7',
        'skipped': false,
      });
      expect(createdMailFail.created, isTrue);
      expect(createdMailFail.emailFailed, isTrue);
      expect(createdMailFail.temporaryPassword, 'WwjdTemp7');

      final skipped = BulkRosterRow.fromJson({
        'email': 'c@example.com',
        'skipped': true,
        'skipReason': 'already_exists',
      });
      expect(skipped.skipLabel, 'Already has an account');
    });
  });

  group('Mode B password gate', () {
    test('mustChangePassword blocks the rest of the app', () {
      const profile = UserProfile(
        uid: 'u1',
        mustChangePassword: true,
        hasSeenInstitutionalWelcome: false,
      );
      expect(profile.needsPasswordSetup, isTrue);
      expect(profile.shouldShowInstitutionalWelcome, isFalse);
    });
  });
}
