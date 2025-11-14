import 'package:flutter/material.dart';

/// 通用的播放控制按钮，桌面/移动端共用，保证交互与样式一致。
class PlayerTransportButton extends StatefulWidget {
  const PlayerTransportButton({
    super.key,
    required this.iconBuilder,
    required this.onPressed,
    required this.enabled,
    required this.baseColor,
    required this.hoverColor,
    this.dimWhenDisabled = true,
    this.tooltip,
    this.padding = const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
  });

  final Widget Function(Color color) iconBuilder;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color baseColor;
  final Color hoverColor;
  final bool dimWhenDisabled;
  final String? tooltip;
  final EdgeInsets padding;

  @override
  State<PlayerTransportButton> createState() => _PlayerTransportButtonState();
}

class _PlayerTransportButtonState extends State<PlayerTransportButton> {
  bool _hovering = false;
  bool _pressing = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  void _setHovering(bool value) {
    if (!_enabled) return;
    setState(() => _hovering = value);
  }

  void _setPressing(bool value) {
    if (!_enabled) return;
    setState(() => _pressing = value);
  }

  @override
  Widget build(BuildContext context) {
    final Color targetColor;
    if (!_enabled) {
      targetColor = widget.dimWhenDisabled
          ? widget.baseColor.withOpacity(0.45)
          : widget.baseColor;
    } else if (_hovering) {
      targetColor = widget.hoverColor;
    } else {
      targetColor = widget.baseColor;
    }

    const hoverScale = 1.05;
    const pressScale = 0.95;
    final scale = !_enabled
        ? 1.0
        : _pressing
        ? pressScale
        : (_hovering ? hoverScale : 1.0);

    final icon = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 140),
      curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
      child: widget.iconBuilder(targetColor),
    );

    final interactive = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHovering(true),
      onExit: (_) {
        _setHovering(false);
        _setPressing(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _enabled ? widget.onPressed : null,
        onTapDown: _enabled ? (_) => _setPressing(true) : null,
        onTapUp: _enabled ? (_) => _setPressing(false) : null,
        onTapCancel: _enabled ? () => _setPressing(false) : null,
        child: Padding(
          padding: widget.padding,
          child: Center(child: icon),
        ),
      ),
    );

    if (widget.tooltip == null || widget.tooltip!.isEmpty) {
      return interactive;
    }

    return Tooltip(message: widget.tooltip!, child: interactive);
  }
}
