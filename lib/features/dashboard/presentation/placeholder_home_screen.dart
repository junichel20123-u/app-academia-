import 'package:flutter/material.dart';

/// Temporary home screen for M0 scaffolding.
/// Replaced by the real dashboard (streak card, quick-start) in M6.
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Academia')),
      body: const Center(
        child: Text('Scaffold pronto — próximos marcos adicionam as telas.'),
      ),
    );
  }
}
