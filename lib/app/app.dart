import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/user_settings_providers.dart';
import '../features/video_generation/application/exercise_video_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: deletes any cached video file left orphaned by a
    // crash between it being written to disk and its DB row being updated
    // with the path — see ExerciseVideosRepository.sweepOrphanFiles. Never
    // blocks the first frame; errors here shouldn't prevent the app from
    // starting.
    unawaited(ref.read(exerciseVideosRepositoryProvider).sweepOrphanFiles());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App Academia',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: appRouter,
    );
  }
}
