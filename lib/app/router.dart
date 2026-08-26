import 'package:go_router/go_router.dart';

import '../features/ai_plan_builder/domain/generated_plan.dart';
import '../features/ai_plan_builder/presentation/ai_plan_builder_screen.dart';
import '../features/ai_plan_builder/presentation/plan_preview_screen.dart';
import '../features/cardio/presentation/cardio_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/exercises/presentation/exercise_detail_screen.dart';
import '../features/exercises/presentation/exercise_library_screen.dart';
import '../features/sessions/presentation/active_session_screen.dart';
import '../features/sessions/presentation/session_history_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/template_catalog/presentation/template_catalog_screen.dart';
import '../features/template_catalog/presentation/template_detail_screen.dart';
import '../features/weigh_in/presentation/weigh_in_screen.dart';
import '../features/workouts/presentation/workout_edit_screen.dart';
import '../features/workouts/presentation/workout_library_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(
      path: '/workouts',
      builder: (context, state) => const WorkoutLibraryScreen(),
    ),
    GoRoute(
      path: '/workouts/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return WorkoutEditScreen(workoutId: id);
      },
    ),
    GoRoute(
      path: '/sessions/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ActiveSessionScreen(sessionId: id);
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const SessionHistoryScreen(),
    ),
    GoRoute(path: '/cardio', builder: (context, state) => const CardioScreen()),
    GoRoute(
      path: '/weigh-in',
      builder: (context, state) => const WeighInScreen(),
    ),
    GoRoute(
      path: '/exercises',
      builder: (context, state) => const ExerciseLibraryScreen(),
    ),
    GoRoute(
      path: '/exercises/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ExerciseDetailScreen(exerciseId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/templates',
      builder: (context, state) => const TemplateCatalogScreen(),
    ),
    GoRoute(
      path: '/templates/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        return TemplateDetailScreen(slug: slug);
      },
    ),
    GoRoute(
      path: '/plan-builder',
      builder: (context, state) => const AiPlanBuilderScreen(),
    ),
    GoRoute(
      path: '/plan-builder/preview',
      builder: (context, state) {
        final workouts = state.extra! as List<GeneratedPlanWorkout>;
        return PlanPreviewScreen(workouts: workouts);
      },
    ),
  ],
);
