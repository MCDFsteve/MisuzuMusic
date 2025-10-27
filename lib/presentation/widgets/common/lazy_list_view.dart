import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 通用懒加载列表组件，通过逐步扩展可见项目数来减少一次性渲染压力。
typedef LazyListItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

class LazyListView<T> extends StatefulWidget {
  const LazyListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.separatorBuilder,
    this.controller,
    this.pageSize = 80,
    this.preloadOffset = 600,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.primary,
    this.cacheExtent,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.emptyBuilder,
  });

  final List<T> items;
  final LazyListItemBuilder<T> itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final ScrollController? controller;
  final int pageSize;
  final double preloadOffset;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool? primary;
  final double? cacheExtent;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final WidgetBuilder? emptyBuilder;

  @override
  State<LazyListView<T>> createState() => _LazyListViewState<T>();
}

class _LazyListViewState<T> extends State<LazyListView<T>> {
  late ScrollController _controller;
  late bool _ownsController;
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _initController(widget.controller);
    _visibleCount = _initialVisibleCount(widget.items.length);
  }

  @override
  void didUpdateWidget(covariant LazyListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller.removeListener(_handleScroll);
      if (_ownsController) {
        _controller.dispose();
      }
      _initController(widget.controller);
    }

    final total = widget.items.length;
    final int minimum = _initialVisibleCount(total);
    int nextVisibleCount = _visibleCount.clamp(0, total);

    if (nextVisibleCount < minimum) {
      nextVisibleCount = minimum;
    }

    if (oldWidget.pageSize != widget.pageSize && nextVisibleCount < minimum) {
      nextVisibleCount = minimum;
    }

    if (nextVisibleCount != _visibleCount) {
      setState(() => _visibleCount = nextVisibleCount);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _initController(ScrollController? external) {
    _controller = external ?? ScrollController();
    _ownsController = external == null;
    _controller.addListener(_handleScroll);
  }

  int _initialVisibleCount(int total) {
    if (total == 0) {
      return 0;
    }
    final effectivePageSize = math.max(1, widget.pageSize);
    return math.min(effectivePageSize, total);
  }

  void _handleScroll() {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    if (position.pixels + widget.preloadOffset >= position.maxScrollExtent) {
      _growVisibleWindow();
    }
  }

  void _growVisibleWindow() {
    final total = widget.items.length;
    if (_visibleCount >= total) {
      return;
    }
    final step = math.max(1, widget.pageSize);
    final next = math.min(_visibleCount + step, total);
    if (next != _visibleCount) {
      setState(() => _visibleCount = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      final builder = widget.emptyBuilder;
      if (builder != null) {
        return builder(context);
      }
      return const SizedBox.shrink();
    }

    final int itemCount = math.min(_visibleCount, widget.items.length);
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    Widget buildItem(BuildContext context, int index) {
      final item = widget.items[index];
      return widget.itemBuilder(context, item, index);
    }

    if (widget.separatorBuilder != null) {
      return ListView.separated(
        controller: _controller,
        padding: widget.padding,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        primary: widget.primary,
        cacheExtent: widget.cacheExtent,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        itemCount: itemCount,
        itemBuilder: buildItem,
        separatorBuilder: widget.separatorBuilder!,
      );
    }

    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      primary: widget.primary,
      cacheExtent: widget.cacheExtent,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      itemCount: itemCount,
      itemBuilder: buildItem,
    );
  }
}
