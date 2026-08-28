import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/ai_plan_builder/domain/generated_plan.dart';
import '../features/ai_plan_builder/presentation/ai_plan_builder_screen.dart';
import '../features/ai_plan_builder/presentation/plan_preview_screen.dart';
import '../features/cardio/presentation/cardio_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/exercises/presentation/exercise_detail_screen.dart';
import '../features/exercises/presentation/exercise_library_screen.dart';
import '../features/gps_tracking/presentation/gps_run_screen.dart';
import '../features/sessions/presentation/active_session_screen.dart';
import '../features/sessions/presentation/session_history_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/template_catalog/presentation/template_catalog_screen.dart';
import '../features/template_catalog/presentation/template_detail_screen.dart';
import '../features/weigh_in/presentation/weigh_in_screen.dart';
import '../features/workouts/presentation/workout_edit_screen.dart';
import '../features/workouts/presentation/workout_library_screen.dart';

/// Shared page transition for every route below: a quick fade + slight
/// scale-in, applied uniformly instead of go_router's platform default.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _page(state, const DashboardScreen()),
    ),
    GoRoute(
      path: '/workouts',
      pageBuilder: (context, state) =>
          _page(state, const WorkoutLibraryScreen()),
    ),
    GoRoute(
      path: '/workouts/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return _page(state, WorkoutEditScreen(workoutId: id));
      },
    ),
    GoRoute(
      path: '/sessions/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return _page(state, ActiveSessionScreen(sessionId: id));
      },
    ),
    GoRoute(
      path: '/history',
      pageBuilder: (context, state) =>
          _page(state, const SessionHistoryScreen()),
    ),
    GoRoute(
      path: '/cardio',
      pageBuilder: (context, state) => _page(state, const CardioScreen()),
    ),
    GoRoute(
      path: '/gps-run',
      pageBuilder: (context, state) => _page(state, const GpsRunScreen()),
    ),
    GoRoute(
      path: '/weigh-in',
      pageBuilder: (context, state) => _page(state, const WeighInScreen()),
    ),
    GoRoute(
      path: '/exercises',
      pageBuilder: (context, state) =>
          _page(state, const ExerciseLibraryScreen()),
    ),
    GoRoute(
      path: '/exercises/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return _page(state, ExerciseDetailScreen(exerciseId: id));
      },
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _page(state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/templates',
      pageBuilder: (context, state) =>
          _page(state, const TemplateCatalogScreen()),
    ),
    GoRoute(
      path: '/templates/:slug',
      pageBuilder: (context, state) {
        final slug = state.pathParameters['slug']!;
        return _page(state, TemplateDetailScreen(slug: slug));
      },
    ),
    GoRoute(
      path: '/plan-builder',
      pageBuilder: (context, state) =>
          _page(state, const AiPlanBuilderScreen()),
    ),
    GoRoute(
      path: '/plan-builder/preview',
      pageBuilder: (context, state) {
        final workouts = state.extra! as List<GeneratedPlanWorkout>;
        return _page(state, PlanPreviewScreen(workouts: workouts));
      },
    ),
  ],
);
