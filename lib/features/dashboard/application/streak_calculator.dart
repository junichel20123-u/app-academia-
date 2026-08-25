/// Distinct calendar dates (time truncated) from the given timestamps.
///
/// Timestamps are treated as already being in whatever timezone the caller
/// wants to bucket by — callers reading from the database should convert to
/// local time (`.toLocal()`) before calling this.
Set<DateTime> distinctDates(Iterable<DateTime> timestamps) {
  return timestamps.map((t) => DateTime(t.year, t.month, t.day)).toSet();
}

/// Counts consecutive calendar days, ending today or yesterday, with at
/// least one entry in [completedTimestamps].
///
/// Anchors on today if today already has an entry; otherwise anchors on
/// yesterday, so the streak isn't shown as broken before today ends.
/// Multiple entries on the same day count once. Returns 0 if neither today
/// nor yesterday has an entry.
int calculateStreak(
  Iterable<DateTime> completedTimestamps, {
  required DateTime now,
}) {
  final dates = distinctDates(completedTimestamps);
  final today = DateTime(now.year, now.month, now.day);
  var cursor = dates.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));

  if (!dates.contains(cursor)) return 0;

  var streak = 0;
  while (dates.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
