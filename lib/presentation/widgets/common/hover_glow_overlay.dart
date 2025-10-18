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

class _HoverGlowOverlayState extends State<HoverGlowOverlay> {
  final GlobalKey _containerKey = GlobalKey();
  Alignment _glowAlignment = Alignment.center;
  bool _hovering = false;
  Size _lastSize = Size.zero;

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

  void _handleEnter(PointerEnterEvent event) {
    _updateAlignment(event.localPosition);
    setState(() {
      _hovering = true;
    });
  }

  void _handleHover(PointerHoverEvent event) {
    _updateAlignment(event.localPosition);
  }

  void _handleExit(PointerExitEvent event) {
    setState(() {
      _hovering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final glowBaseColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.18)
        : Colors.white.withOpacity(0.35);

    final cursor = widget.cursor ?? SystemMouseCursors.basic;
    final blurSigma = widget.blurSigma;

    Widget layeredChild = Stack(
      key: _containerKey,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              opacity: _hovering ? widget.glowOpacity : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: _glowAlignment,
                    radius: widget.glowRadius,
                    colors: [
                      glowBaseColor,
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
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
      onEnter: _handleEnter,
      onHover: _handleHover,
      onExit: _handleExit,
      child: layeredChild,
    );
  }
}
