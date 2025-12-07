import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

import 'hover_shift.dart';

class TrackListTile extends StatelessWidget {
  const TrackListTile({
    super.key,
    required this.index,
    required this.leading,
    required this.title,
    required this.artistAlbum,
    required this.duration,
    this.meta,
    required this.onTap,
    this.hoverDistance,
    this.padding,
    this.onSecondaryTap,
    this.indexColor,
  });

  final int index;
  final Widget leading;
  final String title;
  final String artistAlbum;
  final String duration;
  final String? meta;
  final VoidCallback onTap;
  final double? hoverDistance;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<Offset>? onSecondaryTap;
  final Color? indexColor;

  @override
  Widget build(BuildContext context) {
    final isMac = MacosTheme.maybeOf(context) != null;
    final EdgeInsetsGeometry contentPadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    final double distance = hoverDistance ?? (isMac ? 16 : 12);

    final Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(isMac ? 12 : 8),
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: contentPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      locale: Locale("zh-Hans", "zh"),
                      style: _titleStyle(context, isMac),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artistAlbum.trim().isEmpty ? '未知艺术家' : artistAlbum,
                      locale: Locale("zh-Hans", "zh"),
                      style: _subtitleStyle(context, isMac),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final hasDuration = duration.isNotEmpty;
                        final hasMeta = meta != null && meta!.isNotEmpty;

                        if (!hasDuration && !hasMeta) {
                          return const SizedBox.shrink();
                        }

                        return Row(
                          children: [
                            if (hasDuration)
                              Text(duration, locale: Locale("zh-Hans", "zh"),style: _metaStyle(context, isMac)),
                            if (hasDuration && hasMeta)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  '|',
                                  locale: Locale("zh-Hans", "zh"),
                                  style: _metaStyle(context, isMac),
                                ),
                              ),
                            if (hasMeta)
                              Expanded(
                                child: Text(
                                  meta!,
                                  locale: Locale("zh-Hans", "zh"),
                                  style: _metaStyle(context, isMac),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: HoverShift(distance: distance, child: content),
        ),
        Padding(
          padding: EdgeInsets.only(right: isMac ? 24 : 20, left: 8),
          child: SizedBox(
            width: 32,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                index.toString(),
                locale: Locale("zh-Hans", "zh"),
                style: _indexStyle(context, isMac),
              ),
            ),
          ),
        ),
      ],
    );

    if (onSecondaryTap == null) {
      return row;
    }

    void _handleContextMenuRequest(Offset globalPosition) {
      onSecondaryTap!(globalPosition);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp:
          (details) => _handleContextMenuRequest(details.globalPosition),
      onLongPressStart:
          (details) => _handleContextMenuRequest(details.globalPosition),
      child: row,
    );
  }

  TextStyle _titleStyle(BuildContext context, bool isMac) {
    if (isMac) {
      final macTheme = MacosTheme.of(context);
      final isDark = macTheme.brightness == Brightness.dark;
      final color = isDark ? Colors.white : MacosColors.labelColor;
      return macTheme.typography.body.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      );
    }
    final textStyle = Theme.of(context).textTheme.titleMedium;
    return (textStyle ?? const TextStyle(fontSize: 16)).copyWith(
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle _subtitleStyle(BuildContext context, bool isMac) {
    if (isMac) {
      final macTheme = MacosTheme.of(context);
      final isDark = macTheme.brightness == Brightness.dark;
      final color = isDark
          ? MacosColors.systemGrayColor
          : MacosColors.secondaryLabelColor;
      return macTheme.typography.caption1.copyWith(color: color);
    }
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 13);
    return base.copyWith(color: theme.colorScheme.onSurfaceVariant);
  }

  TextStyle _metaStyle(BuildContext context, bool isMac) {
    if (isMac) {
      final macTheme = MacosTheme.of(context);
      final isDark = macTheme.brightness == Brightness.dark;
      final color = isDark ? Colors.white70 : MacosColors.secondaryLabelColor;
      return macTheme.typography.caption1.copyWith(color: color);
    }
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    return base.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.85),
    );
  }

  TextStyle _indexStyle(BuildContext context, bool isMac) {
    if (isMac) {
      final macTheme = MacosTheme.of(context);
      final isDark = macTheme.brightness == Brightness.dark;
      final color =
          indexColor ?? (isDark ? Colors.white54 : MacosColors.secondaryLabelColor);
      return macTheme.typography.caption1.copyWith(color: color);
    }
    final theme = Theme.of(context);
    final base = theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12);
    return base.copyWith(
      color: indexColor ??
          theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
    );
  }
}
