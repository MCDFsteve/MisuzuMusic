import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/lyrics_entities.dart';

class FuriganaText extends StatelessWidget {
  const FuriganaText({
    super.key,
    required this.segments,
    this.baseStyle,
    this.annotationStyle,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.softWrap = true,
    this.strutStyle,
    this.annotationSpacing = 0.0,
  });

  final List<AnnotatedText> segments;
  final TextStyle? baseStyle;
  final TextStyle? annotationStyle;
  final TextAlign textAlign;
  final int? maxLines;
  final bool softWrap;
  final StrutStyle? strutStyle;
  final double annotationSpacing;

  @override
  Widget build(BuildContext context) {
    final TextStyle effectiveBaseStyle =
        baseStyle ?? DefaultTextStyle.of(context).style;
    final TextStyle effectiveAnnotationStyle =
        annotationStyle ??
        effectiveBaseStyle.copyWith(
          fontSize: (effectiveBaseStyle.fontSize ?? 16.0) * 0.4,
          fontWeight: FontWeight.w500,
          height: 1.0,
        );

    if (segments.isEmpty) {
      return Text(
        '',
        style: effectiveBaseStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: softWrap,
        strutStyle: strutStyle,
      );
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    for (final AnnotatedText segment in segments) {
      if (segment.original.isEmpty) {
        continue;
      }

      final bool renderAnnotation = _shouldRenderAnnotation(segment);
      if (!renderAnnotation) {
        spans.add(TextSpan(text: segment.original));
        continue;
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.ideographic,
          child: _RubySegment(
            baseText: segment.original,
            rubyText: segment.annotation.trim(),
            baseStyle: effectiveBaseStyle,
            annotationStyle: effectiveAnnotationStyle,
            spacing: annotationSpacing,
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      return Text(
        segments.map((e) => e.original).join(),
        style: effectiveBaseStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: softWrap,
        strutStyle: strutStyle,
      );
    }

    return RichText(
      textAlign: textAlign,
      softWrap: softWrap,
      maxLines: maxLines,
      overflow: TextOverflow.visible,
      strutStyle: strutStyle,
      text: TextSpan(style: effectiveBaseStyle, children: spans),
    );
  }

  bool _shouldRenderAnnotation(AnnotatedText segment) {
    final String annotation = segment.annotation.trim();
    if (annotation.isEmpty) {
      return false;
    }
    final String original = segment.original.trim();
    if (original.isEmpty) {
      return false;
    }
    if (annotation == original) {
      return false;
    }
    if (segment.type == TextType.other) {
      return false;
    }
    return true;
  }
}

class _RubySegment extends StatelessWidget {
  const _RubySegment({
    required this.baseText,
    required this.rubyText,
    required this.baseStyle,
    required this.annotationStyle,
    required this.spacing,
  });

  final String baseText;
  final String rubyText;
  final TextStyle baseStyle;
  final TextStyle annotationStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;

    final basePainter = TextPainter(
      text: TextSpan(text: baseText, style: baseStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();

    final annotationPainter = TextPainter(
      text: TextSpan(text: rubyText, style: annotationStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();

    final double width = math.max(basePainter.width, annotationPainter.width);
    final double baseHeight = basePainter.height;
    final double lift = (annotationStyle.fontSize ?? 10.0) * 0.35 + spacing;

    return SizedBox(
      width: width,
      height: baseHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            width: width,
            child: Text(
              baseText,
              style: baseStyle,
              textAlign: TextAlign.center,
              softWrap: false,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: baseHeight + lift,
            child: SizedBox(
              width: width,
              child: Text(
                rubyText,
                style: annotationStyle,
                textAlign: TextAlign.center,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
