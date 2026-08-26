import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// One exercise entry within a catalog workout day. Exercises are addressed
/// by [exerciseSlug] (see the app's M10 migration) — never a local id, since
/// the catalog is shared across every install.
class CatalogWorkoutExercise {
  const CatalogWorkoutExercise({
    required this.exerciseSlug,
    required this.orderIndex,
    required this.targetSets,
    this.targetReps,
    this.targetRestSeconds,
    this.notes,
  });

  final String exerciseSlug;
  final int orderIndex;
  final int targetSets;
  final int? targetReps;
  final int? targetRestSeconds;
  final String? notes;

  factory CatalogWorkoutExercise.fromJson(Map<String, dynamic> json) {
    return CatalogWorkoutExercise(
      exerciseSlug: json['exercise_slug'] as String,
      orderIndex: json['order_index'] as int,
      targetSets: json['target_sets'] as int,
      targetReps: json['target_reps'] as int?,
      targetRestSeconds: json['target_rest_seconds'] as int?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'exercise_slug': exerciseSlug,
    'order_index': orderIndex,
    'target_sets': targetSets,
    'target_reps': targetReps,
    'target_rest_seconds': targetRestSeconds,
    'notes': notes,
  };
}

/// One day of a catalog template (e.g. "Push" in a Push/Pull/Legs program).
class CatalogWorkout {
  const CatalogWorkout({
    required this.name,
    required this.dayIndex,
    required this.exercises,
  });

  final String name;
  final int dayIndex;
  final List<CatalogWorkoutExercise> exercises;

  factory CatalogWorkout.fromJson(Map<String, dynamic> json) {
    return CatalogWorkout(
      name: json['name'] as String,
      dayIndex: json['day_index'] as int,
      exercises: (json['exercises'] as List)
          .map(
            (e) => CatalogWorkoutExercise.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'day_index': dayIndex,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}

/// Parses the `workouts` array cached in `CatalogTemplates.payloadJson`.
List<CatalogWorkout> parseCatalogWorkouts(String payloadJson) {
  final decoded = jsonDecode(payloadJson) as Map<String, dynamic>;
  return (decoded['workouts'] as List)
      .map((w) => CatalogWorkout.fromJson(w as Map<String, dynamic>))
      .toList();
}

/// Builds the `payloadJson` string to cache locally for a template's days.
String encodeCatalogWorkouts(List<CatalogWorkout> workouts) {
  return jsonEncode({'workouts': workouts.map((w) => w.toJson()).toList()});
}

/// Parses one `template_programs` row (with its embedded
/// `template_program_workouts`/`template_program_workout_exercises`) from
/// Supabase's PostgREST resource-embedding response shape into a DB
/// companion ready for `CatalogTemplatesDao.replaceAll`.
CatalogTemplatesCompanion parseSupabaseTemplateProgram(
  Map<String, dynamic> json,
) {
  final workoutsJson = (json['template_program_workouts'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final workouts = workoutsJson
      .map(
        (w) => CatalogWorkout(
          name: w['name'] as String,
          dayIndex: w['day_index'] as int,
          exercises: (w['template_program_workout_exercises'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map(CatalogWorkoutExercise.fromJson)
              .toList(),
        ),
      )
      .toList();

  return CatalogTemplatesCompanion.insert(
    slug: json['slug'] as String,
    name: json['name'] as String,
    description: Value(json['description'] as String?),
    goal: Value(json['goal'] as String?),
    difficulty: Value(json['difficulty'] as String?),
    payloadJson: encodeCatalogWorkouts(workouts),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

/// Parses the full `GET .../template_programs?select=*,...` response body
/// (a JSON array of programs) into companions ready for `replaceAll`.
List<CatalogTemplatesCompanion> parseSupabaseTemplatesResponse(
  List<dynamic> json,
) {
  return json
      .cast<Map<String, dynamic>>()
      .map(parseSupabaseTemplateProgram)
      .toList();
}
