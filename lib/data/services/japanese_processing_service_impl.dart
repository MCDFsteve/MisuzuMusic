import 'package:kana_kit/kana_kit.dart';

import '../../domain/entities/lyrics_entities.dart';
import '../../domain/services/japanese_processing_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';

class JapaneseProcessingServiceImpl implements JapaneseProcessingService {
  late final KanaKit _kanaKit;
  bool _isInitialized = false;

  // Japanese character regex patterns
  static final RegExp _kanjiRegex = RegExp(r'[\u4e00-\u9faf]');
  static final RegExp _katakanaRegex = RegExp(r'[\u30a1-\u30fe]');
  static final RegExp _hiraganaRegex = RegExp(r'[\u3041-\u309e]');
  static final RegExp _japaneseRegex = RegExp(r'[\u3041-\u309e\u30a1-\u30fe\u4e00-\u9faf]');

  // Common kanji to reading mappings (basic implementation)
  static const Map<String, String> _kanjiReadings = {
    '音楽': 'おんがく',
    '歌': 'うた',
    '愛': 'あい',
    '心': 'こころ',
    '夢': 'ゆめ',
    '空': 'そら',
    '海': 'うみ',
    '山': 'やま',
    '花': 'はな',
    '桜': 'さくら',
    '雨': 'あめ',
    '雪': 'ゆき',
    '風': 'かぜ',
    '太陽': 'たいよう',
    '月': 'つき',
    '星': 'ほし',
    '君': 'きみ',
    '僕': 'ぼく',
    '私': 'わたし',
    '貴方': 'あなた',
    '今日': 'きょう',
    '昨日': 'きのう',
    '明日': 'あした',
    '時間': 'じかん',
    '世界': 'せかい',
    '人生': 'じんせい',
    '友達': 'ともだち',
    '家族': 'かぞく',
    '学校': 'がっこう',
    '仕事': 'しごと',
    '未来': 'みらい',
    '過去': 'かこ',
    '現在': 'げんざい',
    '幸せ': 'しあわせ',
    '悲しい': 'かなしい',
    '楽しい': 'たのしい',
    '美しい': 'うつくしい',
    '大切': 'たいせつ',
    '特別': 'とくべつ',
    '一緒': 'いっしょ',
    '永遠': 'えいえん',
    '希望': 'きぼう',
    '勇気': 'ゆうき',
    '努力': 'どりょく',
    '成功': 'せいこう',
    '失敗': 'しっぱい',
    '経験': 'けいけん',
    '思い出': 'おもいで',
    '記憶': 'きおく',
    '感情': 'かんじょう',
    '気持ち': 'きもち',
    '気分': 'きぶん',
    '自然': 'しぜん',
    '季節': 'きせつ',
    '春': 'はる',
    '夏': 'なつ',
    '秋': 'あき',
    '冬': 'ふゆ',
    '朝': 'あさ',
    '昼': 'ひる',
    '夜': 'よる',
    '夕方': 'ゆうがた',
  };

  @override
  Future<void> initialize() async {
    try {
      _kanaKit = const KanaKit();
      _isInitialized = true;
    } catch (e) {
      throw JapaneseProcessingException('Failed to initialize Japanese processing service: ${e.toString()}');
    }
  }

  @override
  Future<List<AnnotatedText>> annotateText(String text) async {
    if (!_isInitialized) {
      throw JapaneseProcessingException('Service not initialized');
    }

    final List<AnnotatedText> result = [];
    final buffer = StringBuffer();
    TextType? currentType;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final charType = _getTextType(char);

      if (currentType == null) {
        currentType = charType;
        buffer.write(char);
      } else if (currentType == charType) {
        buffer.write(char);
      } else {
        // Type changed, process the accumulated text
        final accumulated = buffer.toString();
        result.add(await _createAnnotatedText(accumulated, currentType));

        buffer.clear();
        buffer.write(char);
        currentType = charType;
      }
    }

    // Process remaining text
    if (buffer.isNotEmpty) {
      final accumulated = buffer.toString();
      result.add(await _createAnnotatedText(accumulated, currentType!));
    }

    return result;
  }

  Future<AnnotatedText> _createAnnotatedText(String text, TextType type) async {
    String annotation = '';

    switch (type) {
      case TextType.kanji:
        annotation = await kanjiToHiragana(text);
        break;
      case TextType.katakana:
        annotation = katakanaToHiragana(text);
        break;
      case TextType.hiragana:
      case TextType.other:
        annotation = text; // No annotation needed
        break;
    }

    return AnnotatedText(
      original: text,
      annotation: annotation,
      type: type,
    );
  }

  @override
  Future<String> kanjiToHiragana(String text) async {
    if (!_isInitialized) {
      throw JapaneseProcessingException('Service not initialized');
    }

    // First, try to find exact matches in our dictionary
    if (_kanjiReadings.containsKey(text)) {
      return _kanjiReadings[text]!;
    }

    // For compound words, try to break them down
    // This is a simplified implementation
    String result = '';
    String currentWord = '';

    for (int i = 0; i < text.length; i++) {
      currentWord += text[i];

      if (_kanjiReadings.containsKey(currentWord)) {
        result += _kanjiReadings[currentWord]!;
        currentWord = '';
      } else if (i == text.length - 1) {
        // Last character and no match found
        if (_kanjiReadings.containsKey(currentWord)) {
          result += _kanjiReadings[currentWord]!;
        } else {
          // Single kanji fallback - this would need a more sophisticated approach
          result += currentWord; // Return as-is for now
        }
      }
    }

    return result.isEmpty ? text : result;
  }

  @override
  String katakanaToHiragana(String text) {
    if (!_isInitialized) {
      throw JapaneseProcessingException('Service not initialized');
    }

    try {
      return _kanaKit.toHiragana(text);
    } catch (e) {
      // Fallback: manual conversion
      return _manualKatakanaToHiragana(text);
    }
  }

  String _manualKatakanaToHiragana(String text) {
    const katakana = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポァィゥェォャュョッ';
    const hiragana = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽぁぃぅぇぉゃゅょっ';

    String result = '';
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final index = katakana.indexOf(char);
      if (index != -1) {
        result += hiragana[index];
      } else {
        result += char;
      }
    }
    return result;
  }

  @override
  bool containsJapanese(String text) {
    return _japaneseRegex.hasMatch(text);
  }

  @override
  bool containsKanji(String text) {
    return _kanjiRegex.hasMatch(text);
  }

  @override
  bool containsKatakana(String text) {
    return _katakanaRegex.hasMatch(text);
  }

  TextType _getTextType(String char) {
    if (_kanjiRegex.hasMatch(char)) {
      return TextType.kanji;
    } else if (_katakanaRegex.hasMatch(char)) {
      return TextType.katakana;
    } else if (_hiraganaRegex.hasMatch(char)) {
      return TextType.hiragana;
    } else {
      return TextType.other;
    }
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    // Clean up any resources if needed
  }
}