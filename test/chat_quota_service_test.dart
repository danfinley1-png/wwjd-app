import 'package:flutter_test/flutter_test.dart';

import 'package:wwjd_app/core/chat_quota_service.dart';
import 'package:wwjd_app/core/config.dart';

void main() {
  test('guest and registered limits match config', () {
    expect(AppConfig.guestQuestionLimit, 3);
    expect(AppConfig.registeredDailyQuestionLimit, 25);
  });

  test('newYorkDayKey formats yyyy-MM-dd', () {
    final key = ChatQuotaService.newYorkDayKey(DateTime.utc(2026, 3, 22, 5));
    expect(key, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });
}
