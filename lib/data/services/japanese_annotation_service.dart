import 'dart:collection';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/app_constants.dart';
import '../../domain/entities/lyrics_entities.dart';

/// Lightweight Japanese annotation helper based on CSV dictionaries.
///
/// Dictionaries live in `assets/japanese_dictionary/` so that translators can
/// grow the coverage without touching source code. Only entries containing at
/// least one kanji are considered; other strings are left unchanged.
class JapaneseAnnotationService {
  JapaneseAnnotationService._();

  static const String _charsAsset = 'assets/japanese_dictionary/chars.csv';

  static final Map<String, List<AnnotatedText>> _cache = HashMap();
  static final RegExp _kanjiRegex = RegExp(r'[\u4E00-\u9FFF]');

  static Map<String, String>? _charDictionary;
  static List<String>? _sortedDictionaryKeys;
  static bool _loading = false;

  static bool containsKanji(String text) => _kanjiRegex.hasMatch(text);

  static void clearCache() => _cache.clear();

  static Future<List<AnnotatedText>> annotate(String text) async {
    await _ensureDictionaryLoaded();
    if (text.isEmpty) {
      return _plainSegment(text);
    }

    final cached = _cache[text];
    if (cached != null) {
      return cached;
    }

    if (!containsKanji(text)) {
      final plain = _plainSegment(text);
      _cache[text] = plain;
      return plain;
    }

    final segments = _annotateWithDictionary(text);
    if (segments != null) {
      _cache[text] = segments;
      return segments;
    }

    final plain = _plainSegment(text);
    _cache[text] = plain;
    return plain;
  }

  static Future<void> _ensureDictionaryLoaded() async {
    if (_sortedDictionaryKeys != null || _loading) {
      return;
    }
    _loading = true;
    try {
      final raw = await rootBundle.loadString(_charsAsset);
      final charMap = _parseCsv(raw);
      _charDictionary = charMap;
      _sortedDictionaryKeys = charMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
    } catch (e) {
      _charDictionary = const {};
      _sortedDictionaryKeys = const [];
    } finally {
      _loading = false;
    }
  }

  static List<AnnotatedText>? _annotateWithDictionary(String text) {
    final chars = _charDictionary;
    final sorted = _sortedDictionaryKeys;
    if (chars == null || sorted == null || sorted.isEmpty) {
      return null;
    }

    final segments = <AnnotatedText>[];
    final buffer = StringBuffer();
    bool annotated = false;
    int index = 0;

    while (index < text.length) {
      final match = _matchCharEntry(text, index, sorted, chars);
      if (match != null) {
        if (buffer.isNotEmpty) {
          segments.add(
            AnnotatedText(
              original: buffer.toString(),
              annotation: buffer.toString(),
              type: TextType.other,
            ),
          );
          buffer.clear();
        }
        segments.add(
          AnnotatedText(
            original: match.entry,
            annotation: match.reading,
            type: TextType.kanji,
          ),
        );
        annotated = true;
        index += match.entry.length;
      } else {
        buffer.write(text[index]);
        index += 1;
      }
    }

    if (buffer.isNotEmpty) {
      segments.add(
        AnnotatedText(
          original: buffer.toString(),
          annotation: buffer.toString(),
          type: TextType.other,
        ),
      );
    }

    return annotated ? segments : null;
  }

  static _DictionaryMatch? _matchCharEntry(
    String text,
    int start,
    List<String> sortedKeys,
    Map<String, String> chars,
  ) {
    for (final key in sortedKeys) {
      if (text.startsWith(key, start)) {
        final reading = chars[key];
        if (reading != null) {
          return _DictionaryMatch(key, reading);
        }
      }
    }
    return null;
  }

  static Map<String, String> _parseCsv(String raw) {
    final map = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final parts = trimmed.split(',');
      if (parts.length < 2) {
        continue;
      }
      final word = parts[0].trim();
      final reading = parts[1].trim();
      if (word.isEmpty || reading.isEmpty) {
        continue;
      }
      if (!containsKanji(word)) {
        continue;
      }
      map[word] = reading;
    }
    return map;
  }

  static List<AnnotatedText> _plainSegment(String text) {
    return [
      AnnotatedText(
        original: text,
        annotation: text,
        type: TextType.other,
      ),
    ];
  }
}

class _DictionaryMatch {
  const _DictionaryMatch(this.entry, this.reading);

  final String entry;
  final String reading;
}
