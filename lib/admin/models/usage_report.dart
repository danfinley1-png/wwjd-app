/// Time window for the Super Admin usage report.
enum UsageReportPeriod {
  days7(7, 'Last 7 days'),
  days30(30, 'Last 30 days'),
  days90(90, 'Last 90 days'),
  allTime(null, 'All time');

  const UsageReportPeriod(this.days, this.label);

  final int? days;
  final String label;
}

/// Aggregate usage metrics — no personal spiritual content or user identity.
class UsageReport {
  const UsageReport({
    required this.period,
    required this.generatedAt,
    this.trackingStartedAt,
    required this.totalRegisteredUsers,
    required this.newRegistrationsInPeriod,
    required this.activeUsers7Days,
    required this.activeUsers30Days,
    required this.guestSessionsInPeriod,
    required this.totalSessionCount,
    required this.totalSessionDurationSeconds,
    required this.sessionsByDevice,
    required this.sectionViews,
    required this.userMetricsFromAuth,
    this.note,
  });

  final UsageReportPeriod period;
  final DateTime generatedAt;
  final DateTime? trackingStartedAt;
  final int totalRegisteredUsers;
  final int newRegistrationsInPeriod;
  final int activeUsers7Days;
  final int activeUsers30Days;
  final int guestSessionsInPeriod;
  final int totalSessionCount;
  final int totalSessionDurationSeconds;
  final Map<String, int> sessionsByDevice;
  final Map<String, int> sectionViews;
  final bool userMetricsFromAuth;
  final String? note;

  double get averageSessionLengthSeconds =>
      totalSessionCount == 0
          ? 0
          : totalSessionDurationSeconds / totalSessionCount;

  double get totalScreenTimeHours => totalSessionDurationSeconds / 3600;

  int sectionViewCount(String sectionId) => sectionViews[sectionId] ?? 0;

  int deviceSessionCount(String deviceId) => sessionsByDevice[deviceId] ?? 0;

  double deviceSessionShare(String deviceId) {
    if (totalSessionCount == 0) return 0;
    return deviceSessionCount(deviceId) / totalSessionCount;
  }

  double sectionShare(String sectionId) {
    final total = sectionViews.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return 0;
    return sectionViewCount(sectionId) / total;
  }

  factory UsageReport.fromJson(
    Map<String, dynamic> json,
    UsageReportPeriod period,
  ) {
    return UsageReport(
      period: period,
      generatedAt: DateTime.now(),
      trackingStartedAt: _parseTimestamp(json['trackingStartedAt']),
      totalRegisteredUsers: _asInt(json['totalRegisteredUsers']),
      newRegistrationsInPeriod: _asInt(json['newRegistrationsInPeriod']),
      activeUsers7Days: _asInt(json['activeUsers7Days']),
      activeUsers30Days: _asInt(json['activeUsers30Days']),
      guestSessionsInPeriod: _asInt(json['guestSessionsInPeriod']),
      totalSessionCount: _asInt(json['totalSessionCount']),
      totalSessionDurationSeconds:
          _asInt(json['totalSessionDurationSeconds']),
      sessionsByDevice: _stringIntMap(json['sessionsByDevice']),
      sectionViews: _stringIntMap(json['sectionViews']),
      userMetricsFromAuth: json['userMetricsFromAuth'] as bool? ?? true,
      note: json['note'] as String?,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value['_seconds'] as num).toInt() * 1000,
      );
    }
    return null;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static Map<String, int> _stringIntMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, val) => MapEntry(key.toString(), _asInt(val)),
    );
  }
}
