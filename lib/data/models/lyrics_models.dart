import '../../domain/entities/lyrics_entities.dart';

class LyricsModel extends Lyrics {
  const LyricsModel({
    required super.trackId,
    required super.lines,
    required super.format,
  });

  factory LyricsModel.fromEntity(Lyrics lyrics) {
    return LyricsModel(
      trackId: lyrics.trackId,
      lines: lyrics.lines.map((line) => LyricsLineModel.fromEntity(line)).toList(),
      format: lyrics.format,
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
    );
  }

  String _toLrcContent() {
    final buffer = StringBuffer();
    for (final line in lines) {
      final timestamp = line.timestamp;
      final minutes = timestamp.inMinutes.toString().padLeft(2, '0');
      final seconds = (timestamp.inSeconds % 60).toString().padLeft(2, '0');
      final milliseconds = ((timestamp.inMilliseconds % 1000) / 10).round().toString().padLeft(2, '0');

      buffer.writeln('[$minutes:$seconds.$milliseconds]${line.originalText}');
    }
    return buffer.toString();
  }

  String _toTextContent() {
    return lines.map((line) => line.originalText).join('\n');
  }

  static List<LyricsLine> _parseLrcContent(String content) {
    final lines = <LyricsLine>[];
    final lrcLines = content.split('\n');

    for (final lrcLine in lrcLines) {
      final match = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)').firstMatch(lrcLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!);
        final text = match.group(4)!;

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: centiseconds * 10,
        );

        lines.add(LyricsLine(
          timestamp: timestamp,
          originalText: text,
          annotatedTexts: [], // Will be populated when processing Japanese text
        ));
      }
    }

    return lines;
  }

  static List<LyricsLine> _parseTextContent(String content) {
    final lines = <LyricsLine>[];
    final textLines = content.split('\n');

    for (int i = 0; i < textLines.length; i++) {
      final text = textLines[i].trim();
      if (text.isNotEmpty) {
        lines.add(LyricsLine(
          timestamp: Duration(seconds: i * 5), // Default 5 seconds per line
          originalText: text,
          annotatedTexts: [], // Will be populated when processing Japanese text
        ));
      }
    }

    return lines;
  }
}

class LyricsLineModel extends LyricsLine {
  const LyricsLineModel({
    required super.timestamp,
    required super.originalText,
    required super.annotatedTexts,
  });

  factory LyricsLineModel.fromEntity(LyricsLine line) {
    return LyricsLineModel(
      timestamp: line.timestamp,
      originalText: line.originalText,
      annotatedTexts: line.annotatedTexts
          .map((text) => AnnotatedTextModel.fromEntity(text))
          .toList(),
    );
  }

  LyricsLine toEntity() {
    return LyricsLine(
      timestamp: timestamp,
      originalText: originalText,
      annotatedTexts: annotatedTexts
          .map((text) => (text as AnnotatedTextModel).toEntity())
          .toList(),
    );
  }

  LyricsLineModel copyWith({
    Duration? timestamp,
    String? originalText,
    List<AnnotatedText>? annotatedTexts,
  }) {
    return LyricsLineModel(
      timestamp: timestamp ?? this.timestamp,
      originalText: originalText ?? this.originalText,
      annotatedTexts: annotatedTexts ?? this.annotatedTexts,
    );
  }
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