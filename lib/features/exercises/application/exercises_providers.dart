import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/exercises_repository.dart';

final exercisesRepositoryProvider = Provider<ExercisesRepository>((ref) {
  return ExercisesRepository(ref.watch(appDatabaseProvider));
});

final exercisesListProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(exercisesRepositoryProvider).watchAllExercises();
});

/// Current search text typed into the exercise picker.
class ExerciseSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final exerciseSearchQueryProvider =
    NotifierProvider<ExerciseSearchQueryNotifier, String>(
      ExerciseSearchQueryNotifier.new,
    );

final filteredExercisesProvider = Provider<AsyncValue<List<Exercise>>>((ref) {
  final query = ref.watch(exerciseSearchQueryProvider).trim().toLowerCase();
  final exercises = ref.watch(exercisesListProvider);
  return exercises.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((e) => e.name.toLowerCase().contains(query)).toList();
  });
});
