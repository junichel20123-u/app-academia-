import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// What the "Iniciar" flow should show next, derived from the device's
/// current location-service/permission state. A pure function (no platform
/// call) so the branching itself is unit-testable even though the real OS
/// checks/dialogs aren't.
enum GpsPermissionOutcome {
  /// Location service is on and foreground permission is granted — tracking
  /// can start. Background ("always") permission is handled as a separate,
  /// non-blocking step (see [GpsPermissionFlow.requestBackgroundLocation]).
  ready,

  /// The device's location service (GPS) itself is switched off.
  locationServiceOff,

  /// Foreground location permission was denied, but can be asked again.
  locationDenied,

  /// Foreground location permission was denied permanently — only the
  /// system Settings screen can change it now.
  locationPermanentlyDenied,
}

GpsPermissionOutcome evaluatePermissionState({
  required bool locationServiceEnabled,
  required LocationPermission permission,
}) {
  if (!locationServiceEnabled) return GpsPermissionOutcome.locationServiceOff;
  switch (permission) {
    case LocationPermission.deniedForever:
      return GpsPermissionOutcome.locationPermanentlyDenied;
    case LocationPermission.denied:
      return GpsPermissionOutcome.locationDenied;
    case LocationPermission.whileInUse:
    case LocationPermission.always:
    case LocationPermission.unableToDetermine:
      return GpsPermissionOutcome.ready;
  }
}

/// Thin wrapper around the actual OS calls (`geolocator`/`permission_handler`)
/// — kept separate from [evaluatePermissionState] so the decision logic
/// stays testable without a platform channel.
class GpsPermissionFlow {
  const GpsPermissionFlow();

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Requests foreground ("while in use") location access — the minimum
  /// needed to unlock Start. Only prompts if not already decided.
  Future<LocationPermission> requestForegroundLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Requests "Allow all the time" (background) location — a separate,
  /// non-blocking step per Android's staged-permission guidance. On
  /// Android 11+ this routes the user to system Settings; there is no
  /// reliable in-app callback for what they choose there, so the caller
  /// should re-check `status` after the user returns (e.g. on the next
  /// `AppLifecycleState.resumed`) rather than trust this call's return
  /// value alone.
  Future<PermissionStatus> requestBackgroundLocation() =>
      Permission.locationAlways.request();

  Future<bool> isBackgroundLocationGranted() =>
      Permission.locationAlways.isGranted;

  /// Android 13+ requires this to be granted for the foreground-service
  /// notification to actually show. Non-blocking if denied — tracking
  /// still works, just with a less visible notification.
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Opens the app's system Settings screen — the only way to change a
  /// permanently-denied permission on Android.
  Future<bool> openSystemAppSettings() => openAppSettings();
}
