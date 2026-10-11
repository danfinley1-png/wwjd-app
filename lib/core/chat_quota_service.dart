import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'config.dart';
import 'saints/saint_calendar.dart';

/// Read-only view of Ask WWJD limits (enforced in [chatCompletions]).
class ChatQuotaStatus {
  const ChatQuotaStatus({
    required this.isGuest,
    required this.used,
    required this.limit,
    required this.canAsk,
    this.dayKey,
  });

  final bool isGuest;
  final int used;
  final int limit;
  final bool canAsk;
  final String? dayKey;

  int get remaining => (limit - used).clamp(0, limit);

  bool get guestLimitReached => isGuest && !canAsk;
  bool get dailyLimitReached => !isGuest && !canAsk;
}

class ChatQuotaService {
  ChatQuotaService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static String newYorkDayKey([DateTime? reference]) {
    final ny = SaintCalendar.todayInNewYork(reference);
    final m = ny.month.toString().padLeft(2, '0');
    final d = ny.day.toString().padLeft(2, '0');
    return '${ny.year}-$m-$d';
  }

  Future<ChatQuotaStatus> statusForUser(User user) async {
    if (user.isAnonymous) {
      final snap = await _firestore
          .doc('users/${user.uid}/chatQuota/guest')
          .get();
      final used = _readCount(snap);
      final limit = AppConfig.guestQuestionLimit;
      return ChatQuotaStatus(
        isGuest: true,
        used: used,
        limit: limit,
        canAsk: used < limit,
      );
    }

    final dayKey = newYorkDayKey();
    final snap = await _firestore
        .doc('users/${user.uid}/chatQuota/daily/days/$dayKey')
        .get();
    final used = _readCount(snap);
    final limit = AppConfig.registeredDailyQuestionLimit;
    return ChatQuotaStatus(
      isGuest: false,
      used: used,
      limit: limit,
      canAsk: used < limit,
      dayKey: dayKey,
    );
  }

  int _readCount(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return 0;
    final raw = snap.data()?['count'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
