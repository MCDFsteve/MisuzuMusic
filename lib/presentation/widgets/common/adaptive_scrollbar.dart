import 'package:flutter/material.dart';

/// 通用自定义滚动条包装器，用于确保浅色模式下的滚动条保持足够的对比度。
/// 提供一个 builder 以便复用相同的 [ScrollController]。
class AdaptiveScrollbar extends StatefulWidget {
  const AdaptiveScrollbar({
    super.key,
    required this.builder,
    required this.isDarkMode,
    this.controller,
    this.margin = const EdgeInsets.only(right: 10),
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

    if (maxScrollExtent <= 0) {
      if (_isScrollable || force) {
        setState(() {
          _isScrollable = false;
          _thumbExtent = viewportExtent;
          _thumbOffset = 0;
        });
      }
      return;
    }

    final totalExtent = viewportExtent + maxScrollExtent;
    final visibleFraction = (viewportExtent / totalExtent).clamp(0.0, 1.0);
    final thumbExtent = (visibleFraction * viewportExtent)
        .clamp(widget.minThumbExtent, viewportExtent);
    final scrollFraction = (position.pixels / maxScrollExtent).clamp(0.0, 1.0);
    final thumbOffset = scrollFraction * (viewportExtent - thumbExtent);

    setState(() {
      _isScrollable = true;
      _thumbExtent = thumbExtent;
      _thumbOffset = thumbOffset;
    });
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - widget.margin.vertical
            : MediaQuery.of(context).size.height - widget.margin.vertical;

        final content = NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: widget.builder(_controller),
        );

        return Stack(
          children: [
            content,
            if (_isScrollable)
              Positioned(
                right: widget.margin.right,
                top: widget.margin.top,
                bottom: widget.margin.bottom,
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    width: widget.thumbWidth,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.all(widget.trackRadius),
                    ),
                  ),
                ),
              ),
            if (_isScrollable)
              Positioned(
                right: widget.margin.right,
                top: widget.margin.top + _thumbOffset,
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    width: widget.thumbWidth,
                    height: _thumbExtent.clamp(0, availableHeight),
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.all(widget.trackRadius),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
