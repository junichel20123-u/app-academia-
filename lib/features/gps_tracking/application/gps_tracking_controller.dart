import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../../cardio/application/cardio_providers.dart';
import 'gps_permission_flow.dart';
import 'gps_run_providers.dart';
import 'gps_task_handler.dart';

enum GpsTrackingPhase { idle, tracking }

/// Live tracking state exposed to `GpsRunScreen`. `distanceMeters`/`elapsed`
/// are the values actually shown while tracking — `elapsed` is ticked
/// locally every second from `startedAt` (never depends on the background
/// isolate surviving), `distanceMeters` is refreshed whenever the tracking
/// isolate relays a new total (see `GpsTrackingController._onTaskData`).
class GpsTrackingSnapshot {
  const GpsTrackingSnapshot({
    this.phase = GpsTrackingPhase.idle,
    this.runId,
    this.activityType,
    this.startedAt,
    this.distanceMeters = 0,
    this.elapsed = Duration.zero,
  });

  final GpsTrackingPhase phase;
  final int? runId;
  final CardioActivityType? activityType;
  final DateTime? startedAt;
  final double distanceMeters;
  final Duration elapsed;

  GpsTrackingSnapshot copyWith({double? distanceMeters, Duration? elapsed}) {
    return GpsTrackingSnapshot(
      phase: phase,
      runId: runId,
      activityType: activityType,
      startedAt: startedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

/// Owns the foreground-service lifecycle, the elapsed-time ticker, and the
/// checkpoint writes triggered by data relayed from
/// [GpsTrackingTaskHandler]. Never touches a coordinate — only ever reads
/// (from the isolate relay) and writes (to the DB) a plain distance number.
class GpsTrackingController extends Notifier<GpsTrackingSnapshot> {
  Timer? _elapsedTicker;
  void Function(Object)? _taskDataCallback;

  @override
  GpsTrackingSnapshot build() {
    ref.onDispose(() {
      _elapsedTicker?.cancel();
      final callback = _taskDataCallback;
      if (callback != null) {
        FlutterForegroundTask.removeTaskDataCallback(callback);
      }
    });
    return const GpsTrackingSnapshot();
  }

  /// Runs the staged permission flow for "Iniciar": foreground location is
  /// mandatory (its outcome is returned so the screen can react); "always"
  /// location and notification permission are requested too, but a denial
  /// doesn't block starting — it only means tracking runs in a degraded,
  /// foreground-only mode, surfaced by the screen as a banner.
  Future<GpsPermissionOutcome> ensurePermissions({
    GpsPermissionFlow flow = const GpsPermissionFlow(),
  }) async {
    final serviceEnabled = await flow.isLocationServiceEnabled();
    final permission = await flow.requestForegroundLocation();
    final outcome = evaluatePermissionState(
      locationServiceEnabled: serviceEnabled,
      permission: permission,
    );
    if (outcome != GpsPermissionOutcome.ready) return outcome;

    await flow.requestBackgroundLocation();
    await flow.requestNotificationPermission();
    return outcome;
  }

  Future<void> start({required CardioActivityType activityType}) async {
    final runId = await ref
        .read(gpsRunRepositoryProvider)
        .startRun(activityType: activityType);
    await _beginService(
      runId: runId,
      activityType: activityType,
      startedAt: DateTime.now(),
      initialDistanceMeters: 0,
    );
  }

  /// Reattaches to an in-progress run found in the database after the app
  /// was relaunched. The native foreground service may or may not have
  /// survived the restart; either way this (re)starts location updates and
  /// resumes the distance total from the last checkpoint — the gap since
  /// then (at most one checkpoint interval) is an accepted, documented
  /// limitation rather than something recoverable without ever storing a
  /// coordinate.
  Future<void> resume(GpsRunSession run) async {
    await _beginService(
      runId: run.id,
      activityType: run.activityType,
      startedAt: run.startedAt,
      initialDistanceMeters: run.accumulatedDistanceMeters,
    );
  }

  Future<void> _beginService({
    required int runId,
    required CardioActivityType activityType,
    required DateTime startedAt,
    required double initialDistanceMeters,
  }) async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gps_run_tracking_channel',
        channelName: 'Rastreamento de corrida/caminhada',
        channelDescription:
            'Mostrado enquanto o app rastreia uma corrida ou caminhada, '
            'mesmo com o app em segundo plano.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        serviceId: 385,
        notificationTitle: 'Rastreando corrida/caminhada',
        notificationText:
            '${(initialDistanceMeters / 1000).toStringAsFixed(2)} km',
        callback: gpsTrackingStartCallback,
      );
    }

    final callback = _taskDataCallback;
    if (callback != null) {
      FlutterForegroundTask.removeTaskDataCallback(callback);
    }
    _taskDataCallback = _onTaskData;
    FlutterForegroundTask.addTaskDataCallback(_taskDataCallback!);

    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsed: DateTime.now().difference(startedAt));
    });

    state = GpsTrackingSnapshot(
      phase: GpsTrackingPhase.tracking,
      runId: runId,
      activityType: activityType,
      startedAt: startedAt,
      distanceMeters: initialDistanceMeters,
      elapsed: DateTime.now().difference(startedAt),
    );
  }

  void _onTaskData(Object data) {
    if (data is! double) return;
    state = state.copyWith(distanceMeters: data);
    final runId = state.runId;
    if (runId != null) {
      ref
          .read(gpsRunRepositoryProvider)
          .checkpoint(runId: runId, accumulatedDistanceMeters: data);
    }
  }

  Future<void> _teardownService() async {
    await FlutterForegroundTask.stopService();
    final callback = _taskDataCallback;
    if (callback != null) {
      FlutterForegroundTask.removeTaskDataCallback(callback);
      _taskDataCallback = null;
    }
    _elapsedTicker?.cancel();
    _elapsedTicker = null;
  }

  /// Stops tracking and saves the run to cardio history via the exact same
  /// `CardioRepository.createEntry(...)` the manual form uses — the saved
  /// entry is indistinguishable from one typed in by hand. Both writes run
  /// in one transaction so the run row and the cardio entry can't
  /// desynchronize if something fails mid-way.
  Future<void> stop() async {
    final runId = state.runId;
    final activityType = state.activityType;
    final startedAt = state.startedAt;
    if (runId == null || activityType == null || startedAt == null) return;

    final distanceMeters = state.distanceMeters;
    final durationSeconds = DateTime.now().difference(startedAt).inSeconds;

    await _teardownService();

    await ref.read(appDatabaseProvider).transaction(() async {
      await ref
          .read(cardioRepositoryProvider)
          .createEntry(
            activityType: activityType,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            occurredAt: startedAt,
          );
      await ref
          .read(gpsRunRepositoryProvider)
          .completeRun(runId: runId, accumulatedDistanceMeters: distanceMeters);
    });

    state = const GpsTrackingSnapshot();
  }

  /// Stops tracking without saving anything to cardio history.
  Future<void> discard() async {
    final runId = state.runId;
    await _teardownService();
    if (runId != null) {
      await ref.read(gpsRunRepositoryProvider).abandonRun(runId);
    }
    state = const GpsTrackingSnapshot();
  }
}

final gpsTrackingControllerProvider =
    NotifierProvider<GpsTrackingController, GpsTrackingSnapshot>(
      GpsTrackingController.new,
    );
