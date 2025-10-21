import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

import 'package:misuzu_music/presentation/widgets/common/adaptive_scrollbar.dart';

class CollectionOverviewGrid extends StatelessWidget {
  const CollectionOverviewGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(24),
    this.spacing = 24,
    this.preferredItemWidth = 540,
    this.scrollbarMargin = const EdgeInsets.only(right: 6, top: 16, bottom: 16),
  });

  final int itemCount;
  final Widget Function(BuildContext context, double itemWidth, int index)
  itemBuilder;
  final EdgeInsets padding;
  final double spacing;
  final double preferredItemWidth;
  final EdgeInsets scrollbarMargin;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    final macTheme = MacosTheme.maybeOf(context);
    final isDark = macTheme != null
        ? macTheme.brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final double contentWidth = maxWidth.isFinite
            ? math.max(0, maxWidth - padding.horizontal)
            : 0;

        final int columnCount = contentWidth > 0
            ? math.max(
                1,
                math.min(
                  3,
                  ((contentWidth + spacing) / (preferredItemWidth + spacing))
                      .floor(),
                ),
              )
            : 1;

        final double rawItemWidth = columnCount == 1
            ? contentWidth
            : (contentWidth - (columnCount - 1) * spacing) / columnCount;

        final double itemWidth = columnCount == 1
            ? math.min(preferredItemWidth, contentWidth)
            : math.min(preferredItemWidth, rawItemWidth);

        return AdaptiveScrollbar(
          isDarkMode: isDark,
          margin: scrollbarMargin,
          builder: (controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: math.max(0, contentWidth),
                ),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (var index = 0; index < itemCount; index++)
                      SizedBox(
                        width: columnCount == 1
                            ? (contentWidth <= 0
                                  ? preferredItemWidth
                                  : math.min(preferredItemWidth, contentWidth))
                            : (itemWidth <= 0 ? preferredItemWidth : itemWidth),
                        child: itemBuilder(context, itemWidth, index),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
