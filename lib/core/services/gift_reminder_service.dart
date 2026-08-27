import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/gift_activity.dart';
import '../gift_reminder_utils.dart';
import '../gift_tracking.dart';

typedef GiftReminderTapHandler = void Function(String giftId);

/// Schedules gentle local reminders on Android and iOS native builds.
/// Web/PWA: settings are saved on the gift; use Add to Calendar instead.
class GiftReminderService {
  GiftReminderService._();
  static final GiftReminderService instance = GiftReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  GiftReminderTapHandler? _onGiftReminderTap;

  /// Gift id to open after cold start from a notification tap.
  String? pendingLaunchGiftId;

  void setTapHandler(GiftReminderTapHandler? handler) {
    _onGiftReminderTap = handler;
  }

  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        pendingLaunchGiftId = payload;
      }
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final giftId = response.payload?.trim();
    if (giftId == null || giftId.isEmpty) return;
    _onGiftReminderTap?.call(giftId);
  }

  void consumePendingLaunchTap() {
    final giftId = pendingLaunchGiftId?.trim();
    if (giftId == null || giftId.isEmpty) return;
    pendingLaunchGiftId = null;
    _onGiftReminderTap?.call(giftId);
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb || !_initialized) return false;

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    return true;
  }

  Future<void> syncAll(List<GiftActivity> gifts) async {
    if (kIsWeb || !_initialized) return;

    for (final gift in gifts) {
      if (gift.hasReminder && gift.isActive) {
        await schedule(gift);
      } else {
        await cancel(gift);
      }
    }
  }

  Future<void> schedule(GiftActivity gift) async {
    if (kIsWeb || !_initialized || !gift.hasReminder || !gift.isActive) {
      return;
    }

    await cancel(gift);

    final time = GiftReminderUtils.parseTime(gift.specificTime);
    final details = _notificationDetails(gift);

    if (GiftTracking.isOneTime(gift)) {
      await _scheduleOneTime(gift, time, details);
      return;
    }

    if (gift.frequency.toLowerCase() == 'weekly' &&
        gift.daysOfWeek.isNotEmpty) {
      final weekdayIndexes = GiftReminderUtils.weekdayIndexesForGift(gift);
      for (final index in weekdayIndexes) {
        await _scheduleWeeklyOnDay(
          gift,
          time,
          details,
          weekdayIndex: index,
        );
      }
      return;
    }

    final components = gift.frequency.toLowerCase() == 'weekly'
        ? DateTimeComponents.dayOfWeekAndTime
        : DateTimeComponents.time;

    await _plugin.zonedSchedule(
      GiftReminderUtils.notificationId(gift),
      GiftReminderUtils.notificationTitle(),
      GiftReminderUtils.notificationBody(gift),
      _nextInstance(time),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: components,
      payload: gift.id,
    );
  }

  Future<void> _scheduleOneTime(
    GiftActivity gift,
    TimeOfDay time,
    NotificationDetails details,
  ) async {
    var when = _nextInstance(time);
    if (gift.dueDate != null) {
      final due = gift.dueDate!;
      when = tz.TZDateTime(
        tz.local,
        due.year,
        due.month,
        due.day,
        time.hour,
        time.minute,
      );
      if (when.isBefore(tz.TZDateTime.now(tz.local))) {
        when = _nextInstance(time);
      }
    }

    await _plugin.zonedSchedule(
      GiftReminderUtils.notificationId(gift),
      GiftReminderUtils.notificationTitle(),
      GiftReminderUtils.notificationBody(gift),
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: gift.id,
    );
  }

  Future<void> _scheduleWeeklyOnDay(
    GiftActivity gift,
    TimeOfDay time,
    NotificationDetails details, {
    required int weekdayIndex,
  }) async {
    final when = _nextInstanceOnWeekday(time, weekdayIndex);
    await _plugin.zonedSchedule(
      GiftReminderUtils.notificationId(gift, weekdayIndex: weekdayIndex),
      GiftReminderUtils.notificationTitle(),
      GiftReminderUtils.notificationBody(gift),
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: gift.id,
    );
  }

  Future<void> cancel(GiftActivity gift) async {
    if (kIsWeb || !_initialized) return;

    await _plugin.cancel(GiftReminderUtils.notificationId(gift));
    for (var i = 0; i < GiftReminderUtils.weekdayNames.length; i++) {
      await _plugin.cancel(
        GiftReminderUtils.notificationId(gift, weekdayIndex: i),
      );
    }
  }

  NotificationDetails _notificationDetails(GiftActivity gift) {
    final body = GiftReminderUtils.notificationBody(gift);
    final android = AndroidNotificationDetails(
      'wwjd_gift_reminders',
      'Kingdom Challenge Reminders',
      channelDescription:
          'Gentle reminders for your Sharing My Gifts activities.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: android, iOS: ios);
  }

  tz.TZDateTime _nextInstance(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOnWeekday(TimeOfDay time, int weekdayIndex) {
    final now = tz.TZDateTime.now(tz.local);
    final targetWeekday = weekdayIndex + 1; // Monday=1
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    while (scheduled.weekday != targetWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
