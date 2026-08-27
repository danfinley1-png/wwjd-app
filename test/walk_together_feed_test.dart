import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/walk_together_feed.dart';
import 'package:wwjd_app/models/walk_together_engagement.dart';
import 'package:wwjd_app/models/walk_together_journey.dart';

WalkTogetherJourney _journey({
  required String id,
  bool gift = false,
  int upvotes = 0,
  DateTime? createdAt,
}) {
  return WalkTogetherJourney(
    id: id,
    title: id,
    question: 'Q $id',
    response: 'R $id',
    upvotes: upvotes,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    shareType: gift ? 'gift' : 'reflection',
  );
}

void main() {
  group('filterWalkTogetherFeed', () {
    final journeys = [
      _journey(id: 'gift1', gift: true, upvotes: 5, createdAt: DateTime(2026, 1, 3)),
      _journey(id: 'refl1', upvotes: 10, createdAt: DateTime(2026, 1, 2)),
      _journey(id: 'refl2', upvotes: 2, createdAt: DateTime(2026, 1, 4)),
    ];

    const engagement = WalkTogetherEngagement(
      savedIds: {'gift1'},
      readIds: {'refl1'},
    );

    test('kingdom challenges filter', () {
      final result = filterWalkTogetherFeed(
        journeys: journeys,
        tab: WalkTogetherFeedTab.kingdomChallenges,
        engagement: engagement,
      );
      expect(result.map((j) => j.id), ['gift1']);
    });

    test('seeking wisdom filter', () {
      final result = filterWalkTogetherFeed(
        journeys: journeys,
        tab: WalkTogetherFeedTab.seekingWisdom,
        engagement: engagement,
      );
      expect(result.map((j) => j.id), ['refl1', 'refl2']);
    });

    test('saved filter', () {
      final result = filterWalkTogetherFeed(
        journeys: journeys,
        tab: WalkTogetherFeedTab.saved,
        engagement: engagement,
      );
      expect(result.map((j) => j.id), ['gift1']);
    });

    test('newest sorts by createdAt', () {
      final result = filterWalkTogetherFeed(
        journeys: journeys,
        tab: WalkTogetherFeedTab.newest,
        engagement: WalkTogetherEngagement.empty,
      );
      expect(result.map((j) => j.id), ['refl2', 'gift1', 'refl1']);
    });

    test('most popular sorts by upvotes', () {
      final result = filterWalkTogetherFeed(
        journeys: journeys,
        tab: WalkTogetherFeedTab.mostPopular,
        engagement: WalkTogetherEngagement.empty,
      );
      expect(result.map((j) => j.id), ['refl1', 'gift1', 'refl2']);
    });

    test('hide read removes opened posts', () {
      final result = filterWalkTogetherFeed(
        journeys: journeys,
        tab: WalkTogetherFeedTab.mostPopular,
        engagement: const WalkTogetherEngagement(
          readIds: {'refl1'},
          hideRead: true,
        ),
      );
      expect(result.map((j) => j.id), ['gift1', 'refl2']);
    });
  });
}
