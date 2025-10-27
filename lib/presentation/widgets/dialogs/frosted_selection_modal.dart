import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:misuzu_music/core/widgets/modal_dialog.dart';

class FrostedSelectionModal extends StatelessWidget {
  const FrostedSelectionModal({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.maxWidth = 360,
    this.contentSpacing = 16,
    this.actionsSpacing = 16,
    this.insetPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final double maxWidth;
  final double contentSpacing;
  final double actionsSpacing;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    return PlaylistModalScaffold(
      title: title,
      body: body,
      actions: actions,
      maxWidth: maxWidth,
      contentSpacing: contentSpacing,
      actionsSpacing: actionsSpacing,
      insetPadding: insetPadding,
    );
  }
}

class FrostedSelectionContainer extends StatelessWidget {
  const FrostedSelectionContainer({
    super.key,
    required this.child,
    this.maxHeight,
  });

  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    final background = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.92);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.black.withOpacity(0.08);
    final shadowColor = Colors.black.withOpacity(isDark ? 0.38 : 0.12);

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? double.infinity,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.85),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class FrostedOptionTile extends StatefulWidget {
  const FrostedOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onPressed,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onPressed;
  final bool enabled;
  final EdgeInsets padding;

  @override
  State<FrostedOptionTile> createState() => _FrostedOptionTileState();
}

class _FrostedOptionTileState extends State<FrostedOptionTile> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    final bool enabled = widget.enabled && widget.onPressed != null;
    final baseTitleColor = isDark
        ? Colors.white.withOpacity(enabled ? 0.92 : 0.42)
        : Colors.black.withOpacity(enabled ? 0.88 : 0.42);
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.62)
        : Colors.black.withOpacity(0.6);
    final hoverColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    final backgroundColor = _hovering && enabled ? hoverColor : Colors.transparent;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      locale: const Locale('zh-Hans', 'zh'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: baseTitleColor,
                          ) ??
                          TextStyle(
                            fontWeight: FontWeight.w500,
                            color: baseTitleColor,
                          ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        locale: const Locale('zh-Hans', 'zh'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: subtitleColor,
                              height: 1.2,
                              fontSize: 11.5,
                            ) ??
                            TextStyle(
                              color: subtitleColor,
                              height: 1.2,
                              fontSize: 11.5,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
