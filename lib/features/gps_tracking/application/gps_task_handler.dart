import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_fix_filter.dart';

/// Entry point for the foreground service's own isolate — must be a
/// top-level (or static) function, per `flutter_foreground_task`'s
/// requirements. Registered as the `callback` passed to
/// `FlutterForegroundTask.startService(...)` in `gps_tracking_controller.dart`.
@pragma('vm:entry-point')
void gpsTrackingStartCallback() {
  FlutterForegroundTask.setTaskHandler(GpsTrackingTaskHandler());
}

/// Runs entirely inside the foreground service's isolate — independent of
/// the main UI isolate, which Android can suspend once the app is
/// minimized. This is the only place in the app that ever holds a raw GPS
/// coordinate: it owns the `geolocator` position stream, filters noise via
/// [evaluateFix], and accumulates a running distance total in memory.
///
/// Nothing here is persisted directly. Every few seconds
/// ([onRepeatEvent]) the running total — a plain number of meters, never a
/// coordinate — is relayed to the main isolate via `sendDataToMain`, which
/// is what actually writes the database checkpoint (see
/// `GpsTrackingController._onTaskData`). Keeping every database write on
/// the main isolate's single Drift connection avoids the complexity (and
/// risk) of a second isolate opening its own connection to the same
/// SQLite file.
class GpsTrackingTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionSub;
  GpsFix? _lastAccepted;
  double _accumulatedDistanceMeters = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Meters the device must move before a new fix is even delivered —
        // a first, cheap noise filter before evaluateFix's own thresholds.
        distanceFilter: 5,
      ),
    ).listen(_onPosition);
  }

  void _onPosition(Position position) {
    final candidate = GpsFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp,
    );
    final added = evaluateFix(
      candidate: candidate,
      lastAccepted: _lastAccepted,
    );
    if (added == null) {
      // Rejected as noise — deliberately does NOT become the new
      // `_lastAccepted`, so a bad fix can't become the baseline the next
      // comparison is made against.
      return;
    }
    _accumulatedDistanceMeters += added;
    _lastAccepted = candidate;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.updateService(
      notificationTitle: 'Rastreando corrida/caminhada',
      notificationText:
          '${(_accumulatedDistanceMeters / 1000).toStringAsFixed(2)} km',
    );
    FlutterForegroundTask.sendDataToMain(_accumulatedDistanceMeters);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSub?.cancel();
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}
