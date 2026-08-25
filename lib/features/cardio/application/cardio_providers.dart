import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/cardio_repository.dart';

final cardioRepositoryProvider = Provider<CardioRepository>((ref) {
  return CardioRepository(ref.watch(appDatabaseProvider));
});

final cardioEntriesProvider = StreamProvider<List<CardioEntry>>((ref) {
  return ref.watch(cardioRepositoryProvider).watchAllEntries();
});
