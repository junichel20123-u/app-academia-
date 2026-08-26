const Map<String, String> _diacriticsMap = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

String _removeDiacritics(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticsMap[char] ?? char);
  }
  return buffer.toString();
}

/// Deterministic, stable identifier derived from a display name — used to
/// address seeded/catalog exercises from a server or an LLM without relying
/// on the local autoincrement id (which is only stable within one install).
/// Lowercase, PT-BR accents stripped, any non-alphanumeric run collapsed to
/// a single `-`, trimmed at both ends. E.g. "Supino reto com barra" ->
/// "supino-reto-com-barra".
String slugify(String input) {
  final lower = _removeDiacritics(input.toLowerCase());
  final collapsed = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
}
