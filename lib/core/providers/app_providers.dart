import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../admin/config/admin_config.dart';
import '../auth/auth_service.dart';
import '../repositories/history_repository.dart';
import '../services/gift_service.dart';
import '../services/gift_reminder_service.dart';
import '../../models/gift_activity.dart';
import '../services/history_service.dart';
import '../services/share_service.dart';
import '../services/user_groups_service.dart';
import '../services/group_share_service.dart';
import '../services/group_practice_service.dart';
import '../../models/group_practice_instance.dart';
import '../models/shareable_group.dart';
import '../services/walk_together_service.dart';
import '../services/walk_together_engagement_service.dart';
import '../services/user_profile_service.dart';
import '../../models/walk_together_engagement.dart';
import '../../models/chat_message.dart';
import '../../models/user_profile.dart';
import '../../models/walk_together_journey.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final historyRepositoryProvider =
    Provider<HistoryRepository>((ref) => HistoryRepository());

final historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService(repository: ref.watch(historyRepositoryProvider));
});

final giftServiceProvider = Provider<GiftService>((ref) => GiftService());

final giftReminderServiceProvider =
    Provider<GiftReminderService>((ref) => GiftReminderService.instance);

final userGiftsStreamProvider = StreamProvider<List<GiftActivity>>((ref) {
  return ref.watch(giftServiceProvider).getUserGiftsStream();
});

final groupPracticeServiceProvider =
    Provider<GroupPracticeService>((ref) => GroupPracticeService());

final userGroupPracticesStreamProvider =
    StreamProvider<List<GroupPracticeInstance>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(groupPracticeServiceProvider).watchGroupPractices();
});

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

final userGroupsServiceProvider =
    Provider<UserGroupsService>((ref) => UserGroupsService());

final groupShareServiceProvider =
    Provider<GroupShareService>((ref) => GroupShareService());

final shareableGroupsProvider = StreamProvider<List<ShareableGroup>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(userGroupsServiceProvider).watchShareableGroups();
});

final profileGroupMembershipsProvider = StreamProvider<List<ShareableGroup>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(userGroupsServiceProvider).watchProfileGroupMemberships();
});

final isSuperAdminUserProvider = StreamProvider<bool>((ref) {
  ref.watch(authStateProvider);
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return Stream.value(false);
  if (AdminConfig.isFoundationAdmin(user.email)) {
    return Stream.value(true);
  }
  return FirebaseFirestore.instance
      .collection('platformAdmins')
      .doc(user.uid)
      .snapshots()
      .map((snap) => snap.exists);
});

final userProfileServiceProvider =
    Provider<UserProfileService>((ref) => UserProfileService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  ref.watch(authStateProvider);
  final uid = ref.read(authServiceProvider).currentUser?.uid;
  return ref.read(userProfileServiceProvider).watchProfileForUid(uid);
});

final walkTogetherServiceProvider =
    Provider<WalkTogetherService>((ref) => WalkTogetherService());

final walkTogetherJourneysProvider =
    StreamProvider<List<WalkTogetherJourney>>((ref) {
  return ref.watch(walkTogetherServiceProvider).getJourneysStream();
});

final walkTogetherEngagementServiceProvider =
    Provider<WalkTogetherEngagementService>(
  (ref) => WalkTogetherEngagementService(),
);

final walkTogetherEngagementProvider =
    StreamProvider<WalkTogetherEngagement>((ref) {
  return ref.watch(walkTogetherEngagementServiceProvider).watchEngagement();
});

final walkTogetherFeedTabProvider =
    StateProvider<WalkTogetherFeedTab>((ref) => WalkTogetherFeedTab.mostPopular);

/// Tracks Walk Together upvotes for the current app session (cleared on logout).
class WalkTogetherSessionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  bool hasUpvoted(String journeyId) => state.contains(journeyId);

  void markUpvoted(String journeyId) {
    state = {...state, journeyId};
  }

  void clear() => state = {};
}

final walkTogetherSessionProvider =
    NotifierProvider<WalkTogetherSessionNotifier, Set<String>>(
  WalkTogetherSessionNotifier.new,
);

/// Increment to force a new [HomeScreen] instance (e.g. after logout).
final homeRefreshKeyProvider = StateProvider<int>((ref) => 0);

final authCoordinatorProvider = Provider<AuthCoordinator>((ref) {
  return AuthCoordinator(
    authService: ref.watch(authServiceProvider),
    historyRepository: ref.watch(historyRepositoryProvider),
    giftService: ref.watch(giftServiceProvider),
  );
});

/// Manages persisted session history via [HistoryService] + local guest cache.
class SessionHistoryNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  HistoryService get _history => ref.read(historyServiceProvider);
  HistoryRepository get _repo => ref.read(historyRepositoryProvider);

  /// Load from Firestore, merge any local guest cache, persist, and update state.
  Future<void> loadSessionFromFirebase({bool allowAnonymousFallback = true}) async {
    final auth = ref.read(authServiceProvider);
    await auth.waitForAuthReady();

    var user = auth.currentUser;
    if (user == null && allowAnonymousFallback) {
      await ref.read(authCoordinatorProvider).ensureSession(allowGuest: true);
      user = auth.currentUser;
    }

    final localMaps = await _repo.loadLocalGuestCache();
    final local = _repo.normalizeMessages(localMaps);

    if (user == null) {
      state = local;
      return;
    }

    try {
      final remoteMaps = await _history.loadSessionHistory();
      final remote = _repo.normalizeMessages(remoteMaps);

      final merged = local.isEmpty
          ? remote
          : _repo.mergeHistories(remote, local);

      state = merged;

      if (local.isNotEmpty || merged.length != remote.length) {
        try {
          await _history.saveSessionHistory(merged.map((m) => m.toMap()).toList());
          await _repo.clearLocalGuestCache();
        } catch (e) {
          print('SessionHistoryNotifier: could not sync merged history to Firestore: $e');
        }
      }
    } catch (e) {
      print('SessionHistoryNotifier.loadSessionFromFirebase error: $e');
      if (local.isNotEmpty) {
        state = local;
        return;
      }
      rethrow;
    }
  }

  /// Alias for startup — same as [loadSessionFromFirebase].
  Future<void> initialize() => loadSessionFromFirebase();

  /// Persist in-memory messages to local cache and Firestore when signed in.
  Future<void> saveSessionToFirebase(List<ChatMessage> messages) async {
    final incoming = messages.where((m) => m.isPersistable).toList();
    if (incoming.isEmpty && state.isEmpty) return;

    final merged = incoming.isEmpty
        ? state
        : _repo.mergeHistories(state, incoming);

    state = merged;

    final maps = merged.map((m) => m.toMap()).toList();
    await _repo.saveLocalGuestCache(maps);

    if (ref.read(authServiceProvider).currentUser != null) {
      try {
        await _history.saveSessionHistory(maps);
      } catch (e) {
        print('SessionHistoryNotifier.saveSessionToFirebase Firestore error: $e');
        rethrow;
      }
    }
  }

  /// Called after login/register — reload merged history from Firebase.
  Future<void> onLoginComplete() async {
    try {
      await loadSessionFromFirebase(allowAnonymousFallback: false).timeout(
        const Duration(seconds: 20),
      );
    } catch (e) {
      print('SessionHistoryNotifier.onLoginComplete error: $e');
    }
  }

  /// Clears in-memory and local guest cache on logout (Firestore account data is kept).
  Future<void> clearSessionForLogout() async {
    state = [];
    await _repo.clearLocalGuestCache();
  }

  List<ChatMessage> get current => state;
}

final sessionHistoryProvider =
    NotifierProvider<SessionHistoryNotifier, List<ChatMessage>>(
  SessionHistoryNotifier.new,
);

String mergeFeedbackMessage(HistoryMergeResult result) {
  if (result.newlyAddedCount <= 0) {
    return 'Signed in successfully.';
  }
  if (result.existingMessageCount > 0) {
    return 'Your guest progress has been merged with your saved history '
        '(${result.newlyAddedCount} new item${result.newlyAddedCount == 1 ? '' : 's'} added).';
  }
  return 'Your guest progress has been saved to your account.';
}

void showMigrationSnackBar(
  BuildContext context,
  AuthMigrationResult result,
) {
  if (!result.shouldShowMergeFeedback || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mergeFeedbackMessage(result.mergeResult!)),
      duration: const Duration(seconds: 5),
    ),
  );
}
