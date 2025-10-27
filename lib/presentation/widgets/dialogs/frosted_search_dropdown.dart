import 'package:flutter/cupertino.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

/// 毛玻璃风格的搜索建议浮层；通过 Overlay 组合时使用。
class FrostedSearchDropdown extends StatelessWidget {
  const FrostedSearchDropdown({
    super.key,
    required this.children,
    this.maxHeight = 280,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
  });

  final List<Widget> children;
  final double maxHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    final surfaceTint = isDark
        ? const Color(0xFF1A1B1F).withOpacity(0.82)
        : Colors.white.withOpacity(0.86);
    final overlayTint = isDark
        ? const Color(0xFF0E1013).withOpacity(0.64)
        : const Color(0xFFF9FBFF).withOpacity(0.78);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.06);
    final shadowColor = Colors.black.withOpacity(isDark ? 0.45 : 0.16);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [surfaceTint, overlayTint],
            ),
            border: Border.all(color: borderColor, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 26,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) => children[index],
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.7,
                  color: dividerColor,
                ),
                itemCount: children.length,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FrostedSearchOption extends StatefulWidget {
  const FrostedSearchOption({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<FrostedSearchOption> createState() => _FrostedSearchOptionState();
}

class _FrostedSearchOptionState extends State<FrostedSearchOption> {
  bool _hovering = false;

  void _updateHover(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    final baseTitleColor = isDark
        ? Colors.white.withOpacity(0.95)
        : Colors.black.withOpacity(0.9);
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.65)
        : Colors.black.withOpacity(0.63);
    final iconColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.62);
    final hoverColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    return MouseRegion(
      cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => _updateHover(true),
      onExit: (_) => _updateHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => debugPrint('[SearchField] Gesture onTapDown -> ${widget.title}'),
        onTapUp: (_) => debugPrint('[SearchField] Gesture onTapUp -> ${widget.title}'),
        onTapCancel: () => debugPrint('[SearchField] Gesture onTapCancel -> ${widget.title}'),
        onTap: () {
          debugPrint('[SearchField] Gesture onTap -> ${widget.title}');
          widget.onTap?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering && widget.onTap != null ? hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
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
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                      Text(
                        widget.subtitle!,
                        locale: const Locale('zh-Hans', 'zh'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: subtitleColor,
                              fontSize: 11.5,
                            ) ??
                            TextStyle(
                              color: subtitleColor,
                              fontSize: 11.5,
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                CupertinoIcons.arrow_turn_down_right,
                size: 14,
                color: iconColor.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
