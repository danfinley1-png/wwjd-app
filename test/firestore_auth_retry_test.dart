import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/firestore_auth_retry.dart';

void main() {
  group('isTransientFirestoreAuthError', () {
    test('retries permission-denied and unauthenticated', () {
      expect(
        isTransientFirestoreAuthError(
          FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        ),
        isTrue,
      );
      expect(
        isTransientFirestoreAuthError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
        ),
        isTrue,
      );
    });

    test('does not retry unrelated Firestore errors', () {
      expect(
        isTransientFirestoreAuthError(
          FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
        ),
        isFalse,
      );
      expect(isTransientFirestoreAuthError(StateError('nope')), isFalse);
    });
  });

  test('firestoreAuthRetryDelay backs off then caps', () {
    expect(firestoreAuthRetryDelay(1), const Duration(milliseconds: 250));
    expect(firestoreAuthRetryDelay(2), const Duration(milliseconds: 500));
    expect(firestoreAuthRetryDelay(8).inMilliseconds, lessThanOrEqualTo(3000));
  });
}
