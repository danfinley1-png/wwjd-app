import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/models/user_profile.dart';

void main() {
  group('UserProfile.isValidDisplayName', () {
    test('rejects empty, guest, and email-like values', () {
      expect(UserProfile.isValidDisplayName(null), isFalse);
      expect(UserProfile.isValidDisplayName(''), isFalse);
      expect(UserProfile.isValidDisplayName('guest'), isFalse);
      expect(UserProfile.isValidDisplayName('user@example.com'), isFalse);
    });

    test('rejects email local-part when account email is known', () {
      expect(
        UserProfile.isValidDisplayName(
          'jane.doe',
          accountEmail: 'jane.doe@example.com',
        ),
        isFalse,
      );
      expect(
        UserProfile.isValidDisplayName(
          'Jane',
          accountEmail: 'jane.doe@example.com',
        ),
        isTrue,
      );
    });

    test('hasDisplayName respects account email', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'danfi',
      );
      expect(profile.hasDisplayName('danfi@gmail.com'), isFalse);
      expect(profile.hasDisplayName('other@gmail.com'), isTrue);
    });
  });
}
