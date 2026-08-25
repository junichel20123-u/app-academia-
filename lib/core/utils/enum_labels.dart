import '../database/enums.dart';

String muscleGroupLabel(MuscleGroup group) => switch (group) {
  MuscleGroup.chest => 'Peito',
  MuscleGroup.back => 'Costas',
  MuscleGroup.legs => 'Pernas',
  MuscleGroup.shoulders => 'Ombros',
  MuscleGroup.arms => 'Braços',
  MuscleGroup.core => 'Core',
  MuscleGroup.fullBody => 'Corpo todo',
  MuscleGroup.cardio => 'Cardio',
};

String equipmentLabel(Equipment equipment) => switch (equipment) {
  Equipment.barbell => 'Barra',
  Equipment.dumbbell => 'Halteres',
  Equipment.machine => 'Máquina',
  Equipment.bodyweight => 'Peso corporal',
  Equipment.cable => 'Cabo',
  Equipment.kettlebell => 'Kettlebell',
  Equipment.band => 'Elástico',
  Equipment.other => 'Outro',
};

String cardioActivityTypeLabel(CardioActivityType type) => switch (type) {
  CardioActivityType.run => 'Corrida',
  CardioActivityType.bike => 'Bicicleta',
  CardioActivityType.walk => 'Caminhada',
  CardioActivityType.swim => 'Natação',
  CardioActivityType.other => 'Outro',
};
