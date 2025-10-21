import 'dart:collection';

import 'package:jp_transliterate/jp_transliterate.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/lyrics_entities.dart';

class JapaneseAnnotationService {
  JapaneseAnnotationService._();

  static final Map<String, List<AnnotatedText>> _cache = HashMap();
  static final RegExp _kanjiRegex = RegExp(r'[\u4E00-\u9FFF]');

  static bool containsKanji(String text) {
    return _kanjiRegex.hasMatch(text);
  }

  static Future<List<AnnotatedText>> annotate(String text) async {
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

    try {
      final data = await JpTransliterate.transliterate(kanji: text);
      final hiragana = data.hiragana?.trim() ?? '';
      if (hiragana.isEmpty || hiragana == text.trim()) {
        final plain = _plainSegment(text);
        _cache[text] = plain;
        return plain;
      }

      final annotated = <AnnotatedText>[
        AnnotatedText(
          original: text,
          annotation: hiragana,
          type: TextType.kanji,
        ),
      ];
      _cache[text] = annotated;
      return annotated;
    } catch (e) {
      print('⚠️ JapaneseAnnotationService: transliteration failed -> $e');
      final plain = _plainSegment(text);
      _cache[text] = plain;
      return plain;
    }
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
