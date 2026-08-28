import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/video_generation/data/stock_video_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _exercise({String? slug}) {
  return Exercise(
    id: 1,
    name: 'Supino reto com barra',
    slug: slug,
    muscleGroup: MuscleGroup.chest,
    equipment: Equipment.barbell,
    isCustom: slug == null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('buildStockVideoUrl', () {
    test('builds the public object URL for a slug', () {
      expect(
        buildStockVideoUrl('https://project.supabase.co', 'burpee'),
        'https://project.supabase.co/storage/v1/object/public/exercise-videos/burpee.mp4',
      );
    });
  });

  group('StockVideoProvider.hasVideoFor', () {
    test('is false when Supabase is not configured (null baseUrl)', () async {
      final provider = StockVideoProvider(baseUrl: null);
      expect(await provider.hasVideoFor(_exercise(slug: 'burpee')), isFalse);
    });

    test('is false for an exercise with no slug (custom exercise)', () async {
      final provider = StockVideoProvider(
        baseUrl: 'https://project.supabase.co',
      );
      expect(await provider.hasVideoFor(_exercise(slug: null)), isFalse);
    });
  });

  group('StockVideoProvider.downloadBytes', () {
    test('throws when Supabase is not configured (null baseUrl)', () {
      final provider = StockVideoProvider(baseUrl: null);
      expect(() => provider.downloadBytes('burpee'), throwsStateError);
    });
  });
}
