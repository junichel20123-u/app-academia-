import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Temporary home screen for early scaffolding milestones.
/// Replaced by the real dashboard (streak card, quick-start) in M6.
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Academia')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.push('/workouts'),
          child: const Text('Meus treinos'),
        ),
      ),
    );
  }
}
