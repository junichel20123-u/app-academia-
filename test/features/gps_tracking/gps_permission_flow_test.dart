import 'package:app_academia/features/gps_tracking/application/gps_permission_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('location service off takes priority over permission state', () {
    expect(
      evaluatePermissionState(
        locationServiceEnabled: false,
        permission: LocationPermission.always,
      ),
      GpsPermissionOutcome.locationServiceOff,
    );
  });

  test('denied permission is retryable', () {
    expect(
      evaluatePermissionState(
        locationServiceEnabled: true,
        permission: LocationPermission.denied,
      ),
      GpsPermissionOutcome.locationDenied,
    );
  });

  test('permanently denied permission needs system Settings', () {
    expect(
      evaluatePermissionState(
        locationServiceEnabled: true,
        permission: LocationPermission.deniedForever,
      ),
      GpsPermissionOutcome.locationPermanentlyDenied,
    );
  });

  test('while-in-use permission is enough to be ready', () {
    expect(
      evaluatePermissionState(
        locationServiceEnabled: true,
        permission: LocationPermission.whileInUse,
      ),
      GpsPermissionOutcome.ready,
    );
  });

  test('always permission is ready too', () {
    expect(
      evaluatePermissionState(
        locationServiceEnabled: true,
        permission: LocationPermission.always,
      ),
      GpsPermissionOutcome.ready,
    );
  });
}
