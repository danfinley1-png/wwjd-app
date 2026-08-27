import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/usage_report.dart';
import 'package:wwjd_app/core/analytics/usage_device_class.dart';
import 'package:wwjd_app/core/analytics/usage_section.dart';

void main() {
  group('UsageSection', () {
    test('fromId resolves known sections', () {
      expect(
        UsageSection.fromId('seeking_wisdom'),
        UsageSection.seekingWisdom,
      );
      expect(UsageSection.fromId('unknown'), isNull);
    });
  });

  group('UsageDeviceClass', () {
    test('sessionsField maps to Firestore counter names', () {
      expect(UsageDeviceClass.desktop.sessionsField, 'sessionsDesktop');
      expect(UsageDeviceClass.mobile.sessionsField, 'sessionsMobile');
    });
  });

  group('UsageReport', () {
    test('fromJson parses aggregate payload', () {
      final report = UsageReport.fromJson(
        {
          'totalRegisteredUsers': 120,
          'newRegistrationsInPeriod': 5,
          'activeUsers7Days': 40,
          'activeUsers30Days': 80,
          'guestSessionsInPeriod': 25,
          'totalSessionCount': 200,
          'totalSessionDurationSeconds': 36000,
          'sessionsByDevice': {'desktop': 90, 'mobile': 100, 'tablet': 10},
          'sectionViews': {'prayers': 30, 'sharing_gifts': 12},
          'userMetricsFromAuth': true,
        },
        UsageReportPeriod.days30,
      );

      expect(report.totalRegisteredUsers, 120);
      expect(report.averageSessionLengthSeconds, 180);
      expect(report.deviceSessionShare('mobile'), closeTo(0.5, 0.001));
      expect(report.sectionShare('prayers'), closeTo(30 / 42, 0.001));
    });
  });
}
