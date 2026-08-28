import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/ai_coach/data/ai_coach_repository.dart';
import 'package:app_academia/features/ai_coach/domain/coach_context.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/database/test_database.dart';

void main() {
  late AppDatabase db;
  late AiCoachRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = AiCoachRepository(db);
  });
  tearDown(() => db.close());

  test('isPremiumUnlocked reflects the same shared settings flag as the plan builder', () async {
    expect(await repository.isPremiumUnlocked(), isFalse);

    await db.userSettingsDao.saveSettings(
      const UserSettingsTableCompanion(aiPlanBuilderPremiumUnlocked: Value(true)),
    );

    expect(await repository.isPremiumUnlocked(), isTrue);
  });

  group('buildContext', () {
    test('flags sedentary with no completed sessions and no weight data', () async {
      final context = await repository.buildContext(
        goal: 'hipertrofia',
        experienceLevel: 'beginner',
      );

      expect(context.goal, 'hipertrofia');
      expect(context.experienceLevel, 'beginner');
      expect(context.sedentary, isTrue);
      expect(context.latestWeightKg, isNull);
      expect(context.weightTrend, isNull);
      expect(context.summaryText, contains('Sem treinos completados'));
    });

    test('is not sedentary with a session completed in the last 14 days', () async {
      await db.sessionsDao.startSession(
        WorkoutSessionsCompanion.insert(
          name: 'Treino recente',
          status: WorkoutSessionStatus.completed,
          startedAt: Value(DateTime.now().subtract(const Duration(days: 2))),
          completedAt: Value(DateTime.now().subtract(const Duration(days: 2))),
        ),
      );

      final context = await repository.buildContext();

      expect(context.sedentary, isFalse);
      expect(context.summaryText, contains('regularidade'));
    });

    test('stays sedentary when the only completed session is older than 14 days', () async {
      await db.sessionsDao.startSession(
        WorkoutSessionsCompanion.insert(
          name: 'Treino antigo',
          status: WorkoutSessionStatus.completed,
          startedAt: Value(DateTime.now().subtract(const Duration(days: 40))),
          completedAt: Value(DateTime.now().subtract(const Duration(days: 40))),
        ),
      );

      final context = await repository.buildContext();

      expect(context.sedentary, isTrue);
    });

    test('reports a single weigh-in with no trend', () async {
      await db.weighInsDao.insertWeighIn(
        WeighInsCompanion.insert(weightKg: 80.0),
      );

      final context = await repository.buildContext();

      expect(context.latestWeightKg, 80.0);
      expect(context.weightTrend, isNull);
    });

    test('detects an upward weight trend', () async {
      final now = DateTime.now();
      await db.weighInsDao.insertWeighIn(
        WeighInsCompanion.insert(
          weightKg: 78.0,
          occurredAt: Value(now.subtract(const Duration(days: 30))),
        ),
      );
      await db.weighInsDao.insertWeighIn(
        WeighInsCompanion.insert(weightKg: 82.0, occurredAt: Value(now)),
      );

      final context = await repository.buildContext();

      expect(context.latestWeightKg, 82.0);
      expect(context.weightTrend, WeightTrend.up);
      expect(context.summaryText, contains('alta'));
    });

    test('detects a downward weight trend', () async {
      final now = DateTime.now();
      await db.weighInsDao.insertWeighIn(
        WeighInsCompanion.insert(
          weightKg: 82.0,
          occurredAt: Value(now.subtract(const Duration(days: 30))),
        ),
      );
      await db.weighInsDao.insertWeighIn(
        WeighInsCompanion.insert(weightKg: 78.0, occurredAt: Value(now)),
      );

      final context = await repository.buildContext();

      expect(context.weightTrend, WeightTrend.down);
    });

    test('treats a small change as a stable trend', () async {
      final now = DateTime.now();
      await db.weighInsDao.insertWeighIn(
        WeighInsCompanion.insert(
          weightKg: 80.0,
          occurredAt: Value(now.subtract(const Duration(days: 30))),
        ),
      );
      await db.weighInsDao.insertWeighIn(
        WeighInsCompanion.insert(weightKg: 80.2, occurredAt: Value(now)),
      );

      final context = await repository.buildContext();

      expect(context.weightTrend, WeightTrend.stable);
    });
  });

  group('sendMessage', () {
    test('throws StateError when Supabase is not configured', () {
      expect(
        () => repository.sendMessage(
          history: const [],
          context: const CoachContext(
            goal: null,
            experienceLevel: null,
            sedentary: true,
            latestWeightKg: null,
            weightTrend: null,
            summaryText: '',
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('proposeWorkoutAdjustment', () {
    test('throws StateError when Supabase is not configured', () {
      expect(
        () => repository.proposeWorkoutAdjustment(
          workoutId: 1,
          instructions: 'quero mais foco em resistência',
          context: const CoachContext(
            goal: null,
            experienceLevel: null,
            sedentary: true,
            latestWeightKg: null,
            weightTrend: null,
            summaryText: '',
          ),
          availableEquipment: const {},
        ),
        throwsStateError,
      );
    });
  });
}
