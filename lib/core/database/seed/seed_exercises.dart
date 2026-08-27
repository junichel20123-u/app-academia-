import 'package:drift/drift.dart';

import '../../utils/slugify.dart';
import '../app_database.dart';
import '../enums.dart';

/// Original starter library (schema v1). Kept as its own list so the v4
/// migration below can reference exactly what was added later without
/// redeclaring it.
final List<ExercisesCompanion> _v1Exercises = [
  _e('Supino reto com barra', MuscleGroup.chest, Equipment.barbell),
  _e('Supino inclinado com halteres', MuscleGroup.chest, Equipment.dumbbell),
  _e('Crucifixo no cabo', MuscleGroup.chest, Equipment.cable),
  _e('Flexão de braço', MuscleGroup.chest, Equipment.bodyweight),
  // Real lat-pulldown machines are always cable/weight-stack based — this
  // was mislabeled `Equipment.machine` originally; corrected here for new
  // installs (`onCreate`), and via an `UPDATE` in the v5 migration for
  // existing ones (see `exercisesAddedInSchemaV5` and `app_database.dart`).
  _e('Puxada frontal', MuscleGroup.back, Equipment.cable),
  _e('Remada curvada com barra', MuscleGroup.back, Equipment.barbell),
  _e('Remada unilateral com halter', MuscleGroup.back, Equipment.dumbbell),
  _e('Barra fixa', MuscleGroup.back, Equipment.bodyweight),
  _e('Agachamento livre', MuscleGroup.legs, Equipment.barbell),
  _e('Leg press', MuscleGroup.legs, Equipment.machine),
  _e('Cadeira extensora', MuscleGroup.legs, Equipment.machine),
  _e('Cadeira flexora', MuscleGroup.legs, Equipment.machine),
  _e('Afundo com halteres', MuscleGroup.legs, Equipment.dumbbell),
  _e('Levantamento terra', MuscleGroup.legs, Equipment.barbell),
  _e('Desenvolvimento com halteres', MuscleGroup.shoulders, Equipment.dumbbell),
  _e('Elevação lateral', MuscleGroup.shoulders, Equipment.dumbbell),
  _e('Elevação frontal', MuscleGroup.shoulders, Equipment.dumbbell),
  _e(
    'Desenvolvimento militar com barra',
    MuscleGroup.shoulders,
    Equipment.barbell,
  ),
  _e('Rosca direta com barra', MuscleGroup.arms, Equipment.barbell),
  _e('Rosca alternada com halteres', MuscleGroup.arms, Equipment.dumbbell),
  _e('Tríceps corda no cabo', MuscleGroup.arms, Equipment.cable),
  _e('Tríceps testa com barra', MuscleGroup.arms, Equipment.barbell),
  _e('Prancha abdominal', MuscleGroup.core, Equipment.bodyweight),
  _e('Abdominal supra', MuscleGroup.core, Equipment.bodyweight),
  _e('Elevação de pernas', MuscleGroup.core, Equipment.bodyweight),
  _e('Burpee', MuscleGroup.fullBody, Equipment.bodyweight),
  _e('Kettlebell swing', MuscleGroup.fullBody, Equipment.kettlebell),
  _e('Corrida na esteira', MuscleGroup.cardio, Equipment.machine),
];

/// Added in schema v4 — fills the gap reported after testing: too few
/// machine-equipment options outside legs/back, and only one cardio entry.
/// Exported (not private) so the v4 `onUpgrade` migration in
/// `app_database.dart` can insert exactly this list into existing installs
/// without redeclaring it or re-inserting the v1 exercises.
final List<ExercisesCompanion> exercisesAddedInSchemaV4 = [
  _e('Supino máquina', MuscleGroup.chest, Equipment.machine),
  _e('Peck deck (voador máquina)', MuscleGroup.chest, Equipment.machine),
  _e('Remada máquina', MuscleGroup.back, Equipment.machine),
  _e('Puxada supinada na máquina', MuscleGroup.back, Equipment.machine),
  _e('Cadeira adutora', MuscleGroup.legs, Equipment.machine),
  _e('Cadeira abdutora', MuscleGroup.legs, Equipment.machine),
  _e('Panturrilha em pé na máquina', MuscleGroup.legs, Equipment.machine),
  _e('Agachamento hack na máquina', MuscleGroup.legs, Equipment.machine),
  _e('Desenvolvimento máquina', MuscleGroup.shoulders, Equipment.machine),
  _e('Tríceps máquina', MuscleGroup.arms, Equipment.machine),
  _e('Rosca scott na máquina', MuscleGroup.arms, Equipment.machine),
  _e('Abdominal máquina', MuscleGroup.core, Equipment.machine),
  _e('Bicicleta ergométrica', MuscleGroup.cardio, Equipment.machine),
  _e('Elíptico', MuscleGroup.cardio, Equipment.machine),
  _e('Remo ergométrico', MuscleGroup.cardio, Equipment.machine),
  _e('Pular corda', MuscleGroup.cardio, Equipment.other),
];

/// Added in schema v5 — fills the "polia" (cable/pulley) gap reported after
/// testing: only 2 cable exercises existed (both v1), and the most iconic
/// cable movement (lat pulldown) was mislabeled `Equipment.machine` — see
/// the `_v1Exercises` fix above. Exported for the same reason as
/// [exercisesAddedInSchemaV4].
final List<ExercisesCompanion> exercisesAddedInSchemaV5 = [
  _e('Remada baixa na polia', MuscleGroup.back, Equipment.cable),
  _e('Elevação lateral no cabo', MuscleGroup.shoulders, Equipment.cable),
  _e('Face pull na polia', MuscleGroup.shoulders, Equipment.cable),
  _e('Rosca na polia baixa', MuscleGroup.arms, Equipment.cable),
  _e('Tríceps francês na polia', MuscleGroup.arms, Equipment.cable),
  _e('Abdominal na polia alta', MuscleGroup.core, Equipment.cable),
  _e('Coice no cabo (glúteos)', MuscleGroup.legs, Equipment.cable),
];

/// Starter exercise library seeded into an empty database on first launch.
final List<ExercisesCompanion> seedExercises = [
  ..._v1Exercises,
  ...exercisesAddedInSchemaV4,
  ...exercisesAddedInSchemaV5,
];

ExercisesCompanion _e(
  String name,
  MuscleGroup muscleGroup,
  Equipment equipment,
) {
  return ExercisesCompanion.insert(
    name: name,
    slug: Value(slugify(name)),
    muscleGroup: muscleGroup,
    equipment: Value(equipment),
    isCustom: const Value(false),
  );
}
