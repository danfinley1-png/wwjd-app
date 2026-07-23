import '../repositories/history_repository.dart';
import '../../models/chat_message.dart';

/// Firestore persistence layer for MyHistory session data.
class HistoryService {
  HistoryService({HistoryRepository? repository})
      : _repository = repository ?? HistoryRepository();

  final HistoryRepository _repository;

  Future<void> saveSessionHistory(List<Map<String, dynamic>> history) async {
    final messages = _repository.normalizeMessages(history);
    await _repository.saveHistory(messages);
  }

  Future<List<Map<String, dynamic>>> loadSessionHistory() async {
    final messages = await _repository.loadHistory();
    return messages.map((m) => m.toMap()).toList();
  }

  Future<HistoryMergeResult> mergeGuestHistory(
    List<ChatMessage> guestHistory, {
    String? anonymousUid,
  }) async {
    return _repository.migrateGuestHistoryToCurrentUser(
      inMemoryHistory: guestHistory,
      anonymousUid: anonymousUid,
    );
  }

  Future<void> deleteConversation(String userQuestion) async {
    await _repository.deleteConversation(userQuestion);
  }

  /// Restores a gift's linked conversation into My History when missing.
  /// Returns true if new history entries were added.
  Future<bool> restoreGiftToHistory({
    required String question,
    required String response,
  }) async {
    return _repository.appendConversationIfMissing(
      question: question,
      response: response,
    );
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
  }
}
