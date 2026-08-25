import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:app_academia/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:app_academia/features/video_generation/application/exercise_video_providers.dart';
import 'package:app_academia/features/video_generation/data/exercise_videos_repository.dart';
import 'package:app_academia/features/video_generation/data/mock_video_generation_provider.dart';
import 'package:app_academia/features/video_generation/domain/exercise_video_state.dart'
    as state;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_file_storage_service.dart';

void main() {
  testWidgets('tapping Gerar vídeo drives the full pipeline through to Ready', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final exercise = (await db.exercisesDao.getAllExercises()).first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // Zero delays: `checkStatus` reports Ready on the very first
          // call, so the pipeline resolves through plain microtasks with
          // no Timer involved at all — avoids the mismatch between
          // `tester.pump(duration)`'s fake clock (which only advances
          // scheduled Timers) and `DateTime.now()` (real, unaffected by
          // it), which the mock provider's pending check depends on.
          exerciseVideosRepositoryProvider.overrideWithValue(
            ExerciseVideosRepository(
              db,
              MockVideoGenerationProvider(generationDelay: Duration.zero),
              fileStorage: FakeFileStorageService(),
              pollInterval: Duration.zero,
            ),
          ),
        ],
        child: MaterialApp(home: ExerciseDetailScreen(exerciseId: exercise.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gerar vídeo'), findsOneWidget);

    await tester.tap(find.text('Gerar vídeo'));
    await tester.pumpAndSettle();

    expect(find.text('Regenerar'), findsOneWidget);
    final row = await db.exercisesDao.getLatestVideoForExercise(exercise.id);
    expect(row!.status, ExerciseVideoStatus.ready);
    expect(row.localFilePath, isNotNull);

    // See workout_flow_test.dart for why this is needed: drift's stream-
    // cancellation debounce timer must fire before the framework's
    // pending-timer check runs at test teardown.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  // The Generating/Failed cases below override the state provider directly
  // rather than driving a real repository — they're only about how the UI
  // renders a given state, which the pipeline tests in
  // exercise_videos_repository_test.dart already cover independently.

  testWidgets('renders the Generating state', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final exercise = (await db.exercisesDao.getAllExercises()).first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          exerciseVideoStateProvider(exercise.id)
              .overrideWith((ref) => Stream.value(const state.Generating())),
        ],
        child: MaterialApp(home: ExerciseDetailScreen(exerciseId: exercise.id)),
      ),
    );
    // Not pumpAndSettle: the Generating state shows a perpetually-animating
    // spinner, which never settles. A couple of plain pumps is enough to
    // let exercisesListProvider's stream resolve.
    await tester.pump();
    await tester.pump();

    expect(find.text('Gerando vídeo...'), findsOneWidget);
    expect(find.text('Gerar vídeo'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('renders Failed with a Retry action', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final exercise = (await db.exercisesDao.getAllExercises()).first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          exerciseVideoStateProvider(exercise.id).overrideWith(
            (ref) => Stream.value(
              const state.Failed('Falha simulada (modo de teste).'),
            ),
          ),
        ],
        child: MaterialApp(home: ExerciseDetailScreen(exerciseId: exercise.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Falha simulada'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
