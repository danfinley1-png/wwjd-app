/// Major app areas tracked in aggregate usage reports (no content logged).
enum UsageSection {
  seekingWisdom('seeking_wisdom', "Seeking God's Wisdom"),
  sharingGifts('sharing_gifts', 'Sharing My Gifts'),
  myReflections('my_reflections', 'My Reflections'),
  myHistory('my_history', 'My History'),
  walkTogether('walk_together', 'Walk Together'),
  prayers('prayers', 'Prayers'),
  localWorship('local_worship', 'Near Me'),
  orgCalendar('org_calendar', 'School / Organization Calendar'),
  spiritualNourishment('spiritual_nourishment', 'Spiritual Nourishment'),
  pastoralInsights('pastoral_insights', 'Pastoral Insights'),
  admin('admin', 'Administration'),
  other('other', 'Other');

  const UsageSection(this.id, this.label);

  final String id;
  final String label;

  static UsageSection? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final section in values) {
      if (section.id == id) return section;
    }
    return null;
  }
}
