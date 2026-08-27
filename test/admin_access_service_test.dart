import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/config/admin_config.dart';
import 'package:wwjd_app/admin/services/admin_access_service.dart';

void main() {
  group('adminAccessDeniedMessage', () {
    test('memberOnly explains leader restriction', () {
      final message = adminAccessDeniedMessage(AdminAccessStatus.memberOnly);
      expect(message, contains('restricted'));
      expect(message, contains('leader'));
    });

    test('guestNotAllowed rejects anonymous sessions', () {
      final message = adminAccessDeniedMessage(AdminAccessStatus.guestNotAllowed);
      expect(message, contains('Guest'));
    });

    test('authorized returns empty message', () {
      expect(adminAccessDeniedMessage(AdminAccessStatus.authorized), isEmpty);
    });
  });

  group('AdminConfig foundation admins', () {
    test('dan.finley@verizon.net is a foundation administrator', () {
      expect(AdminConfig.isFoundationAdmin('dan.finley@verizon.net'), isTrue);
      expect(AdminConfig.isFoundationAdmin('Dan.Finley@Verizon.net'), isTrue);
    });

    test('other emails are not foundation administrators', () {
      expect(AdminConfig.isFoundationAdmin('other@example.com'), isFalse);
    });
  });
}
