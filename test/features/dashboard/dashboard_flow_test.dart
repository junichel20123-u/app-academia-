import 'package:app_academia/app/router.dart';
import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('streak card reflects completed sessions', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    appRouter.go('/');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    expect(find.text('dias seguidos'), findsOneWidget);

    final sessionId = await db.sessionsDao.startSession(
      WorkoutSessionsCompanion.insert(
        name: 'Treino',
        status: WorkoutSessionStatus.inProgress,
      ),
    );
    final session = await db.sessionsDao.getSessionById(sessionId);
    await db.sessionsDao.updateSession(
      session!.copyWith(
        status: WorkoutSessionStatus.completed,
        completedAt: Value(DateTime.now()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('dia seguido'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
