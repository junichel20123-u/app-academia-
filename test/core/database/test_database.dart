import 'package:app_academia/core/database/app_database.dart';
import 'package:drift/native.dart';

AppDatabase openTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
