import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';

class ExercisesRepository {
  ExercisesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Exercise>> watchAllExercises() =>
      _db.exercisesDao.watchAllExercises();

  Future<int> createCustomExercise({
    required String name,
    required MuscleGroup muscleGroup,
    Equipment? equipment,
  }) {
    return _db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(
        name: name,
        muscleGroup: muscleGroup,
        equipment: Value(equipment),
        isCustom: const Value(true),
      ),
    );
  }
}
