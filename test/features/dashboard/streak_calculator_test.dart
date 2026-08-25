import 'package:app_academia/features/dashboard/application/streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 15, 20); // Monday, 8pm.
  DateTime daysAgo(int n) => now.subtract(Duration(days: n));

  test('returns 0 when there are no completed sessions', () {
    expect(calculateStreak([], now: now), 0);
  });

  test('returns 0 when the most recent session was 2+ days ago', () {
    expect(calculateStreak([daysAgo(2)], now: now), 0);
  });

  test('counts 1 when only today has a session', () {
    expect(calculateStreak([daysAgo(0)], now: now), 1);
  });

  test('anchors on yesterday when today has no session yet (not broken '
      'before the day ends)', () {
    expect(calculateStreak([daysAgo(1)], now: now), 1);
    expect(calculateStreak([daysAgo(1), daysAgo(2)], now: now), 2);
  });

  test('counts consecutive days ending today', () {
    expect(calculateStreak([daysAgo(0), daysAgo(1), daysAgo(2)], now: now), 3);
  });

  test('stops counting at the first gap', () {
    // Today, yesterday, then a gap before day 3.
    expect(calculateStreak([daysAgo(0), daysAgo(1), daysAgo(3)], now: now), 2);
  });

  test('multiple sessions on the same day count once', () {
    final today = daysAgo(0);
    expect(
      calculateStreak([
        today,
        today.add(const Duration(hours: 3)),
        today.add(const Duration(hours: 6)),
      ], now: now),
      1,
    );
  });

  test('distinctDates truncates time of day', () {
    final dates = distinctDates([
      DateTime(2026, 1, 1, 8),
      DateTime(2026, 1, 1, 20),
      DateTime(2026, 1, 2, 0, 1),
    ]);
    expect(dates, {DateTime(2026, 1, 1), DateTime(2026, 1, 2)});
  });
}
