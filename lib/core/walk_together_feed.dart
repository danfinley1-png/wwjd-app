import '../models/walk_together_engagement.dart';
import '../models/walk_together_journey.dart';

/// Applies Walk Together feed tab, hide-read, and sort rules client-side.
List<WalkTogetherJourney> filterWalkTogetherFeed({
  required List<WalkTogetherJourney> journeys,
  required WalkTogetherFeedTab tab,
  required WalkTogetherEngagement engagement,
}) {
  Iterable<WalkTogetherJourney> filtered = journeys;

  switch (tab) {
    case WalkTogetherFeedTab.mostPopular:
    case WalkTogetherFeedTab.newest:
      break;
    case WalkTogetherFeedTab.kingdomChallenges:
      filtered = filtered.where((j) => j.isGiftShare);
      break;
    case WalkTogetherFeedTab.seekingWisdom:
      filtered = filtered.where((j) => !j.isGiftShare);
      break;
    case WalkTogetherFeedTab.saved:
      filtered = filtered.where((j) => engagement.isSaved(j.id));
      break;
  }

  if (engagement.hideRead) {
    filtered = filtered.where((j) => !engagement.isRead(j.id));
  }

  final list = filtered.toList();

  if (tab == WalkTogetherFeedTab.newest) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  list.sort((a, b) {
    final upvoteCompare = b.upvotes.compareTo(a.upvotes);
    if (upvoteCompare != 0) return upvoteCompare;
    return b.createdAt.compareTo(a.createdAt);
  });
  return list;
}

String walkTogetherEmptyMessage(WalkTogetherFeedTab tab, {required bool hideRead}) {
  if (tab == WalkTogetherFeedTab.saved) {
    return 'No saved posts yet.\n\nTap the bookmark icon on a journey to save it here.';
  }
  if (tab == WalkTogetherFeedTab.kingdomChallenges) {
    return hideRead
        ? 'No unread Kingdom Challenges right now.'
        : 'No Kingdom Challenges shared yet.\n\nShare a Gift from Sharing My Gifts.';
  }
  if (tab == WalkTogetherFeedTab.seekingWisdom) {
    return hideRead
        ? 'No unread reflections right now.'
        : 'No shared reflections yet.\n\nShare a question from Seeking God\'s Wisdom.';
  }
  if (hideRead) {
    return 'You\'re all caught up — no unread journeys in this view.';
  }
  return 'No journeys shared yet.\n\nShare a Kingdom Challenge from Sharing My Gifts, '
      'or share a reflection from Seeking God\'s Wisdom.';
}
