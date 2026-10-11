import '../../models/pastoral_theme.dart';

/// One anonymized question event used for aggregation.
///
/// Never includes question text, display name, email, or uid.
class QuestionThemeEvent {
  const QuestionThemeEvent({
    required this.theme,
    required this.source,
    required this.recordedAt,
    required this.userHash,
    this.organizationId,
    this.groupId,
  });

  final PastoralThemeCategory theme;
  final QuestionThemeSource source;
  final DateTime recordedAt;
  final String userHash;
  final String? organizationId;
  final String? groupId;
}

class QuestionThemeCell {
  const QuestionThemeCell({
    required this.theme,
    required this.suppressed,
    this.distinctUsers,
    this.previousDistinctUsers,
    this.previousSuppressed = true,
    this.seekingWisdomUsers,
    this.seekingWisdomSuppressed = true,
    this.walkTogetherUsers,
    this.walkTogetherSuppressed = true,
  });

  final PastoralThemeCategory theme;
  final bool suppressed;
  final int? distinctUsers;
  final int? previousDistinctUsers;
  final bool previousSuppressed;
  final int? seekingWisdomUsers;
  final bool seekingWisdomSuppressed;
  final int? walkTogetherUsers;
  final bool walkTogetherSuppressed;
}

class QuestionThemeAggregation {
  const QuestionThemeAggregation({
    required this.threshold,
    required this.insufficientVolume,
    required this.rolledUpFromGroup,
    required this.rolledUpToAllThemes,
    required this.cells,
    this.allThemesDistinctUsers,
    this.allThemesSuppressed = true,
    this.seekingWisdomDistinctUsers,
    this.seekingWisdomSuppressed = true,
    this.walkTogetherDistinctUsers,
    this.walkTogetherSuppressed = true,
    this.poolDistinctUsers = 0,
  });

  final int threshold;
  final bool insufficientVolume;
  final bool rolledUpFromGroup;
  final bool rolledUpToAllThemes;
  final List<QuestionThemeCell> cells;
  final int? allThemesDistinctUsers;
  final bool allThemesSuppressed;
  final int? seekingWisdomDistinctUsers;
  final bool seekingWisdomSuppressed;
  final int? walkTogetherDistinctUsers;
  final bool walkTogetherSuppressed;
  final int poolDistinctUsers;

  static const String insufficientLabel = 'Insufficient volume';
}

/// k-anonymity aggregation: cells need [threshold] distinct [userHash] values.
class QuestionThemeAggregator {
  QuestionThemeAggregator({this.threshold = 8});

  final int threshold;

  QuestionThemeAggregation aggregate({
    required List<QuestionThemeEvent> events,
    required DateTime now,
    int? periodDays,
    String? organizationId,
    String? groupId,
    QuestionThemeSource? source,
  }) {
    final scoped = events.where((event) {
      if (source != null && event.source != source) return false;
      return true;
    }).toList();

    final currentStart = periodDays == null
        ? null
        : now.subtract(Duration(days: periodDays));
    final previousStart = periodDays == null || currentStart == null
        ? null
        : currentStart.subtract(Duration(days: periodDays));

    var filterGroupId = groupId;
    var rolledUpFromGroup = false;

    if (filterGroupId != null && filterGroupId.isNotEmpty) {
      final groupPool = _inWindow(
        scoped.where((e) => e.groupId == filterGroupId).toList(),
        currentStart,
        now,
      );
      if (_distinct(groupPool).length < threshold) {
        filterGroupId = null;
        rolledUpFromGroup = true;
      }
    }

    var working = scoped;
    if (organizationId != null && organizationId.isNotEmpty) {
      working = working
          .where((e) => e.organizationId == organizationId)
          .toList();
    }
    if (filterGroupId != null && filterGroupId.isNotEmpty) {
      working = working.where((e) => e.groupId == filterGroupId).toList();
    }

    final current = _inWindow(working, currentStart, now);
    final previous = previousStart == null || currentStart == null
        ? const <QuestionThemeEvent>[]
        : working
            .where(
              (e) =>
                  !e.recordedAt.isBefore(previousStart) &&
                  e.recordedAt.isBefore(currentStart),
            )
            .toList();

    final cells = <QuestionThemeCell>[];
    for (final theme in PastoralThemeCategory.values) {
      final curTheme = current.where((e) => e.theme == theme).toList();
      final prevTheme = previous.where((e) => e.theme == theme).toList();
      final curCount = _distinct(curTheme).length;
      final prevCount = _distinct(prevTheme).length;
      final sgw = _distinct(
        curTheme.where((e) => e.source == QuestionThemeSource.seekingGodsWisdom),
      ).length;
      final walk = _distinct(
        curTheme.where((e) => e.source == QuestionThemeSource.walkTogether),
      ).length;

      cells.add(
        QuestionThemeCell(
          theme: theme,
          suppressed: curCount < threshold,
          distinctUsers: curCount < threshold ? null : curCount,
          previousDistinctUsers: prevCount < threshold ? null : prevCount,
          previousSuppressed: prevCount < threshold,
          seekingWisdomUsers: sgw < threshold ? null : sgw,
          seekingWisdomSuppressed: sgw < threshold,
          walkTogetherUsers: walk < threshold ? null : walk,
          walkTogetherSuppressed: walk < threshold,
        ),
      );
    }

    final visible = cells.where((c) => !c.suppressed).toList();
    final allCurrent = _distinct(current).length;
    final sgwAll = _distinct(
      current.where((e) => e.source == QuestionThemeSource.seekingGodsWisdom),
    ).length;
    final walkAll = _distinct(
      current.where((e) => e.source == QuestionThemeSource.walkTogether),
    ).length;

    final rolledUpToAllThemes = visible.isEmpty && allCurrent >= threshold;

    return QuestionThemeAggregation(
      threshold: threshold,
      insufficientVolume: visible.isEmpty && allCurrent < threshold,
      rolledUpFromGroup: rolledUpFromGroup,
      rolledUpToAllThemes: rolledUpToAllThemes,
      cells: rolledUpToAllThemes ? const [] : cells,
      allThemesDistinctUsers: allCurrent < threshold ? null : allCurrent,
      allThemesSuppressed: allCurrent < threshold,
      seekingWisdomDistinctUsers: sgwAll < threshold ? null : sgwAll,
      seekingWisdomSuppressed: sgwAll < threshold,
      walkTogetherDistinctUsers: walkAll < threshold ? null : walkAll,
      walkTogetherSuppressed: walkAll < threshold,
      poolDistinctUsers: allCurrent,
    );
  }

  List<QuestionThemeEvent> _inWindow(
    List<QuestionThemeEvent> events,
    DateTime? start,
    DateTime now,
  ) {
    return events.where((e) {
      if (e.recordedAt.isAfter(now)) return false;
      if (start != null && e.recordedAt.isBefore(start)) return false;
      return true;
    }).toList();
  }

  Set<String> _distinct(Iterable<QuestionThemeEvent> events) {
    return events.map((e) => e.userHash).where((h) => h.isNotEmpty).toSet();
  }
}
