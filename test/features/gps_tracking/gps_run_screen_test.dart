import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:app_academia/features/cardio/application/cardio_providers.dart';
import 'package:app_academia/features/gps_tracking/application/gps_permission_flow.dart';
import 'package:app_academia/features/gps_tracking/application/gps_run_providers.dart';
import 'package:app_academia/features/gps_tracking/application/gps_tracking_controller.dart';
import 'package:app_academia/features/gps_tracking/presentation/gps_run_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A GPS run/walk involves real OS platform channels (geolocator,
/// permission_handler, flutter_foreground_task) that don't exist in the
/// `flutter_test` environment — the same reason this feature's live
/// behavior can only be verified on a real device (see the M26 plan).
/// This fake replaces only the platform-touching entry points
/// (`ensurePermissions`/`start`/`stop`/`discard`) with in-memory logic that
/// still exercises the real save-to-cardio transaction, so the test covers
/// everything that *is* deterministic: the screen's UI states and the
/// data flow from "stop and save" into cardio history.
class FakeGpsTrackingController extends GpsTrackingController {
  static const fakeDistanceMeters = 3200.0;
  static const fakeElapsed = Duration(minutes: 18);

  @override
  Future<GpsPermissionOutcome> ensurePermissions({
    GpsPermissionFlow flow = const GpsPermissionFlow(),
  }) async => GpsPermissionOutcome.ready;

  @override
  Future<void> start({required CardioActivityType activityType}) async {
    final runId = await ref
        .read(gpsRunRepositoryProvider)
        .startRun(activityType: activityType);
    state = GpsTrackingSnapshot(
      phase: GpsTrackingPhase.tracking,
      runId: runId,
      activityType: activityType,
      startedAt: DateTime.now().subtract(fakeElapsed),
      distanceMeters: fakeDistanceMeters,
      elapsed: fakeElapsed,
    );
  }

  @override
  Future<void> stop() async {
    final runId = state.runId;
    final activityType = state.activityType;
    final startedAt = state.startedAt;
    if (runId == null || activityType == null || startedAt == null) return;
    final distanceMeters = state.distanceMeters;

    await ref
        .read(cardioRepositoryProvider)
        .createEntry(
          activityType: activityType,
          durationSeconds: fakeElapsed.inSeconds,
          distanceMeters: distanceMeters,
          occurredAt: startedAt,
        );
    await ref
        .read(gpsRunRepositoryProvider)
        .completeRun(runId: runId, accumulatedDistanceMeters: distanceMeters);

    state = const GpsTrackingSnapshot();
  }

  @override
  Future<void> discard() async {
    final runId = state.runId;
    if (runId != null) {
      await ref.read(gpsRunRepositoryProvider).abandonRun(runId);
    }
    state = const GpsTrackingSnapshot();
  }
}

/// `GpsRunScreen._start()` checks `GpsPermissionFlow.isLocationServiceEnabled()`
/// directly, before ever reaching the (already-faked) controller — this
/// stands in for it so the test never touches the real `geolocator`
/// platform channel, which doesn't exist in `flutter_test` and would hang
/// the call indefinitely instead of throwing.
class FakeGpsPermissionFlow extends GpsPermissionFlow {
  const FakeGpsPermissionFlow();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> isBackgroundLocationGranted() async => true;
}

void main() {
  Future<AppDatabase> pumpScreen(WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          gpsTrackingControllerProvider.overrideWith(
            FakeGpsTrackingController.new,
          ),
          gpsPermissionFlowProvider.overrideWithValue(
            const FakeGpsPermissionFlow(),
          ),
        ],
        child: const MaterialApp(home: GpsRunScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('idle state shows the activity selector and Iniciar button', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Corrida'), findsOneWidget);
    expect(find.text('Caminhada'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('start, stop and save records a cardio entry', (tester) async {
    final db = await pumpScreen(tester);

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('Parar'), findsOneWidget);
    expect(find.text('3.20 km'), findsOneWidget);

    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));

    // `runAsync` (real time, not flutter_test's fake clock) — a bare await
    // here can hang: the just-canceled `activeGpsRunProvider` subscription
    // (on the table this write also touches) leaves a pending Drift
    // stream-notification timer that only real time advances. The run's
    // own completed/status bookkeeping is covered without this wrinkle by
    // gps_run_sessions_dao_test.dart.
    final entries = await tester.runAsync(
      () => db.cardioDao.watchAllEntries().first,
    );
    expect(entries, hasLength(1));
    expect(entries!.single.activityType, CardioActivityType.run);
    expect(
      entries.single.distanceMeters,
      FakeGpsTrackingController.fakeDistanceMeters,
    );
    expect(
      entries.single.durationSeconds,
      FakeGpsTrackingController.fakeElapsed.inSeconds,
    );
  });

  testWidgets('start then discard does not record a cardio entry', (
    tester,
  ) async {
    final db = await pumpScreen(tester);

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    // Confirmation dialog.
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));

    final entries = await tester.runAsync(
      () => db.cardioDao.watchAllEntries().first,
    );
    expect(entries, isEmpty);
  });
}
