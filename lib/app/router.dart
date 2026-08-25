import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/placeholder_home_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PlaceholderHomeScreen(),
    ),
  ],
);
