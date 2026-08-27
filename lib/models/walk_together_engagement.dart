/// Per-user Walk Together bookmarks, read history, and display preferences.
class WalkTogetherEngagement {
  const WalkTogetherEngagement({
    this.savedIds = const {},
    this.readIds = const {},
    this.hideRead = false,
  });

  final Set<String> savedIds;
  final Set<String> readIds;
  final bool hideRead;

  static const empty = WalkTogetherEngagement();

  bool isSaved(String journeyId) => savedIds.contains(journeyId);

  bool isRead(String journeyId) => readIds.contains(journeyId);

  factory WalkTogetherEngagement.fromMap(Map<String, dynamic>? map) {
    if (map == null) return WalkTogetherEngagement.empty;
    return WalkTogetherEngagement(
      savedIds: _stringSet(map['savedIds']),
      readIds: _stringSet(map['readIds']),
      hideRead: map['hideRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'savedIds': savedIds.toList(),
      'readIds': readIds.toList(),
      'hideRead': hideRead,
    };
  }

  static Set<String> _stringSet(dynamic value) {
    if (value is! List) return {};
    return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
  }
}

/// Feed tabs for the Walk Together community list.
enum WalkTogetherFeedTab {
  mostPopular('Most Popular'),
  kingdomChallenges('Kingdom Challenges'),
  seekingWisdom('Seeking God\'s Wisdom'),
  newest('Newest'),
  saved('Saved');

  const WalkTogetherFeedTab(this.label);
  final String label;
}
