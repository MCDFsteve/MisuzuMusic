import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 高分辨率歌词行位图渲染结果。
class RenderedLyricsLine {
  RenderedLyricsLine({
    required this.image,
    required this.logicalSize,
    required this.pixelRatio,
  });

  final ui.Image image;
  final Size logicalSize;
  final double pixelRatio;
}

/// 渲染参数。
class LyricsImageRenderConfig {
  const LyricsImageRenderConfig({
    required this.maxWidth,
    required this.pixelRatio,
    required this.style,
  });

  final double maxWidth;
  final double pixelRatio;
  final TextStyle style;
}

/// 简单的内存缓存，避免重复生成位图。
class LyricsLineImageCache {
  LyricsLineImageCache._();

  static final LyricsLineImageCache instance = LyricsLineImageCache._();

  final Map<_LyricsImageKey, Future<RenderedLyricsLine>> _cache = {};

  Future<RenderedLyricsLine> resolve({
    required String text,
    required LyricsImageRenderConfig config,
  }) {
    final key = _LyricsImageKey(
      text: text,
      maxWidth: config.maxWidth,
      pixelRatio: config.pixelRatio,
      style: config.style,
    );

    return _cache.putIfAbsent(key, () => _render(text, config));
  }

  Future<RenderedLyricsLine> _render(
    String text,
    LyricsImageRenderConfig config,
  ) async {
    final style = config.style.copyWith(color: Colors.white);
    final double maxWidth = config.maxWidth.isFinite && config.maxWidth > 0
        ? config.maxWidth
        : 540.0;

    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: maxWidth);

    final double logicalWidth = painter.width;
    final double logicalHeight = painter.height;
    final double pixelRatio = config.pixelRatio;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double dx = (maxWidth - logicalWidth) * 0.5;
    if (dx > 0) {
      canvas.translate(dx, 0);
    }
    canvas.scale(pixelRatio);
    painter.paint(canvas, Offset.zero);

    final ui.Picture picture = recorder.endRecording();
    final int width = (maxWidth * pixelRatio).ceil();
    final int height = (logicalHeight * pixelRatio).ceil();
    final ui.Image image = await picture.toImage(width, height);

    return RenderedLyricsLine(
      image: image,
      logicalSize: Size(maxWidth, logicalHeight),
      pixelRatio: pixelRatio,
    );
  }
}

class _LyricsImageKey {
  _LyricsImageKey({
    required this.text,
    required this.maxWidth,
    required this.pixelRatio,
    required TextStyle style,
  }) : fontFamily = style.fontFamily,
       fontSize = style.fontSize ?? 14,
       fontWeight = style.fontWeight ?? FontWeight.w400,
       height = style.height,
       letterSpacing = style.letterSpacing,
       wordSpacing = style.wordSpacing,
       fontStyle = style.fontStyle ?? FontStyle.normal,
       decoration = style.decoration;

  final String text;
  final double maxWidth;
  final double pixelRatio;
  final String? fontFamily;
  final double fontSize;
  final FontWeight fontWeight;
  final double? height;
  final double? letterSpacing;
  final double? wordSpacing;
  final FontStyle fontStyle;
  final TextDecoration? decoration;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _LyricsImageKey &&
        text == other.text &&
        maxWidth == other.maxWidth &&
        pixelRatio == other.pixelRatio &&
        fontFamily == other.fontFamily &&
        fontSize == other.fontSize &&
        fontWeight == other.fontWeight &&
        height == other.height &&
        letterSpacing == other.letterSpacing &&
        wordSpacing == other.wordSpacing &&
        fontStyle == other.fontStyle &&
        decoration == other.decoration;
  }

  @override
  int get hashCode => Object.hash(
    text,
    maxWidth,
    pixelRatio,
    fontFamily,
    fontSize,
    fontWeight,
    height,
    letterSpacing,
    wordSpacing,
    fontStyle,
    decoration,
  );
}
