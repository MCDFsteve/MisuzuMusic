import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

// Annotated text for Japanese lyrics
class AnnotatedText extends Equatable {
  final String original;     // Original text (kanji/katakana)
  final String annotation;   // Furigana annotation
  final TextType type;       // Type of text

  const AnnotatedText({
    required this.original,
    required this.annotation,
    required this.type,
  });

  @override
  List<Object> get props => [original, annotation, type];
}

// Lyrics line with timestamp
class LyricsLine extends Equatable {
  final Duration timestamp;
  final String originalText;
  final String? translatedText;
  final List<AnnotatedText> annotatedTexts;

  const LyricsLine({
    required this.timestamp,
    required this.originalText,
    this.translatedText,
    required this.annotatedTexts,
  });

  @override
  List<Object?> get props => [
        timestamp,
        originalText,
        translatedText,
        annotatedTexts,
      ];
}

// Complete lyrics for a track
class Lyrics extends Equatable {
  final String trackId;
  final List<LyricsLine> lines;
  final LyricsFormat format;
  final LyricsSource source;

  const Lyrics({
    required this.trackId,
    required this.lines,
    required this.format,
    this.source = LyricsSource.unknown,
  });

  @override
  List<Object> get props => [trackId, lines, format, source];
}

enum LyricsFormat {
  lrc,    // LRC format with timestamps
  text,   // Plain text
}

enum LyricsSource {
  nipaplay,   // From nipaplay.aimes-soft.com server
  netease,    // From Netease Cloud Music
  local,      // From local file
  embedded,   // From embedded audio metadata
  cached,     // From cache
  unknown,    // Unknown source
}

// Lyrics display settings
class LyricsSettings extends Equatable {
  final bool showAnnotation;
  final double annotationFontSize;
  final double textFontSize;
  final bool autoScroll;

  const LyricsSettings({
    this.showAnnotation = true,
    this.annotationFontSize = 14.0,
    this.textFontSize = 18.0,
    this.autoScroll = true,
  });

  @override
  List<Object> get props => [
        showAnnotation,
        annotationFontSize,
        textFontSize,
        autoScroll,
      ];

  LyricsSettings copyWith({
    bool? showAnnotation,
    double? annotationFontSize,
    double? textFontSize,
    bool? autoScroll,
  }) {
    return LyricsSettings(
      showAnnotation: showAnnotation ?? this.showAnnotation,
      annotationFontSize: annotationFontSize ?? this.annotationFontSize,
      textFontSize: textFontSize ?? this.textFontSize,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }
}
