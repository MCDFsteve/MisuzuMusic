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
      print('🈲 Annotation cache hit for "$text"');
      return cached;
    }

    if (!containsKanji(text)) {
      print('🈳 Annotation skip (no kanji) for "$text"');
      final plain = _plainSegment(text);
      _cache[text] = plain;
      return plain;
    }

    try {
      print('🈶 Annotation request for "$text"');
      final data = await JpTransliterate.transliterate(kanji: text);
      final hiragana = data.hiragana?.trim() ?? '';
      if (hiragana.isEmpty || hiragana == text.trim()) {
        print('🈚 Annotation empty result for "$text"');
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
      print('🈴 Annotation success for "$text" -> "$hiragana"');
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
    if (text.isNotEmpty) {
      print('🈵 Annotation fallback plain for "$text"');
    }
    return [
      AnnotatedText(
        original: text,
        annotation: text,
        type: TextType.other,
      ),
    ];
  }
}
