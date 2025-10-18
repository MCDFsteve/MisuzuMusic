import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HoverGlowOverlay extends StatefulWidget {
  const HoverGlowOverlay({
    super.key,
    required this.child,
    required this.isDarkMode,
    this.borderRadius = BorderRadius.zero,
    this.cursor,
    this.glowRadius = 0.9,
    this.glowOpacity = 1.0,
    this.blurSigma,
  });

  final Widget child;
  final bool isDarkMode;
  final BorderRadius borderRadius;
  final MouseCursor? cursor;
  final double glowRadius;
  final double glowOpacity;
  final double? blurSigma;

  @override
  State<HoverGlowOverlay> createState() => _HoverGlowOverlayState();
}

class _HoverGlowOverlayState extends State<HoverGlowOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _containerKey = GlobalKey();
  Alignment _glowAlignment = Alignment.center;
  bool _hovering = false;
  Size _lastSize = Size.zero;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateAlignment(Offset localPosition) {
    final renderBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      _lastSize = renderBox.size;
    }

    final width = _lastSize.width;
    final height = _lastSize.height;
    if (width <= 0 || height <= 0) {
      return;
    }

    final dx = (localPosition.dx / width).clamp(0.0, 1.0);
    final dy = (localPosition.dy / height).clamp(0.0, 1.0);
    setState(() {
      _glowAlignment = Alignment(dx * 2 - 1, dy * 2 - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseOpacity = widget.isDarkMode ? 0.28 : 0.6;
    final glowColor = Colors.white;

    final cursor = widget.cursor ?? SystemMouseCursors.basic;
    final blurSigma = widget.blurSigma;

    Widget layeredChild = Stack(
      key: _containerKey,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = _controller.value * widget.glowOpacity;
                return CustomPaint(
                  painter: _GlowPainter(
                    alignment: _glowAlignment,
                    color: glowColor,
                    baseOpacity: baseOpacity,
                    progress: progress,
                    radiusFactor: widget.glowRadius,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

    if (blurSigma != null && blurSigma > 0) {
      layeredChild = ClipRRect(
        borderRadius: widget.borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: layeredChild,
        ),
      );
    } else {
      layeredChild = ClipRRect(
        borderRadius: widget.borderRadius,
        child: layeredChild,
      );
    }

    return MouseRegion(
      cursor: cursor,
      onEnter: (event) {
        _updateAlignment(event.localPosition);
        setState(() {
          _hovering = true;
        });
        _controller.forward();
      },
      onHover: (event) {
        _updateAlignment(event.localPosition);
      },
      onExit: (event) {
        setState(() {
          _hovering = false;
        });
        _controller.reverse();
      },
      child: layeredChild,
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.alignment,
    required this.color,
    required this.baseOpacity,
    required this.progress,
    required this.radiusFactor,
  });

  final Alignment alignment;
  final Color color;
  final double baseOpacity;
  final double progress;
  final double radiusFactor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final center = Offset(
      (alignment.x + 1) / 2 * size.width,
      (alignment.y + 1) / 2 * size.height,
    );

    final radius = size.shortestSide * radiusFactor;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withOpacity(baseOpacity * progress),
          color.withOpacity((baseOpacity * 0.2) * progress),
          Colors.transparent,
        ],
        [0.0, 0.55, 1.0],
      )
      ..blendMode = BlendMode.plus;

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) {
    return alignment != oldDelegate.alignment ||
        color != oldDelegate.color ||
        baseOpacity != oldDelegate.baseOpacity ||
        progress != oldDelegate.progress ||
        radiusFactor != oldDelegate.radiusFactor;
  }
}
