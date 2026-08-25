import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/video_generation/data/mock_video_generation_provider.dart';
import 'package:app_academia/features/video_generation/domain/video_generation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _testExercise() => Exercise(
  id: 1,
  name: 'Exercício de teste',
  muscleGroup: MuscleGroup.chest,
  isCustom: false,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  test('reports pending before the delay elapses, ready after', () async {
    final provider = MockVideoGenerationProvider(
      generationDelay: const Duration(milliseconds: 50),
    );
    final job = await provider.requestGeneration(exercise: _testExercise());

    final immediate = await provider.checkStatus(jobId: job.jobId);
    expect(immediate.kind, VideoJobStatusKind.pending);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    final later = await provider.checkStatus(jobId: job.jobId);
    expect(later.kind, VideoJobStatusKind.ready);
    expect(later.resultUrl, isNotNull);
  });

  test('reports failed after the delay when alwaysFail is set', () async {
    final provider = MockVideoGenerationProvider(
      alwaysFail: true,
      generationDelay: const Duration(milliseconds: 20),
    );
    final job = await provider.requestGeneration(exercise: _testExercise());

    await Future<void>.delayed(const Duration(milliseconds: 30));
    final status = await provider.checkStatus(jobId: job.jobId);
    expect(status.kind, VideoJobStatusKind.failed);
    expect(status.errorMessage, isNotNull);
  });

  test('checkStatus derives elapsed time from the jobId, not instance state', () async {
    // A jobId minted 5 seconds ago, as if the app had just relaunched
    // mid-generation, should already read as done — no in-memory timer
    // to lose across a restart.
    final provider = MockVideoGenerationProvider(
      generationDelay: const Duration(seconds: 1),
    );
    final oldJobId =
        'mock-${DateTime.now().subtract(const Duration(seconds: 5)).millisecondsSinceEpoch}';

    final status = await provider.checkStatus(jobId: oldJobId);
    expect(status.kind, VideoJobStatusKind.ready);
  });
}
