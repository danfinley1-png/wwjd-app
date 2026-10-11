const THEMES = [
  "prayer",
  "sacraments",
  "scripture",
  "relationships_chastity",
  "suffering_grief",
  "vocation",
  "moral_decision",
  "other",
];

const SOURCES = ["seeking_gods_wisdom", "walk_together"];
const THRESHOLD = 8;

function distinctHashes(events) {
  const set = new Set();
  for (const event of events) {
    if (event.userHash) set.add(event.userHash);
  }
  return set.size;
}

function inWindow(events, start, end) {
  return events.filter((event) => {
    const at = event.recordedAt;
    if (!(at instanceof Date) || Number.isNaN(at.getTime())) return false;
    if (at.getTime() > end.getTime()) return false;
    if (start && at.getTime() < start.getTime()) return false;
    return true;
  });
}

function cell(theme, current, previous) {
  const curCount = distinctHashes(current.filter((e) => e.theme === theme));
  const prevCount = distinctHashes(previous.filter((e) => e.theme === theme));
  const sgw = distinctHashes(
    current.filter(
      (e) => e.theme === theme && e.source === "seeking_gods_wisdom"
    )
  );
  const walk = distinctHashes(
    current.filter((e) => e.theme === theme && e.source === "walk_together")
  );
  return {
    theme,
    suppressed: curCount < THRESHOLD,
    distinctUsers: curCount < THRESHOLD ? null : curCount,
    previousDistinctUsers: prevCount < THRESHOLD ? null : prevCount,
    previousSuppressed: prevCount < THRESHOLD,
    seekingWisdomUsers: sgw < THRESHOLD ? null : sgw,
    seekingWisdomSuppressed: sgw < THRESHOLD,
    walkTogetherUsers: walk < THRESHOLD ? null : walk,
    walkTogetherSuppressed: walk < THRESHOLD,
  };
}

function aggregateQuestionThemes({
  events,
  now,
  periodDays,
  organizationId,
  groupId,
  source,
}) {
  let scoped = Array.isArray(events) ? events.slice() : [];
  if (source && SOURCES.includes(source)) {
    scoped = scoped.filter((e) => e.source === source);
  }

  const currentStart =
    periodDays == null ? null : new Date(now.getTime() - periodDays * 86400000);
  const previousStart =
    periodDays == null || !currentStart
      ? null
      : new Date(currentStart.getTime() - periodDays * 86400000);

  let filterGroupId = groupId || null;
  let rolledUpFromGroup = false;
  if (filterGroupId) {
    const groupPool = inWindow(
      scoped.filter((e) => e.groupId === filterGroupId),
      currentStart,
      now
    );
    if (distinctHashes(groupPool) < THRESHOLD) {
      filterGroupId = null;
      rolledUpFromGroup = true;
    }
  }

  let working = scoped;
  if (organizationId) {
    working = working.filter((e) => e.organizationId === organizationId);
  }
  if (filterGroupId) {
    working = working.filter((e) => e.groupId === filterGroupId);
  }

  const current = inWindow(working, currentStart, now);
  const previous =
    !previousStart || !currentStart
      ? []
      : working.filter((e) => {
          const at = e.recordedAt;
          if (!(at instanceof Date)) return false;
          return at >= previousStart && at < currentStart;
        });

  const cells = THEMES.map((theme) => cell(theme, current, previous));
  const visible = cells.filter((c) => !c.suppressed);
  const allCurrent = distinctHashes(current);
  const sgwAll = distinctHashes(
    current.filter((e) => e.source === "seeking_gods_wisdom")
  );
  const walkAll = distinctHashes(
    current.filter((e) => e.source === "walk_together")
  );
  const rolledUpToAllThemes = visible.length === 0 && allCurrent >= THRESHOLD;

  return {
    threshold: THRESHOLD,
    insufficientVolume: visible.length === 0 && allCurrent < THRESHOLD,
    rolledUpFromGroup,
    rolledUpToAllThemes,
    cells: rolledUpToAllThemes ? [] : cells,
    allThemesDistinctUsers: allCurrent < THRESHOLD ? null : allCurrent,
    allThemesSuppressed: allCurrent < THRESHOLD,
    seekingWisdomDistinctUsers: sgwAll < THRESHOLD ? null : sgwAll,
    seekingWisdomSuppressed: sgwAll < THRESHOLD,
    walkTogetherDistinctUsers: walkAll < THRESHOLD ? null : walkAll,
    walkTogetherSuppressed: walkAll < THRESHOLD,
    poolDistinctUsers: allCurrent,
  };
}

module.exports = {
  THEMES,
  SOURCES,
  THRESHOLD,
  aggregateQuestionThemes,
};
