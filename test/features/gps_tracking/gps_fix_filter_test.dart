import 'package:app_academia/features/gps_tracking/application/gps_fix_filter.dart';
import 'package:flutter_test/flutter_test.dart';

GpsFix _fix({
  required double lat,
  required double lng,
  double accuracy = 5,
  required DateTime at,
}) => GpsFix(
  latitude: lat,
  longitude: lng,
  accuracyMeters: accuracy,
  timestamp: at,
);

void main() {
  group('haversineDistanceMeters', () {
    test('is zero for the same point', () {
      final fix = _fix(lat: -23.5505, lng: -46.6333, at: DateTime(2026, 1, 1));
      expect(haversineDistanceMeters(fix, fix), 0);
    });

    test('matches a known distance (roughly 1 degree of latitude ~111km)', () {
      final a = _fix(lat: 0, lng: 0, at: DateTime(2026, 1, 1));
      final b = _fix(lat: 1, lng: 0, at: DateTime(2026, 1, 1));
      final distance = haversineDistanceMeters(a, b);
      expect(distance, closeTo(111195, 200));
    });
  });

  group('evaluateFix', () {
    final start = DateTime(2026, 1, 1, 8, 0, 0);

    test('first fix seeds the run and adds zero distance', () {
      final first = _fix(lat: -23.5505, lng: -46.6333, at: start);
      final added = evaluateFix(candidate: first, lastAccepted: null);
      expect(added, 0);
    });

    test('accepts a normal-pace movement between two fixes', () {
      final last = _fix(lat: -23.5505, lng: -46.6333, at: start);
      // ~11m north, 5 seconds later => ~2.2 m/s, a plausible jog pace.
      final next = _fix(
        lat: -23.5504,
        lng: -46.6333,
        at: start.add(const Duration(seconds: 5)),
      );
      final added = evaluateFix(candidate: next, lastAccepted: last);
      expect(added, isNotNull);
      expect(added, greaterThan(0));
    });

    test('rejects a fix with poor accuracy', () {
      final last = _fix(lat: -23.5505, lng: -46.6333, at: start);
      final next = _fix(
        lat: -23.5504,
        lng: -46.6333,
        accuracy: 45,
        at: start.add(const Duration(seconds: 5)),
      );
      final added = evaluateFix(candidate: next, lastAccepted: last);
      expect(added, isNull);
    });

    test('rejects an implausible speed jump (GPS teleport)', () {
      final last = _fix(lat: -23.5505, lng: -46.6333, at: start);
      // ~1km away but only 1 second later => ~1000 m/s, impossible.
      final next = _fix(
        lat: -23.5415,
        lng: -46.6333,
        at: start.add(const Duration(seconds: 1)),
      );
      final added = evaluateFix(candidate: next, lastAccepted: last);
      expect(added, isNull);
    });

    test('rejects sub-floor jitter while effectively stationary', () {
      final last = _fix(lat: -23.5505, lng: -46.6333, at: start);
      // ~1m of drift — below the default 3m movement floor.
      final next = _fix(
        lat: -23.550491,
        lng: -46.6333,
        at: start.add(const Duration(seconds: 5)),
      );
      final added = evaluateFix(candidate: next, lastAccepted: last);
      expect(added, isNull);
    });

    test('rejects a non-positive time delta (duplicate/out-of-order fix)', () {
      final last = _fix(lat: -23.5505, lng: -46.6333, at: start);
      final next = _fix(lat: -23.5504, lng: -46.6333, at: start);
      final added = evaluateFix(candidate: next, lastAccepted: last);
      expect(added, isNull);
    });
  });
}
