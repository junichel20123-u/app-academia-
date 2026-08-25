import 'package:drift/drift.dart';

import '../app_database.dart';
import '../enums.dart';

/// Starter exercise library seeded into an empty database on first launch.
final List<ExercisesCompanion> seedExercises = [
  _e('Supino reto com barra', MuscleGroup.chest, Equipment.barbell),
  _e('Supino inclinado com halteres', MuscleGroup.chest, Equipment.dumbbell),
  _e('Crucifixo no cabo', MuscleGroup.chest, Equipment.cable),
  _e('Flexão de braço', MuscleGroup.chest, Equipment.bodyweight),
  _e('Puxada frontal', MuscleGroup.back, Equipment.machine),
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

ExercisesCompanion _e(
  String name,
  MuscleGroup muscleGroup,
  Equipment equipment,
) {
  return ExercisesCompanion.insert(
    name: name,
    muscleGroup: muscleGroup,
    equipment: Value(equipment),
    isCustom: const Value(false),
  );
}
