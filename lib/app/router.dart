import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/placeholder_home_screen.dart';
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
  ],
);
