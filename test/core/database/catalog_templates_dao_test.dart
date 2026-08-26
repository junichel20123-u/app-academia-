import 'package:app_academia/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  CatalogTemplatesCompanion template(String slug, {String name = 'Push'}) {
    return CatalogTemplatesCompanion.insert(
      slug: slug,
      name: name,
      payloadJson: '{}',
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('starts empty', () async {
    expect(await db.catalogTemplatesDao.getAllTemplates(), isEmpty);
  });

  test(
    'replaceAll inserts entries readable by getAllTemplates/getBySlug',
    () async {
      await db.catalogTemplatesDao.replaceAll([
        template('push-pull-legs'),
        template('full-body-iniciante', name: 'Full body iniciante'),
      ]);

      final all = await db.catalogTemplatesDao.getAllTemplates();
      expect(
        all.map((t) => t.slug),
        containsAll(['push-pull-legs', 'full-body-iniciante']),
      );

      final one = await db.catalogTemplatesDao.getBySlug('push-pull-legs');
      expect(one!.name, 'Push');
    },
  );

  test(
    'a second replaceAll replaces the previous content, not accumulates',
    () async {
      await db.catalogTemplatesDao.replaceAll([template('push-pull-legs')]);
      await db.catalogTemplatesDao.replaceAll([template('upper-lower')]);

      final all = await db.catalogTemplatesDao.getAllTemplates();
      expect(all.length, 1);
      expect(all.single.slug, 'upper-lower');
    },
  );

  test('watchAllTemplates emits an updated list after replaceAll', () async {
    final emissions = <int>[];
    final subscription = db.catalogTemplatesDao.watchAllTemplates().listen(
      (list) => emissions.add(list.length),
    );

    await pumpEventQueue();
    await db.catalogTemplatesDao.replaceAll([template('push-pull-legs')]);
    await pumpEventQueue();

    expect(emissions, [0, 1]);
    await subscription.cancel();
  });
}
