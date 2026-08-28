import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // Required once at startup for the main isolate to receive data relayed
  // from the GPS-tracking foreground service's own isolate (see
  // features/gps_tracking/application/gps_task_handler.dart).
  FlutterForegroundTask.initCommunicationPort();
  runApp(const ProviderScope(child: App()));
}
