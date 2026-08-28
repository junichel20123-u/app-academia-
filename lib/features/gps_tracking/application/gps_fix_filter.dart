import 'dart:math';

/// One GPS reading. Lives only in memory for as long as tracking is
/// active — never written to the database or anywhere else; only the
/// distance/duration these fixes accumulate into is ever persisted (see
/// `GpsRunSessions` in `core/database/tables/gps_run_sessions_table.dart`).
/// Plain Dart, no Flutter dependency, so it can run inside the foreground
/// task's background isolate as well as the main isolate.
class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
}

const double _earthRadiusMeters = 6371000;

/// Great-circle distance between two fixes, in meters (haversine formula).
double haversineDistanceMeters(GpsFix from, GpsFix to) {
  final lat1 = from.latitude * pi / 180;
  final lat2 = to.latitude * pi / 180;
  final dLat = (to.latitude - from.latitude) * pi / 180;
  final dLon = (to.longitude - from.longitude) * pi / 180;

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return _earthRadiusMeters * c;
}

/// Decides whether [candidate] represents real movement worth adding to a
/// run's total, given the last fix that was accepted (`null` if this is the
/// first fix of the run). Returns the meters to add, or `null` to reject
/// the candidate as noise.
///
/// Thresholds are heuristics from published smartphone-GPS-accuracy
/// figures, not calibrated against a real device — expect to tune after
/// the first live outdoor test:
/// - [maxAccuracyMeters] (default 20m): typical open-sky GPS accuracy is
///   3-8m, degrading to 20-50m under tree cover/urban canyon. 20m rejects
///   clearly-bad fixes (cold start, indoor leakage) without discarding
///   legitimate outdoor fixes under partial cover.
/// - [maxPlausibleSpeedMps] (default 12 m/s, ~43 km/h): generous enough for
///   a fast sprint interval, but rejects GPS "teleports" from multipath/
///   reflection, which routinely imply 30-100+ m/s.
/// - [minMovementMeters] (default 3m): a stationary phone's GPS reports a
///   few meters of jitter even standing still; without a floor, distance
///   would silently accumulate while stopped.
double? evaluateFix({
  required GpsFix candidate,
  required GpsFix? lastAccepted,
  double maxAccuracyMeters = 20,
  double maxPlausibleSpeedMps = 12,
  double minMovementMeters = 3,
}) {
  if (candidate.accuracyMeters > maxAccuracyMeters) return null;
  if (lastAccepted == null) return 0;

  final elapsedSeconds =
      candidate.timestamp.difference(lastAccepted.timestamp).inMilliseconds /
      1000;
  if (elapsedSeconds <= 0) return null;

  final distance = haversineDistanceMeters(lastAccepted, candidate);
  if (distance < minMovementMeters) return null;

  final impliedSpeedMps = distance / elapsedSeconds;
  if (impliedSpeedMps > maxPlausibleSpeedMps) return null;

  return distance;
}
