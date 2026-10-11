import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/email/institutional_email_copy.dart';
import 'package:wwjd_app/admin/models/user_directory.dart';

void main() {
  group('WWJD-DI-only invite copy', () {
    test('does not mention unaffiliated, general admission, or empty labels', () {
      final copy = InstitutionalEmailCopy.platformInvite(
        inviteeEmail: 'friend@example.com',
      );

      expect(copy.subject, "You're invited to WWJD-DI");
      expect(copy.text.toLowerCase(), isNot(contains('unaffiliated')));
      expect(copy.text.toLowerCase(), isNot(contains('general admission')));
      expect(copy.text, contains('WWJD-DI'));
      expect(copy.text, contains('Open WWJD-DI'));
      expect(copy.text, contains(InstitutionalEmailCopy.appPublicUrl));
      expect(copy.text, isNot(contains('your organization')));
    });

    test('welcome without an organization does not invent an institution', () {
      final copy = InstitutionalEmailCopy.welcome(
        email: 'new@example.com',
        displayName: 'Pat',
      );

      expect(copy.text.toLowerCase(), isNot(contains('unaffiliated')));
      expect(copy.text, isNot(contains('through your organization')));
      expect(copy.text, contains('WWJD-DI'));
      expect(copy.text, contains(InstitutionalEmailCopy.tempPasswordPlaceholder));
    });
  });

  group('UserDirectory unaffiliated filter', () {
    test('is admin-only math: no org and no group', () {
      final directory = UserDirectory.fromJson({
        'generatedAt': '2026-09-02T12:00:00.000Z',
        'guestCount': 3,
        'users': [
          {
            'uid': 'a',
            'email': 'a@example.com',
            'displayName': 'Ann',
            'status': 'registered',
            'organizations': [
              {'id': 'o1', 'name': 'St. Mary'},
            ],
            'groups': const [],
          },
          {
            'uid': 'b',
            'email': 'b@example.com',
            'displayName': 'Ben',
            'status': 'registered',
            'organizations': const [],
            'groups': const [],
          },
        ],
        'pendingInvites': const [],
        'organizations': [
          {'id': 'o1', 'name': 'St. Mary'},
        ],
        'groups': const [],
      });

      expect(directory.guestCount, 3);
      expect(directory.unaffiliatedUsers, hasLength(1));
      expect(directory.unaffiliatedUsers.single.email, 'b@example.com');
      expect(directory.unaffiliatedUsers.single.organizationLabels, '—');
      expect(directory.users.first.organizationLabels, 'St. Mary');
    });

    test('drops empty organization and group names from labels', () {
      final user = DirectoryUser.fromJson({
        'uid': 'u',
        'email': 'u@example.com',
        'displayName': '',
        'status': 'registered',
        'organizations': [
          {'id': 'o1', 'name': '  '},
          {'id': 'o2', 'name': 'Youth Ministry'},
        ],
        'groups': [
          {'id': 'g1', 'name': ''},
        ],
      });

      expect(user.nameLabel, '—');
      expect(user.organizationLabels, 'Youth Ministry');
      expect(user.groupLabels, '—');
      expect(user.isUnaffiliated, isFalse);
    });
  });
}
