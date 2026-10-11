import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// On permission-denied / unauthenticated, emit [fallback] instead of failing the stream.
Stream<T> firestoreStreamWithFallback<T>(
  Stream<T> source,
  T fallback, {
  String? debugLabel,
}) {
  return source.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) => sink.add(data),
      handleError: (Object error, StackTrace stack, EventSink<T> sink) {
        if (_isDeniedFirestoreAccess(error)) {
          debugPrint(
            '${debugLabel ?? 'Firestore stream'}: ${error is FirebaseException ? error.code : error} '
            '— using fallback.',
          );
          sink.add(fallback);
          return;
        }
        sink.addError(error, stack);
      },
    ),
  );
}

bool _isDeniedFirestoreAccess(Object error) {
  if (error is! FirebaseException) return false;
  return error.code == 'permission-denied' || error.code == 'unauthenticated';
}
