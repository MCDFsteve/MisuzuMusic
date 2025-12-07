import 'package:misuzu_music/core/constants/app_constants.dart';
import 'package:misuzu_music/core/utils/lyrics_line_merger.dart';

import '../../domain/entities/lyrics_entities.dart';

class LyricsModel extends Lyrics {
  const LyricsModel({
    required super.trackId,
    required super.lines,
    required super.format,
    super.source,
  });

  factory LyricsModel.fromEntity(Lyrics lyrics) {
    final normalizedLines = LyricsLineMerger.mergeByTimestamp(lyrics.lines);
    return LyricsModel(
      trackId: lyrics.trackId,
      lines: normalizedLines
          .map((line) => LyricsLineModel.fromEntity(line))
          .toList(),
      format: lyrics.format,
      source: lyrics.source,
    );
  }

  factory LyricsModel.fromMap(Map<String, dynamic> map) {
    final content = map['content'] as String;
    final formatStr = map['format'] as String;
    final format = LyricsFormat.values.firstWhere(
      (f) => f.toString().split('.').last == formatStr,
      orElse: () => LyricsFormat.text,
    );

    List<LyricsLine> lines;
    if (format == LyricsFormat.lrc) {
      lines = _parseLrcContent(content);
    } else {
      lines = _parseTextContent(content);
    }

    return LyricsModel(
      trackId: map['track_id'] as String,
      lines: lines.map((line) => LyricsLineModel.fromEntity(line)).toList(),
      format: format,
    );
  }

  Map<String, dynamic> toMap() {
    String content;
    if (format == LyricsFormat.lrc) {
      content = _toLrcContent();
    } else {
      content = _toTextContent();
    }

    return {
      'track_id': trackId,
      'content': content,
      'format': format.toString().split('.').last,
    };
  }

  Lyrics toEntity() {
    return Lyrics(
      trackId: trackId,
      lines: lines.map((line) => (line as LyricsLineModel).toEntity()).toList(),
      format: format,
      source: source,
    );
  }

  String _toLrcContent() {
    final buffer = StringBuffer();
    for (final line in lines) {
      final annotated = _formatAnnotatedLine(line.annotatedTexts);
      final timestamp = line.timestamp;
      final minutes = timestamp.inMinutes.toString().padLeft(2, '0');
      final seconds = (timestamp.inSeconds % 60).toString().padLeft(2, '0');
      final milliseconds =
          (timestamp.inMilliseconds % 1000).toString().padLeft(3, '0');
      final translation = line.translatedText?.trim();
      final suffix = (translation != null && translation.isNotEmpty)
          ? ' <${translation.replaceAll('\n', ' ')}>'
          : '';

      buffer.writeln('[$minutes:$seconds.$milliseconds]$annotated$suffix');
    }
    return buffer.toString();
  }

  String _toTextContent() {
    return lines
        .map(
          (line) => line.translatedText == null || line.translatedText!.isEmpty
              ? line.originalText
              : '${line.originalText} <${line.translatedText}>',
        )
        .join('\n');
  }

  static List<LyricsLine> _parseLrcContent(String content) {
    final lines = <LyricsLine>[];
    final lrcLines = content.split('\n');

    for (final lrcLine in lrcLines) {
      final match = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)')
          .firstMatch(lrcLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3)!;
        final milliseconds = fraction.length == 3
            ? int.parse(fraction)
            : int.parse(fraction) * 10;
        final raw = match.group(4)!.trim();
        final split = _extractTranslation(raw);
        final parsed = _parseAnnotatedLine(split.text);

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        lines.add(
          LyricsLine(
            timestamp: timestamp,
            originalText: parsed.text,
            translatedText: split.translation,
            annotatedTexts: parsed.segments,
          ),
        );
      }
    }

    return LyricsLineMerger.mergeByTimestamp(lines);
  }

  static List<LyricsLine> _parseTextContent(String content) {
    final lines = <LyricsLine>[];
    final textLines = content.split('\n');

    for (int i = 0; i < textLines.length; i++) {
      final raw = textLines[i].trim();
      if (raw.isNotEmpty) {
        final split = _extractTranslation(raw);
        final parsed = _parseAnnotatedLine(split.text);
        lines.add(
          LyricsLine(
            timestamp: Duration(seconds: i * 5), // Default 5 seconds per line
            originalText: parsed.text,
            translatedText: split.translation,
            annotatedTexts: parsed.segments,
          ),
        );
      }
    }

    return LyricsLineMerger.mergeByTimestamp(lines);
  }

  static List<LyricsLine> parseLrc(String content) => _parseLrcContent(content);

  static _TranslationSplit _extractTranslation(String raw) {
    final match = RegExp(r'<([^<>]+)>\s*$', multiLine: false).firstMatch(raw);
    if (match == null) {
      return _TranslationSplit(text: raw.trimRight(), translation: null);
    }

    final baseText = raw.substring(0, match.start).trimRight();
    final translation = match.group(1)?.trim();
    return _TranslationSplit(
      text: baseText,
      translation: (translation == null || translation.isEmpty)
          ? null
          : translation,
    );
  }
}

class LyricsLineModel extends LyricsLine {
  const LyricsLineModel({
    required super.timestamp,
    required super.originalText,
    super.translatedText,
    required super.annotatedTexts,
  });

  factory LyricsLineModel.fromEntity(LyricsLine line) {
    return LyricsLineModel(
      timestamp: line.timestamp,
      originalText: line.originalText,
      translatedText: line.translatedText,
      annotatedTexts: line.annotatedTexts
          .map((text) => AnnotatedTextModel.fromEntity(text))
          .toList(),
    );
  }

  LyricsLine toEntity() {
    return LyricsLine(
      timestamp: timestamp,
      originalText: originalText,
      translatedText: translatedText,
      annotatedTexts: annotatedTexts
          .map((text) => (text as AnnotatedTextModel).toEntity())
          .toList(),
    );
  }

  LyricsLineModel copyWith({
    Duration? timestamp,
    String? originalText,
    String? translatedText,
    List<AnnotatedText>? annotatedTexts,
  }) {
    return LyricsLineModel(
      timestamp: timestamp ?? this.timestamp,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      annotatedTexts: annotatedTexts ?? this.annotatedTexts,
    );
  }
}

class _TranslationSplit {
  const _TranslationSplit({required this.text, required this.translation});

  final String text;
  final String? translation;
}

class AnnotatedTextModel extends AnnotatedText {
  const AnnotatedTextModel({
    required super.original,
    required super.annotation,
    required super.type,
  });

  factory AnnotatedTextModel.fromEntity(AnnotatedText text) {
    return AnnotatedTextModel(
      original: text.original,
      annotation: text.annotation,
      type: text.type,
    );
  }

  AnnotatedText toEntity() {
    return AnnotatedText(
      original: original,
      annotation: annotation,
      type: type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'original': original,
      'annotation': annotation,
      'type': type.toString().split('.').last,
    };
  }

  factory AnnotatedTextModel.fromMap(Map<String, dynamic> map) {
    return AnnotatedTextModel(
      original: map['original'] as String,
      annotation: map['annotation'] as String,
      type: TextType.values.firstWhere(
        (t) => t.toString().split('.').last == map['type'],
        orElse: () => TextType.other,
      ),
    );
  }
}

String _formatAnnotatedLine(List<AnnotatedText> annotatedTexts) {
  if (annotatedTexts.isEmpty) {
    return '';
  }
  final buffer = StringBuffer();
  for (final text in annotatedTexts) {
    if (text.type == TextType.kanji &&
        text.annotation.trim().isNotEmpty &&
        text.annotation.trim() != text.original.trim()) {
      buffer.write('${text.original}[${text.annotation}]');
    } else {
      buffer.write(text.original);
    }
  }
  return buffer.toString();
}

_ParsedAnnotatedLine _parseAnnotatedLine(String rawText) {
  final segments = <AnnotatedText>[];
  final pattern = RegExp(r'([^\[\]]+)\[([^\[\]]+)\]');
  int currentIndex = 0;

  for (final match in pattern.allMatches(rawText)) {
    final start = match.start;
    final end = match.end;

    if (start > currentIndex) {
      final plainSegment = rawText.substring(currentIndex, start);
      if (plainSegment.isNotEmpty) {
        segments.add(
          AnnotatedText(
            original: plainSegment,
            annotation: plainSegment,
            type: TextType.other,
          ),
        );
      }
    }

    final baseRaw = match.group(1)!.trim();
    final ruby = match.group(2)!.trim();

    if (baseRaw.isNotEmpty) {
      final split = _separatePrefix(baseRaw, ruby);

      if (split.prefix.isNotEmpty) {
        segments.add(
          AnnotatedText(
            original: split.prefix,
            annotation: split.prefix,
            type: TextType.other,
          ),
        );
      }

      if (split.core.isNotEmpty) {
        segments.add(
          AnnotatedText(
            original: split.core,
            annotation: ruby,
            type: TextType.kanji,
          ),
        );
      }
    }

    currentIndex = end;
  }

  if (currentIndex < rawText.length) {
    final tail = rawText.substring(currentIndex);
    if (tail.isNotEmpty) {
      segments.add(
        AnnotatedText(
          original: tail,
          annotation: tail,
          type: TextType.other,
        ),
      );
    }
  }

  if (segments.isEmpty) {
    segments.add(
      AnnotatedText(
        original: rawText,
        annotation: rawText,
        type: TextType.other,
      ),
    );
  }

  final buffer = StringBuffer();
  for (final segment in segments) {
    buffer.write(segment.original);
  }

  return _ParsedAnnotatedLine(text: buffer.toString(), segments: segments);
}

class _ParsedAnnotatedLine {
  const _ParsedAnnotatedLine({required this.text, required this.segments});

  final String text;
  final List<AnnotatedText> segments;
}

class _BaseSplitResult {
  const _BaseSplitResult({required this.prefix, required this.core});

  final String prefix;
  final String core;
}

_BaseSplitResult _separatePrefix(String base, String ruby) {
  if (base.isEmpty) {
    return const _BaseSplitResult(prefix: '', core: '');
  }

  final kanjiRegex = RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF々〆ヶ]');
  int firstKanjiIndex = -1;

  for (int i = 0; i < base.length; i++) {
    final char = base[i];
    if (kanjiRegex.hasMatch(char)) {
      firstKanjiIndex = i;
      break;
    }
  }

  if (firstKanjiIndex <= 0) {
    return _BaseSplitResult(prefix: '', core: base);
  }

  final prefix = base.substring(0, firstKanjiIndex);
  final core = base.substring(firstKanjiIndex);

  if (ruby.startsWith(prefix)) {
    return _BaseSplitResult(prefix: '', core: base);
  }

  return _BaseSplitResult(prefix: prefix, core: core);
}

class LyricsSettingsModel extends LyricsSettings {
  const LyricsSettingsModel({
    super.showAnnotation,
    super.annotationFontSize,
    super.textFontSize,
    super.autoScroll,
  });

  factory LyricsSettingsModel.fromEntity(LyricsSettings settings) {
    return LyricsSettingsModel(
      showAnnotation: settings.showAnnotation,
      annotationFontSize: settings.annotationFontSize,
      textFontSize: settings.textFontSize,
      autoScroll: settings.autoScroll,
    );
  }

  factory LyricsSettingsModel.fromMap(Map<String, dynamic> map) {
    return LyricsSettingsModel(
      showAnnotation: map['show_annotation'] as bool? ?? true,
      annotationFontSize: (map['annotation_font_size'] as num?)?.toDouble() ?? 14.0,
      textFontSize: (map['text_font_size'] as num?)?.toDouble() ?? 18.0,
      autoScroll: map['auto_scroll'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'show_annotation': showAnnotation,
      'annotation_font_size': annotationFontSize,
      'text_font_size': textFontSize,
      'auto_scroll': autoScroll,
    };
  }

  LyricsSettings toEntity() {
    return LyricsSettings(
      showAnnotation: showAnnotation,
      annotationFontSize: annotationFontSize,
      textFontSize: textFontSize,
      autoScroll: autoScroll,
    );
  }

  @override
  LyricsSettingsModel copyWith({
    bool? showAnnotation,
    double? annotationFontSize,
    double? textFontSize,
    bool? autoScroll,
  }) {
    return LyricsSettingsModel(
      showAnnotation: showAnnotation ?? this.showAnnotation,
      annotationFontSize: annotationFontSize ?? this.annotationFontSize,
      textFontSize: textFontSize ?? this.textFontSize,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }
}
