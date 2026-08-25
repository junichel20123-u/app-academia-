import 'package:go_router/go_router.dart';

import '../features/cardio/presentation/cardio_screen.dart';
import '../features/dashboard/presentation/placeholder_home_screen.dart';
import '../features/sessions/presentation/active_session_screen.dart';
import '../features/sessions/presentation/session_history_screen.dart';
import '../features/weigh_in/presentation/weigh_in_screen.dart';
import '../features/workouts/presentation/workout_edit_screen.dart';
import '../features/workouts/presentation/workout_library_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PlaceholderHomeScreen(),
    ),
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
  ],
);
