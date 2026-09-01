import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firestore snapshot errors that often mean Auth's ID token has not reached
/// the listener yet, not that the user is forbidden from their own data.
bool isTransientFirestoreAuthError(Object error) {
  if (error is! FirebaseException) return false;
  return error.code == 'permission-denied' || error.code == 'unauthenticated';
}

Duration firestoreAuthRetryDelay(int attempt) {
  final ms = min(3000, 250 * pow(2, max(0, attempt - 1)).toInt());
  return Duration(milliseconds: ms);
}

/// Listens to [snapshots] and resubscribes on transient Auth races.
///
/// A Firestore snapshot stream **ends** on permission-denied. After sign-in the
/// ID token can lag a moment, which would otherwise leave Sharing My Gifts in a
/// stuck error state until another logout/login.
Stream<QuerySnapshot<T>> firestoreSnapshotsRetrying<T>({
  required FirebaseAuth auth,
  required Stream<QuerySnapshot<T>> Function() snapshots,
  int maxAttempts = 8,
}) {
  return Stream<QuerySnapshot<T>>.multi((listener) {
    StreamSubscription<QuerySnapshot<T>>? sub;
    var attempt = 0;
    var cancelled = false;
    Timer? retryTimer;

    Future<void> attach() async {
      if (cancelled) return;
      retryTimer?.cancel();
      await sub?.cancel();
      sub = null;

      final user = auth.currentUser;
      if (user != null) {
        try {
          await user.getIdToken(attempt > 0);
        } catch (_) {}
      }
      if (cancelled) return;

      sub = snapshots().listen(
        (snap) {
          attempt = 0;
          listener.add(snap);
        },
        onError: (Object error, StackTrace stack) {
          if (cancelled) return;
          if (!isTransientFirestoreAuthError(error) ||
              attempt >= maxAttempts) {
            listener.addError(error, stack);
            return;
          }
          attempt++;
          debugPrint(
            'firestoreSnapshotsRetrying: ${error is FirebaseException ? error.code : error} '
            '(attempt $attempt/$maxAttempts)',
          );
          retryTimer = Timer(firestoreAuthRetryDelay(attempt), attach);
        },
        onDone: () {
          if (!cancelled) listener.close();
        },
      );
    }

    listener.onCancel = () async {
      cancelled = true;
      retryTimer?.cancel();
      await sub?.cancel();
    };

    attach();
  });
}

Future<T> firestoreGetRetrying<T>({
  required FirebaseAuth auth,
  required Future<T> Function() get,
  int maxAttempts = 8,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final user = auth.currentUser;
    if (user != null) {
      try {
        await user.getIdToken(attempt > 0);
      } catch (_) {}
    }
    try {
      return await get();
    } catch (e) {
      lastError = e;
      if (!isTransientFirestoreAuthError(e) || attempt == maxAttempts - 1) {
        rethrow;
      }
      debugPrint(
        'firestoreGetRetrying: ${e is FirebaseException ? e.code : e} '
        '(attempt ${attempt + 1}/$maxAttempts)',
      );
      await Future<void>.delayed(firestoreAuthRetryDelay(attempt + 1));
    }
  }
  throw lastError!;
}
