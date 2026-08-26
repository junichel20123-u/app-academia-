import 'package:app_academia/core/utils/slugify.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lowercases the input', () {
    expect(slugify('SUPINO'), 'supino');
  });

  test('removes common PT-BR diacritics', () {
    expect(slugify('Tríceps testa com barra'), 'triceps-testa-com-barra');
    expect(slugify('Elevação lateral'), 'elevacao-lateral');
    expect(slugify('Cadeira extensora'), 'cadeira-extensora');
  });

  test('collapses spaces and punctuation into a single dash', () {
    expect(slugify('Supino reto com barra'), 'supino-reto-com-barra');
    expect(slugify('Puxada  frontal!!'), 'puxada-frontal');
  });

  test('trims leading and trailing dashes', () {
    expect(slugify('  Agachamento livre  '), 'agachamento-livre');
    expect(slugify('-já com traço-'), 'ja-com-traco');
  });

  test('returns an empty string for input with no alphanumeric content', () {
    expect(slugify(''), '');
    expect(slugify('!!!'), '');
  });

  test('is deterministic', () {
    expect(
      slugify('Rosca direta com barra'),
      slugify('Rosca direta com barra'),
    );
  });
}
