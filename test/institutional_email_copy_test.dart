import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/email/institutional_email_copy.dart';
import 'package:wwjd_app/admin/models/admin_role.dart';

void main() {
  group('InstitutionalEmailCopy', () {
    test('org invite names WWJD-DI and includes home-screen steps', () {
      final copy = InstitutionalEmailCopy.organizationInvite(
        inviteeEmail: 'member@example.com',
        organizationName: 'St. Mary Parish',
        role: AdminRole.member,
        groupNames: const ['Youth'],
      );

      expect(copy.subject, contains('WWJD-DI'));
      expect(copy.subject, contains('St. Mary Parish'));
      expect(copy.text, contains('WWJD-DI'));
      expect(copy.text, contains('Open WWJD-DI'));
      expect(copy.text, contains(InstitutionalEmailCopy.appPublicUrl));
      expect(copy.text, contains('Add to Home Screen'));
      expect(copy.text, contains('Youth'));
    });

    test('group invite names WWJD-DI and includes home-screen steps', () {
      final copy = InstitutionalEmailCopy.groupInvite(
        groupName: 'Choir',
        organizationName: 'St. Mary Parish',
      );

      expect(copy.subject, contains('WWJD-DI'));
      expect(copy.text, contains('Choir'));
      expect(copy.text, contains('Open WWJD-DI'));
      expect(
        copy.text,
        contains('iPhone: Safari → Share → Add to Home Screen. Use the WWJD-DI icon.'),
      );
    });

    test('welcome preview uses password placeholder, not a live secret', () {
      final copy = InstitutionalEmailCopy.welcome(
        email: 'new@example.com',
        displayName: 'Jane Smith',
        organizationName: 'St. Mary Parish',
      );

      expect(copy.subject, contains('WWJD-DI'));
      expect(copy.text, contains(InstitutionalEmailCopy.tempPasswordPlaceholder));
      expect(copy.text, contains('Open WWJD-DI'));
      expect(copy.text, contains('Jane'));
    });

    test('platform invite is WWJD-DI only and includes home-screen steps', () {
      final copy = InstitutionalEmailCopy.platformInvite(
        inviteeEmail: 'friend@example.com',
      );

      expect(copy.subject, "You're invited to WWJD-DI");
      expect(copy.text, contains('Open WWJD-DI'));
      expect(copy.text.toLowerCase(), isNot(contains('unaffiliated')));
    });

    test('overrideFields are empty until the admin edits', () {
      const draft = EmailSendDraft(
        subject: 'Welcome to WWJD-DI',
        text: 'Hello',
        edited: false,
      );
      expect(draft.overrideFields, isEmpty);

      const edited = EmailSendDraft(
        subject: 'Welcome to WWJD-DI',
        text: 'Custom body',
        edited: true,
      );
      expect(edited.overrideFields['emailSubject'], 'Welcome to WWJD-DI');
      expect(edited.overrideFields['emailText'], 'Custom body');
    });
  });
}
