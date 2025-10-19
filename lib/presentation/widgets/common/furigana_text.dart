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
    this.annotationSpacing = 1.0,
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
          fontSize: math.max(6.0, (effectiveBaseStyle.fontSize ?? 16.0) * 0.35),
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

    final StringBuffer buffer = StringBuffer();
    final List<_AnnotatedSegment> annotatedSegments = [];

    for (final AnnotatedText segment in segments) {
      if (segment.original.isEmpty) continue;
      final int start = buffer.length;
      buffer.write(segment.original);

      if (_shouldRenderAnnotation(segment)) {
        annotatedSegments.add(
          _AnnotatedSegment(
            start: start,
            end: start + segment.original.length,
            annotation: segment.annotation.trim(),
          ),
        );
      }
    }

    if (annotatedSegments.isEmpty) {
      return Text(
        buffer.toString(),
        style: effectiveBaseStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: softWrap,
        strutStyle: strutStyle,
      );
    }

    return _FuriganaParagraph(
      text: buffer.toString(),
      annotatedSegments: annotatedSegments,
      baseStyle: effectiveBaseStyle,
      annotationStyle: effectiveAnnotationStyle,
      textAlign: textAlign,
      softWrap: softWrap,
      maxLines: maxLines,
      strutStyle: strutStyle,
      spacing: annotationSpacing,
    );
  }

  bool _shouldRenderAnnotation(AnnotatedText segment) {
    final String annotation = segment.annotation.trim();
    final String original = segment.original.trim();
    if (annotation.isEmpty || original.isEmpty) return false;
    if (annotation == original) return false;
    if (segment.type == TextType.other) return false;
    return true;
  }
}

class _FuriganaParagraph extends LeafRenderObjectWidget {
  const _FuriganaParagraph({
    required this.text,
    required this.annotatedSegments,
    required this.baseStyle,
    required this.annotationStyle,
    required this.textAlign,
    required this.softWrap,
    required this.maxLines,
    required this.strutStyle,
    required this.spacing,
  });

  final String text;
  final List<_AnnotatedSegment> annotatedSegments;
  final TextStyle baseStyle;
  final TextStyle annotationStyle;
  final TextAlign textAlign;
  final bool softWrap;
  final int? maxLines;
  final StrutStyle? strutStyle;
  final double spacing;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _FuriganaParagraphRenderBox(
      text: text,
      annotatedSegments: annotatedSegments,
      baseStyle: baseStyle,
      annotationStyle: annotationStyle,
      textAlign: textAlign,
      softWrap: softWrap,
      maxLines: maxLines,
      strutStyle: strutStyle,
      spacing: spacing,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _FuriganaParagraphRenderBox renderObject,
  ) {
    renderObject
      ..text = text
      ..annotatedSegments = annotatedSegments
      ..baseStyle = baseStyle
      ..annotationStyle = annotationStyle
      ..textAlign = textAlign
      ..softWrap = softWrap
      ..maxLines = maxLines
      ..strutStyle = strutStyle
      ..spacing = spacing
      ..textDirection = Directionality.of(context);
  }
}

class _FuriganaParagraphRenderBox extends RenderBox {
  _FuriganaParagraphRenderBox({
    required String text,
    required List<_AnnotatedSegment> annotatedSegments,
    required TextStyle baseStyle,
    required TextStyle annotationStyle,
    required TextAlign textAlign,
    required bool softWrap,
    required int? maxLines,
    required StrutStyle? strutStyle,
    required double spacing,
    required TextDirection textDirection,
  }) : _text = text,
       _annotatedSegments = annotatedSegments,
       _baseStyle = baseStyle,
       _annotationStyle = annotationStyle,
       _textAlign = textAlign,
       _softWrap = softWrap,
       _maxLines = maxLines,
       _strutStyle = strutStyle,
       _spacing = spacing,
       _textDirection = textDirection;

  String _text;
  List<_AnnotatedSegment> _annotatedSegments;
  TextStyle _baseStyle;
  TextStyle _annotationStyle;
  TextAlign _textAlign;
  bool _softWrap;
  int? _maxLines;
  StrutStyle? _strutStyle;
  double _spacing;
  TextDirection _textDirection;

  final TextPainter _basePainter = TextPainter();
  final TextPainter _rubyPainter = TextPainter();

  set text(String value) {
    if (_text == value) return;
    _text = value;
    markNeedsLayout();
  }

  set annotatedSegments(List<_AnnotatedSegment> value) {
    _annotatedSegments = value;
    markNeedsLayout();
  }

  set baseStyle(TextStyle value) {
    if (_baseStyle == value) return;
    _baseStyle = value;
    markNeedsLayout();
  }

  set annotationStyle(TextStyle value) {
    if (_annotationStyle == value) return;
    _annotationStyle = value;
    markNeedsLayout();
  }

  set textAlign(TextAlign value) {
    if (_textAlign == value) return;
    _textAlign = value;
    markNeedsLayout();
  }

  set softWrap(bool value) {
    if (_softWrap == value) return;
    _softWrap = value;
    markNeedsLayout();
  }

  set maxLines(int? value) {
    if (_maxLines == value) return;
    _maxLines = value;
    markNeedsLayout();
  }

  set strutStyle(StrutStyle? value) {
    if (_strutStyle == value) return;
    _strutStyle = value;
    markNeedsLayout();
  }

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsPaint();
  }

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  void _layoutBasePainter(double maxWidth) {
    final int? effectiveMaxLines = _softWrap ? _maxLines : (_maxLines ?? 1);
    _basePainter
      ..text = TextSpan(text: _text, style: _baseStyle)
      ..textAlign = _textAlign
      ..textDirection = _textDirection
      ..strutStyle = _strutStyle
      ..maxLines = effectiveMaxLines
      ..ellipsis = _softWrap ? null : ''
      ..layout(minWidth: 0, maxWidth: maxWidth);
  }

  @override
  void performLayout() {
    final double maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : double.infinity;
    _layoutBasePainter(maxWidth);
    size = constraints.constrain(_basePainter.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : double.infinity;
    _layoutBasePainter(maxWidth);
    return constraints.constrain(_basePainter.size);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return _basePainter.computeDistanceToActualBaseline(baseline);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;

    final double maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : double.infinity;
    _layoutBasePainter(maxWidth);
    _basePainter.paint(canvas, offset);

    for (final segment in _annotatedSegments) {
      if (segment.start >= segment.end) continue;
      final boxes = _basePainter.getBoxesForSelection(
        TextSelection(baseOffset: segment.start, extentOffset: segment.end),
      );
      if (boxes.isEmpty) continue;

      final TextBox box = boxes.first;
      _rubyPainter
        ..text = TextSpan(text: segment.annotation, style: _annotationStyle)
        ..textDirection = _textDirection
        ..textAlign = TextAlign.center
        ..layout();

      final double rubyWidth = _rubyPainter.width;
      final double rubyX = offset.dx + (box.left + box.right - rubyWidth) / 2;
      final double rubyY = offset.dy + box.top - _rubyPainter.height - _spacing;

      _rubyPainter.paint(canvas, Offset(rubyX, rubyY));
    }
  }

  @override
  void detach() {
    _basePainter.dispose();
    _rubyPainter.dispose();
    super.detach();
  }
}

class _AnnotatedSegment {
  const _AnnotatedSegment({
    required this.start,
    required this.end,
    required this.annotation,
  });

  final int start;
  final int end;
  final String annotation;
}
