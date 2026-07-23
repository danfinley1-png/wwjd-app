import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_service.dart';
import '../repositories/history_repository.dart';
import '../services/gift_service.dart';
import '../services/history_service.dart';
import '../services/share_service.dart';
import '../../models/chat_message.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final historyRepositoryProvider =
    Provider<HistoryRepository>((ref) => HistoryRepository());

final historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService(repository: ref.watch(historyRepositoryProvider));
});

final giftServiceProvider = Provider<GiftService>((ref) => GiftService());

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

/// Increment to force a new [HomeScreen] instance (e.g. after logout).
final homeRefreshKeyProvider = StateProvider<int>((ref) => 0);

final authCoordinatorProvider = Provider<AuthCoordinator>((ref) {
  return AuthCoordinator(
    authService: ref.watch(authServiceProvider),
    historyRepository: ref.watch(historyRepositoryProvider),
    giftService: ref.watch(giftServiceProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Manages persisted session history via [HistoryService] + local guest cache.
class SessionHistoryNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  HistoryService get _history => ref.read(historyServiceProvider);
  HistoryRepository get _repo => ref.read(historyRepositoryProvider);

  /// Load from Firestore, merge any local guest cache, persist, and update state.
  Future<void> loadSessionFromFirebase() async {
    final user = ref.read(authServiceProvider).currentUser;

    if (user == null) {
      final local = await _repo.loadLocalGuestCache();
      state = _repo.normalizeMessages(local);
      return;
    }

    try {
      final remoteMaps = await _history.loadSessionHistory();
      final remote = _repo.normalizeMessages(remoteMaps);
      final localMaps = await _repo.loadLocalGuestCache();
      final local = _repo.normalizeMessages(localMaps);

      final merged = local.isEmpty
          ? remote
          : _repo.mergeHistories(remote, local);

      state = merged;

      if (local.isNotEmpty || merged.length != remote.length) {
        await _history.saveSessionHistory(merged.map((m) => m.toMap()).toList());
        await _repo.clearLocalGuestCache();
      }
    } catch (e) {
      print('SessionHistoryNotifier.loadSessionFromFirebase error: $e');
      rethrow;
    }
  }

  /// Alias for startup — same as [loadSessionFromFirebase].
  Future<void> initialize() => loadSessionFromFirebase();

  /// Persist in-memory messages to local cache and Firestore when signed in.
  Future<void> saveSessionToFirebase(List<ChatMessage> messages) async {
    final persistable = messages.where((m) => m.isPersistable).toList();
    state = persistable;

    try {
      final maps = persistable.map((m) => m.toMap()).toList();
      await _repo.saveLocalGuestCache(maps);

      if (ref.read(authServiceProvider).currentUser != null) {
        await _history.saveSessionHistory(maps);
      }
    } catch (e) {
      print('SessionHistoryNotifier.saveSessionToFirebase error: $e');
      rethrow;
    }
  }

  /// Called after login/register — reload merged history from Firebase.
  Future<void> onLoginComplete() async {
    await loadSessionFromFirebase();
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
