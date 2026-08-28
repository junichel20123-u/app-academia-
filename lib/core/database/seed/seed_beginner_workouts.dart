/// One exercise entry within a fixed beginner workout, resolved by the
/// exercise's stable slug (never a local id) — same convention as the
/// template catalog and AI-generated plans.
class BeginnerWorkoutExerciseSeed {
  const BeginnerWorkoutExerciseSeed(
    this.exerciseSlug, {
    required this.targetSets,
    this.targetReps,
    this.targetRestSeconds,
    this.notes,
  });

  final String exerciseSlug;
  final int targetSets;
  final int? targetReps;
  final int? targetRestSeconds;
  final String? notes;
}

class BeginnerWorkoutSeed {
  const BeginnerWorkoutSeed(this.name, this.exercises);

  final String name;
  final List<BeginnerWorkoutExerciseSeed> exercises;
}

/// The fixed, non-editable "Treinos iniciante" category (see
/// `app_database.dart`'s v9 migration): three basic, zero-equipment,
/// aerobic/fat-loss-oriented circuits for someone who opens the app with
/// no plan of their own and isn't ready for the AI plan builder yet. Short
/// rest (30s) keeps the heart rate up, matching a beginner fat-loss
/// circuit rather than a strength-training rest cadence.
final List<BeginnerWorkoutSeed> beginnerWorkoutSeeds = [
  BeginnerWorkoutSeed('Iniciante — Queima Total', [
    const BeginnerWorkoutExerciseSeed(
      'polichinelo',
      targetSets: 3,
      targetReps: 30,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'agachamento-com-peso-corporal',
      targetSets: 3,
      targetReps: 15,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'escalador',
      targetSets: 3,
      targetReps: 20,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'flexao-de-braco',
      targetSets: 3,
      targetReps: 10,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'abdominal-supra',
      targetSets: 3,
      targetReps: 15,
      targetRestSeconds: 30,
    ),
  ]),
  BeginnerWorkoutSeed('Iniciante — Intervalado Leve', [
    const BeginnerWorkoutExerciseSeed(
      'joelhos-altos',
      targetSets: 3,
      targetReps: 30,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'afundo-alternado',
      targetSets: 3,
      targetReps: 12,
      targetRestSeconds: 30,
      notes: 'Alternando o lado a cada repetição',
    ),
    const BeginnerWorkoutExerciseSeed(
      'burpee',
      targetSets: 3,
      targetReps: 8,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'elevacao-de-pernas',
      targetSets: 3,
      targetReps: 15,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'polichinelo',
      targetSets: 3,
      targetReps: 30,
      targetRestSeconds: 30,
    ),
  ]),
  BeginnerWorkoutSeed('Iniciante — Ativação Full Body', [
    const BeginnerWorkoutExerciseSeed(
      'agachamento-com-salto',
      targetSets: 3,
      targetReps: 12,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'escalador',
      targetSets: 3,
      targetReps: 20,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'afundo-alternado',
      targetSets: 3,
      targetReps: 12,
      targetRestSeconds: 30,
      notes: 'Alternando o lado a cada repetição',
    ),
    const BeginnerWorkoutExerciseSeed(
      'flexao-de-braco',
      targetSets: 3,
      targetReps: 10,
      targetRestSeconds: 30,
    ),
    const BeginnerWorkoutExerciseSeed(
      'joelhos-altos',
      targetSets: 3,
      targetReps: 30,
      targetRestSeconds: 30,
    ),
  ]),
];
