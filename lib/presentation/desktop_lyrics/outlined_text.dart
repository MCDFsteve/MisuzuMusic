import 'package:flutter/material.dart';

import '../../domain/entities/lyrics_entities.dart';
import '../widgets/common/furigana_text.dart';

class OutlinedText extends StatelessWidget {
  const OutlinedText({
    super.key,
    required this.text,
    required this.fillStyle,
    required this.strokeColor,
    this.strokeWidth = 2.2,
    this.textAlign = TextAlign.center,
    this.maxLines,
    this.softWrap = true,
    this.strutStyle,
  });

  final String text;
  final TextStyle fillStyle;
  final Color strokeColor;
  final double strokeWidth;
  final TextAlign textAlign;
  final int? maxLines;
  final bool softWrap;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor
      ..strokeJoin = StrokeJoin.round;

    final strokeStyle = fillStyle.copyWith(
      foreground: strokePaint,
      color: null,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          softWrap: softWrap,
          locale: const Locale('zh', 'Hans'),
          strutStyle: strutStyle,
          style: strokeStyle,
        ),
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          softWrap: softWrap,
          locale: const Locale('zh', 'Hans'),
          strutStyle: strutStyle,
          style: fillStyle,
        ),
      ],
    );
  }
}

class OutlinedFuriganaText extends StatelessWidget {
  const OutlinedFuriganaText({
    super.key,
    required this.segments,
    required this.baseStyle,
    required this.annotationStyle,
    required this.strokeColor,
    this.strokeWidth = 2.2,
    this.textAlign = TextAlign.center,
    this.maxLines,
    this.softWrap = true,
    this.strutStyle,
    this.annotationSpacing = -2.0,
  });

  final List<AnnotatedText> segments;
  final TextStyle baseStyle;
  final TextStyle annotationStyle;
  final Color strokeColor;
  final double strokeWidth;
  final TextAlign textAlign;
  final int? maxLines;
  final bool softWrap;
  final StrutStyle? strutStyle;
  final double annotationSpacing;

  @override
  Widget build(BuildContext context) {
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor
      ..strokeJoin = StrokeJoin.round;

    final annotationStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.72
      ..color = strokeColor
      ..strokeJoin = StrokeJoin.round;

    final strokeBaseStyle = baseStyle.copyWith(
      foreground: strokePaint,
      color: null,
    );
    final strokeAnnotationStyle = annotationStyle.copyWith(
      foreground: annotationStrokePaint,
      color: null,
    );

    return Stack(
      children: [
        FuriganaText(
          segments: segments,
          baseStyle: strokeBaseStyle,
          annotationStyle: strokeAnnotationStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          softWrap: softWrap,
          strutStyle: strutStyle,
          annotationSpacing: annotationSpacing,
        ),
        FuriganaText(
          segments: segments,
          baseStyle: baseStyle,
          annotationStyle: annotationStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          softWrap: softWrap,
          strutStyle: strutStyle,
          annotationSpacing: annotationSpacing,
        ),
      ],
    );
  }
}
