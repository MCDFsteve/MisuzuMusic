import 'package:characters/characters.dart';
import 'package:collection/collection.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/lyrics_entities.dart';

class ParsedLyricsLine {
  const ParsedLyricsLine({
    required this.plain,
    required this.segments,
    this.translation,
  });

  final String plain;
  final List<AnnotatedText> segments;
  final String? translation;

  bool get hasContent => plain.isNotEmpty || (translation?.isNotEmpty ?? false);
}

class DesktopLyricsParser {
  const DesktopLyricsParser();

  ParsedLyricsLine parse(String? rawLine) {
    if (rawLine == null) {
      return const ParsedLyricsLine(plain: '', segments: []);
    }
    String text = rawLine.trim();
    if (text.isEmpty) {
      return const ParsedLyricsLine(plain: '', segments: []);
    }

    String? translation;
    final translationMatch = _translationPattern.firstMatch(text);
    if (translationMatch != null) {
      translation = translationMatch.group(1)?.trim();
      text = text.substring(0, translationMatch.start).trimRight();
    }

    final matches = _rubyPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return ParsedLyricsLine(
        plain: text,
        segments: [
          AnnotatedText(
            original: text,
            annotation: '',
            type: TextType.other,
          ),
        ],
        translation: translation,
      );
    }

    final List<AnnotatedText> segments = [];
    final StringBuffer plain = StringBuffer();
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        final chunk = text.substring(lastIndex, match.start);
        if (chunk.isNotEmpty) {
          segments.add(
            AnnotatedText(
              original: chunk,
              annotation: '',
              type: TextType.other,
            ),
          );
          plain.write(chunk);
        }
      }

      final base = match.group(1) ?? '';
      final annotation = match.group(2) ?? '';
      if (base.isNotEmpty) {
        segments.add(
          AnnotatedText(
            original: base,
            annotation: annotation,
            type: _detectTextType(base),
          ),
        );
        plain.write(base);
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final rest = text.substring(lastIndex);
      if (rest.isNotEmpty) {
        segments.add(
          AnnotatedText(
            original: rest,
            annotation: '',
            type: TextType.other,
          ),
        );
        plain.write(rest);
      }
    }

    return ParsedLyricsLine(
      plain: plain.toString(),
      segments: segments,
      translation: translation?.isNotEmpty == true ? translation : null,
    );
  }

  TextType _detectTextType(String input) {
    final char = input.characters.firstOrNull;
    if (char == null) {
      return TextType.other;
    }
    final codePoint = char.codeUnitAt(0);
    if (_isKanji(codePoint)) return TextType.kanji;
    if (_isHiragana(codePoint)) return TextType.hiragana;
    if (_isKatakana(codePoint)) return TextType.katakana;
    return TextType.other;
  }

  bool _isKanji(int codeUnit) =>
      (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
      (codeUnit >= 0x3400 && codeUnit <= 0x4DBF);

  bool _isHiragana(int codeUnit) => codeUnit >= 0x3040 && codeUnit <= 0x309F;

  bool _isKatakana(int codeUnit) =>
      (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) ||
      (codeUnit >= 0x31F0 && codeUnit <= 0x31FF);
}

final RegExp _translationPattern = RegExp(r'<([^<>]*)>\s*$', multiLine: false);
final RegExp _rubyPattern = RegExp(r'([^\[]+?)\[(.+?)\]');
