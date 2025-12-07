import 'dart:collection';

import '../../domain/entities/lyrics_entities.dart';

/// 合并同一时间轴的歌词行，将后续行视为翻译内容。
class LyricsLineMerger {
  const LyricsLineMerger._();

  /// 将同一时间戳的多行歌词合并到第一行中。
  static List<LyricsLine> mergeByTimestamp(List<LyricsLine> lines) {
    if (lines.length <= 1) {
      return lines;
    }

    final LinkedHashMap<Duration, _MergedLine> merged = LinkedHashMap();

    for (final line in lines) {
      final existing = merged[line.timestamp];
      if (existing == null) {
        merged[line.timestamp] = _MergedLine(line);
      } else {
        existing.absorb(line);
      }
    }

    return merged.values.map((mergedLine) => mergedLine.toLyricsLine()).toList();
  }
}

class _MergedLine {
  _MergedLine(this.base) {
    _appendTranslation(base.translatedText);
  }

  final LyricsLine base;
  final LinkedHashSet<String> translations = LinkedHashSet<String>();

  void absorb(LyricsLine next) {
    _appendTranslation(next.translatedText);
    final String candidate = _extractPlainText(next);
    final String baseText = _extractPlainText(base);
    if (candidate.isNotEmpty && candidate != baseText) {
      _appendTranslation(candidate);
    }
  }

  LyricsLine toLyricsLine() {
    final String? mergedTranslation =
        translations.isEmpty ? null : translations.join('\n');
    if (mergedTranslation == base.translatedText) {
      return base;
    }
    return LyricsLine(
      timestamp: base.timestamp,
      originalText: base.originalText,
      translatedText: mergedTranslation,
      annotatedTexts: base.annotatedTexts,
    );
  }

  void _appendTranslation(String? value) {
    if (value == null) {
      return;
    }
    for (final piece in value.split('\n')) {
      final normalized = piece.trim();
      if (normalized.isEmpty) {
        continue;
      }
      translations.add(normalized);
    }
  }
}

String _extractPlainText(LyricsLine line) {
  final String original = line.originalText.trim();
  if (original.isNotEmpty) {
    return original;
  }
  if (line.annotatedTexts.isNotEmpty) {
    final StringBuffer buffer = StringBuffer();
    for (final segment in line.annotatedTexts) {
      buffer.write(segment.original);
    }
    return buffer.toString().trim();
  }
  return '';
}
