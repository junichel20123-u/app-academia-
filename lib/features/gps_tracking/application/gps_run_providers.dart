import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/gps_run_repository.dart';
import 'gps_permission_flow.dart';

final gpsRunRepositoryProvider = Provider<GpsRunRepository>((ref) {
  return GpsRunRepository(ref.watch(appDatabaseProvider));
});

/// Overridden in widget tests with a fake that never touches a real
/// platform channel (see `gps_run_screen_test.dart`).
final gpsPermissionFlowProvider = Provider<GpsPermissionFlow>((ref) {
  return const GpsPermissionFlow();
});

/// Most recent in-progress GPS run, if any — used by `GpsRunScreen` to
/// offer resuming after the app was relaunched, mirroring
/// `activeSessionProvider` for strength-training sessions.
final activeGpsRunProvider = StreamProvider<GpsRunSession?>((ref) {
  return ref.watch(gpsRunRepositoryProvider).watchActiveRun();
});
