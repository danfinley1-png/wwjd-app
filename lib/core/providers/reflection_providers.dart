import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reflection_entry.dart';
import '../../models/reflection_thread.dart';
import '../services/reflection_service.dart';

final reflectionServiceProvider = Provider<ReflectionService>((ref) {
  return ReflectionService();
});

final reflectionThreadsStreamProvider =
    StreamProvider<List<ReflectionThread>>((ref) {
  return ref.watch(reflectionServiceProvider).watchThreads();
});

final reflectionThreadStreamProvider =
    StreamProvider.family<ReflectionThread?, String>((ref, threadId) {
  return ref.watch(reflectionServiceProvider).watchThread(threadId);
});

final reflectionEntriesStreamProvider =
    StreamProvider.family<List<ReflectionEntry>, String>((ref, threadId) {
  return ref.watch(reflectionServiceProvider).watchEntries(threadId);
});
