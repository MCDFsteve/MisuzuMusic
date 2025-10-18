import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class HoverShift extends StatefulWidget {
  const HoverShift({
    super.key,
    required this.child,
    this.distance = 12,
    this.duration = const Duration(milliseconds: 120),
    this.curve = Curves.easeOutCubic,
    this.enabled,
  });

  final Widget child;
  final double distance;
  final Duration duration;
  final Curve curve;
  final bool? enabled;

  @override
  State<HoverShift> createState() => _HoverShiftState();
}

class _HoverShiftState extends State<HoverShift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  bool get _pointerEnabled {
    if (widget.enabled != null) {
      return widget.enabled!;
    }
    final platform = defaultTargetPlatform;
    switch (platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return kIsWeb;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
  }

  @override
  void didUpdateWidget(covariant HoverShift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _animation = CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      );
    }
    if (!_pointerEnabled) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enableHover = _pointerEnabled;

    return MouseRegion(
      onEnter: enableHover ? (_) => _controller.forward() : null,
      onExit: enableHover ? (_) => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final shift = _animation.value * widget.distance;
          return Transform.translate(
            offset: Offset(shift, 0),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
