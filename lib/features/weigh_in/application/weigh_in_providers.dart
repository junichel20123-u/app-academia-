import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/weigh_in_repository.dart';

final weighInRepositoryProvider = Provider<WeighInRepository>((ref) {
  return WeighInRepository(ref.watch(appDatabaseProvider));
});

final weighInsProvider = StreamProvider<List<WeighIn>>((ref) {
  return ref.watch(weighInRepositoryProvider).watchAllWeighIns();
});
