import 'dart:async';

import 'package:flutter/material.dart';

/// 通用自定义滚动条包装器，用于确保浅色模式下的滚动条保持足够的对比度。
/// 提供一个 builder 以便复用相同的 [ScrollController]。
class AdaptiveScrollbar extends StatefulWidget {
  const AdaptiveScrollbar({
    super.key,
    required this.builder,
    required this.isDarkMode,
    this.controller,
    this.margin = EdgeInsets.zero,
    this.trackRadius = const Radius.circular(3),
    this.thumbWidth = 6,
    this.minThumbExtent = 36,
  });

  final Widget Function(ScrollController controller) builder;
  final bool isDarkMode;
  final ScrollController? controller;
  final EdgeInsets margin;
  final Radius trackRadius;
  final double thumbWidth;
  final double minThumbExtent;

  @override
  State<AdaptiveScrollbar> createState() => _AdaptiveScrollbarState();
}

class _AdaptiveScrollbarState extends State<AdaptiveScrollbar> {
  late ScrollController _controller;
  late bool _ownsController;

  double _thumbOffset = 0;
  double _thumbExtent = 0;
  bool _isScrollable = false;
  bool _isRailVisible = false;
  bool _isHovering = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initController(widget.controller);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateThumb(force: true));
  }

  @override
  void didUpdateWidget(covariant AdaptiveScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_scheduleUpdate);
      if (_ownsController) {
        _controller.dispose();
      }
      _initController(widget.controller);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateThumb(force: true));
    } else if (oldWidget.isDarkMode != widget.isDarkMode) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_scheduleUpdate);
    if (_ownsController) {
      _controller.dispose();
    }
    _hideTimer?.cancel();
    super.dispose();
  }

  void _initController(ScrollController? controller) {
    _controller = controller ?? ScrollController();
    _ownsController = controller == null;
    _controller.addListener(_scheduleUpdate);
  }

  void _scheduleUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateThumb());
  }

  void _updateThumb({bool force = false}) {
    if (!_controller.hasClients) {
      if (_isScrollable || force) {
        setState(() {
          _isScrollable = false;
          _thumbExtent = 0;
          _thumbOffset = 0;
        });
      }
      return;
    }

    final position = _controller.position;
    final maxScrollExtent = position.maxScrollExtent;
    final viewportExtent = position.viewportDimension;

    if (viewportExtent <= 0) {
      if (_isScrollable || force) {
        setState(() {
          _isScrollable = false;
          _thumbExtent = 0;
          _thumbOffset = 0;
          _isRailVisible = false;
        });
        _hideTimer?.cancel();
      }
      return;
    }

    if (maxScrollExtent <= 0) {
      if (_isScrollable || force) {
        setState(() {
          _isScrollable = false;
          _thumbExtent = viewportExtent;
          _thumbOffset = 0;
          _isRailVisible = false;
        });
        _hideTimer?.cancel();
      }
      return;
    }

    final totalExtent = viewportExtent + maxScrollExtent;
    final visibleFraction = (viewportExtent / totalExtent).clamp(0.0, 1.0);
    final double minThumbExtent = widget.minThumbExtent;
    final double clampedMin = minThumbExtent <= viewportExtent
        ? minThumbExtent
        : viewportExtent;
    final thumbExtent = (visibleFraction * viewportExtent)
        .clamp(clampedMin, viewportExtent);
    final scrollFraction = (position.pixels / maxScrollExtent).clamp(0.0, 1.0);
    final thumbOffset = scrollFraction * (viewportExtent - thumbExtent);

    setState(() {
      _isScrollable = true;
      _thumbExtent = thumbExtent;
      _thumbOffset = thumbOffset;
      _isRailVisible = true;
    });
    _restartHideTimer();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        notification is ScrollMetricsNotification ||
        notification is ScrollEndNotification) {
      _scheduleUpdate();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final thumbColor = widget.isDarkMode ? Colors.white : Colors.black;
    final trackColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.2);
    final railWidth = widget.thumbWidth * (_isHovering ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - widget.margin.vertical
            : MediaQuery.of(context).size.height - widget.margin.vertical;
        final trackExtent = availableHeight > 0 ? availableHeight : 0.0;

        final baseBehavior = ScrollConfiguration.of(context);
        final behaviorWithHiddenScrollbar =
            baseBehavior.copyWith(scrollbars: false);

        final content = NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ScrollConfiguration(
            behavior: behaviorWithHiddenScrollbar,
            child: widget.builder(_controller),
          ),
        );

        final showRail = _isScrollable && (_isRailVisible || _isHovering);

        return Stack(
          children: [
            content,
            if (_isScrollable)
              Positioned(
                right: widget.margin.right,
                top: widget.margin.top,
                bottom: widget.margin.bottom,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: showRail ? 1 : 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => _setHovering(true),
                    onExit: (_) => _setHovering(false),
                    child: _ScrollbarRail(
                      height: trackExtent,
                      width: railWidth,
                      trackRadius: widget.trackRadius,
                      trackColor: trackColor,
                      thumbColor: thumbColor,
                      thumbExtent: _thumbExtent.clamp(0, availableHeight),
                      thumbOffset: _thumbOffset,
                      onDragTo: (dy) => _jumpToPosition(dy, trackExtent),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _jumpToPosition(double dy, double trackExtent) {
    if (!_controller.hasClients) {
      return;
    }

    final maxScroll = _controller.position.maxScrollExtent;
    if (maxScroll <= 0 || trackExtent <= 0) {
      return;
    }

    final effectiveRange = (trackExtent - _thumbExtent).clamp(0.0, double.infinity);
    final clampedDy = (dy - (_thumbExtent / 2)).clamp(0.0, effectiveRange);
    final fraction = effectiveRange == 0 ? 0 : (clampedDy / effectiveRange);
    final target = fraction * maxScroll;
    _controller.jumpTo(target);
  }

  void _setHovering(bool value) {
    if (_isHovering == value) {
      return;
    }
    setState(() {
      _isHovering = value;
      if (value) {
        _isRailVisible = true;
      }
    });
    if (value) {
      _hideTimer?.cancel();
    } else {
      _restartHideTimer();
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    if (!_isScrollable) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || _isHovering) {
        return;
      }
      setState(() {
        _isRailVisible = false;
      });
    });
  }
}

class _ScrollbarRail extends StatelessWidget {
  const _ScrollbarRail({
    required this.height,
    required this.width,
    required this.trackRadius,
    required this.trackColor,
    required this.thumbColor,
    required this.thumbExtent,
    required this.thumbOffset,
    required this.onDragTo,
  });

  final double height;
  final double width;
  final Radius trackRadius;
  final Color trackColor;
  final Color thumbColor;
  final double thumbExtent;
  final double thumbOffset;
  final ValueChanged<double> onDragTo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => onDragTo(details.localPosition.dy),
      onVerticalDragStart: (details) => onDragTo(details.localPosition.dy),
      onVerticalDragUpdate: (details) => onDragTo(details.localPosition.dy),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.all(trackRadius),
                ),
              ),
            ),
            Positioned(
              top: thumbOffset.clamp(0, height - thumbExtent),
              child: Container(
                width: width,
                height: thumbExtent,
                decoration: BoxDecoration(
                  color: thumbColor,
                  borderRadius: BorderRadius.all(trackRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
