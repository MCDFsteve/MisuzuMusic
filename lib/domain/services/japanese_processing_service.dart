import '../entities/lyrics_entities.dart';

// Japanese text processing service interface
abstract class JapaneseProcessingService {
  // Initialize the service (e.g., load MeCab dictionary)
  Future<void> initialize();

  // Annotate Japanese text with furigana
  Future<List<AnnotatedText>> annotateText(String text);

  // Convert kanji to hiragana
  Future<String> kanjiToHiragana(String text);

  // Convert katakana to hiragana
  String katakanaToHiragana(String text);

  // Detect if text contains Japanese characters
  bool containsJapanese(String text);

  // Detect if text contains kanji
  bool containsKanji(String text);

  // Detect if text contains katakana
  bool containsKatakana(String text);

  // Cleanup resources
  Future<void> dispose();
}