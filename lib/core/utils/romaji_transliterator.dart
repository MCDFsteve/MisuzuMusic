class RomajiTransliterator {
  RomajiTransliterator._();

  static final Map<String, String> _hiraganaMap = {
    'a': 'あ',
    'i': 'い',
    'u': 'う',
    'e': 'え',
    'o': 'お',
    'ka': 'か',
    'ki': 'き',
    'ku': 'く',
    'ke': 'け',
    'ko': 'こ',
    'sa': 'さ',
    'shi': 'し',
    'su': 'す',
    'se': 'せ',
    'so': 'そ',
    'ta': 'た',
    'chi': 'ち',
    'tsu': 'つ',
    'te': 'て',
    'to': 'と',
    'na': 'な',
    'ni': 'に',
    'nu': 'ぬ',
    'ne': 'ね',
    'no': 'の',
    'ha': 'は',
    'hi': 'ひ',
    'fu': 'ふ',
    'he': 'へ',
    'ho': 'ほ',
    'ma': 'ま',
    'mi': 'み',
    'mu': 'む',
    'me': 'め',
    'mo': 'も',
    'ya': 'や',
    'yu': 'ゆ',
    'yo': 'よ',
    'ra': 'ら',
    'ri': 'り',
    'ru': 'る',
    're': 'れ',
    'ro': 'ろ',
    'wa': 'わ',
    'wo': 'を',
    'n': 'ん',
    'ga': 'が',
    'gi': 'ぎ',
    'gu': 'ぐ',
    'ge': 'げ',
    'go': 'ご',
    'za': 'ざ',
    'ji': 'じ',
    'zu': 'ず',
    'ze': 'ぜ',
    'zo': 'ぞ',
    'da': 'だ',
    'di': 'ぢ',
    'du': 'づ',
    'de': 'で',
    'do': 'ど',
    'ba': 'ば',
    'bi': 'び',
    'bu': 'ぶ',
    'be': 'べ',
    'bo': 'ぼ',
    'pa': 'ぱ',
    'pi': 'ぴ',
    'pu': 'ぷ',
    'pe': 'ぺ',
    'po': 'ぽ',
    'kya': 'きゃ',
    'kyu': 'きゅ',
    'kyo': 'きょ',
    'gya': 'ぎゃ',
    'gyu': 'ぎゅ',
    'gyo': 'ぎょ',
    'sha': 'しゃ',
    'shu': 'しゅ',
    'sho': 'しょ',
    'ja': 'じゃ',
    'ju': 'じゅ',
    'jo': 'じょ',
    'cha': 'ちゃ',
    'chu': 'ちゅ',
    'cho': 'ちょ',
    'nya': 'にゃ',
    'nyu': 'にゅ',
    'nyo': 'にょ',
    'hya': 'ひゃ',
    'hyu': 'ひゅ',
    'hyo': 'ひょ',
    'bya': 'びゃ',
    'byu': 'びゅ',
    'byo': 'びょ',
    'pya': 'ぴゃ',
    'pyu': 'ぴゅ',
    'pyo': 'ぴょ',
    'mya': 'みゃ',
    'myu': 'みゅ',
    'myo': 'みょ',
    'rya': 'りゃ',
    'ryu': 'りゅ',
    'ryo': 'りょ',
    'fa': 'ふぁ',
    'fi': 'ふぃ',
    'fe': 'ふぇ',
    'fo': 'ふぉ',
    'wi': 'うぃ',
    'we': 'うぇ',
    'va': 'ゔぁ',
    'vi': 'ゔぃ',
    'vu': 'ゔ',
    've': 'ゔぇ',
    'vo': 'ゔぉ',
  };

  static final RegExp _romajiPattern = RegExp(r"^[a-zA-Z'-]+$");
  static const String _smallTsu = 'っ';

  static bool _isVowel(String c) => 'aeiou'.contains(c);
  static bool _isConsonant(String c) => RegExp(r'[bcdfghjklmnpqrstvwxyz]').hasMatch(c);

  static String? _toHiragana(String input) {
    if (input.isEmpty) return null;
    final lower = input.toLowerCase();
    if (!_romajiPattern.hasMatch(lower.replaceAll(' ', ''))) {
      return null;
    }

    final buffer = StringBuffer();
    int index = 0;
    while (index < lower.length) {
      final char = lower[index];

      if (char == ' ') {
        index++;
        continue;
      }

      if (char == "'") {
        index++;
        continue;
      }

      if (char == '-') {
        buffer.write('ー');
        index++;
        continue;
      }

      if (char == 'n') {
        if (index + 1 == lower.length) {
          buffer.write('ん');
          index++;
          continue;
        }
        final next = lower[index + 1];
        if (!_isVowel(next) && next != 'y') {
          buffer.write('ん');
          index++;
          continue;
        }
      }

      if (index + 1 < lower.length &&
          lower[index] == lower[index + 1] &&
          _isConsonant(lower[index]) &&
          lower[index] != 'n') {
        buffer.write(_smallTsu);
        index++;
        continue;
      }

      String? kana;
      int matchLength = 0;
      for (int window = 3; window >= 1; window--) {
        if (index + window > lower.length) continue;
        final segment = lower.substring(index, index + window);
        final mapped = _hiraganaMap[segment];
        if (mapped != null) {
          kana = mapped;
          matchLength = window;
          break;
        }
      }

      kana ??= _hiraganaMap[lower[index]];
      matchLength = matchLength == 0 ? 1 : matchLength;

      if (kana == null) {
        return null;
      }

      buffer.write(kana);
      index += matchLength;
    }

    return buffer.isEmpty ? null : buffer.toString();
  }

  static String _hiraganaToKatakana(String input) {
    final buffer = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      if (codeUnit >= 0x3041 && codeUnit <= 0x3096) {
        buffer.writeCharCode(codeUnit + 0x60);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static List<String> toKanaVariants(String token) {
    if (token.isEmpty) return const [];
    final cleaned = token.trim();
    if (cleaned.isEmpty) return const [];
    if (!_romajiPattern.hasMatch(cleaned)) {
      return const [];
    }

    final hiragana = _toHiragana(cleaned);
    if (hiragana == null) return const [];

    final katakana = _hiraganaToKatakana(hiragana);
    return {hiragana, katakana}.toList();
  }
}
