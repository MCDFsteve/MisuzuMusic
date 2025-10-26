import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class MacosContextMenuAction {
  const MacosContextMenuAction({
    required this.label,
    this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onSelected;
  final bool destructive;
}

class MacosContextMenu {
  static Future<void> show({
    required BuildContext context,
    required Offset globalPosition,
    required List<MacosContextMenuAction> actions,
    double width = 188,
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null || actions.isEmpty) {
      return Future.value();
    }

    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) {
      return Future.value();
    }

    final overlaySize = overlayBox.size;
    final localPosition = overlayBox.globalToLocal(globalPosition);

    final estimatedHeight = (actions.length * 44.0) + 16.0;
    final margin = 12.0;
    double left = localPosition.dx;
    double top = localPosition.dy;

    if (left + width + margin > overlaySize.width) {
      left = overlaySize.width - width - margin;
    }
    if (top + estimatedHeight + margin > overlaySize.height) {
      top = overlaySize.height - estimatedHeight - margin;
    }
    left = left.clamp(margin, overlaySize.width - width - margin);
    top = top.clamp(margin, overlaySize.height - estimatedHeight - margin);

    final completer = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _MacosContextMenuOverlay(
        position: Offset(left, top),
        width: width,
        actions: actions,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );

    overlay.insert(entry);
    return completer.future;
  }
}

class _MacosContextMenuOverlay extends StatefulWidget {
  const _MacosContextMenuOverlay({
    required this.position,
    required this.width,
    required this.actions,
    required this.onDismiss,
  });

  final Offset position;
  final double width;
  final List<MacosContextMenuAction> actions;
  final VoidCallback onDismiss;

  @override
  State<_MacosContextMenuOverlay> createState() =>
      _MacosContextMenuOverlayState();
}

class _MacosContextMenuOverlayState extends State<_MacosContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final isDark =
        (macTheme?.brightness ?? theme.brightness) == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              onSecondaryTapUp: (_) => widget.onDismiss(),
            ),
          ),
          Positioned(
            left: widget.position.dx,
            top: widget.position.dy,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOut,
              ),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutBack,
                ),
                child: _MenuSurface(
                  width: widget.width,
                  actions: widget.actions,
                  onDismiss: widget.onDismiss,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSurface extends StatelessWidget {
  const _MenuSurface({
    required this.width,
    required this.actions,
    required this.onDismiss,
    required this.isDark,
  });

  final double width;
  final List<MacosContextMenuAction> actions;
  final VoidCallback onDismiss;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surfaceTint = isDark
        ? const Color(0xFF14141C).withOpacity(0.46)
        : const Color(0xFFFFFFFF).withOpacity(0.6);
    final overlayTint = isDark
        ? const Color(0xFF07070B).withOpacity(0.28)
        : const Color(0xFFEAF3FF).withOpacity(0.42);
    final highlightTint = isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.36);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [surfaceTint, overlayTint],
              stops: const [0.12, 1.0],
            ),
            border: Border.all(color: borderColor, width: 0.6),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.35)
                    : Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [highlightTint, Colors.transparent],
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: actions
                .map(
                  (action) => _MenuTile(
                    action: action,
                    onDismiss: onDismiss,
                    isDark: isDark,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatefulWidget {
  const _MenuTile({
    required this.action,
    required this.onDismiss,
    required this.isDark,
  });

  final MacosContextMenuAction action;
  final VoidCallback onDismiss;
  final bool isDark;

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);
    final iconColor = widget.action.destructive
        ? (widget.isDark ? Colors.redAccent.shade200 : Colors.redAccent)
        : (widget.isDark
              ? Colors.white.withOpacity(_hovering ? 0.96 : 0.84)
              : Colors.black.withOpacity(_hovering ? 0.84 : 0.72));
    final textColor = widget.action.destructive
        ? (widget.isDark
              ? Colors.redAccent.shade100
              : Colors.redAccent.shade200)
        : (widget.isDark
              ? Colors.white.withOpacity(_hovering ? 0.97 : 0.9)
              : Colors.black.withOpacity(_hovering ? 0.9 : 0.78));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onDismiss();
          widget.action.onSelected();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering ? hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (widget.action.icon != null)
                Icon(widget.action.icon, size: 18, color: iconColor),
              if (widget.action.icon != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.action.label,
                  locale: Locale("zh-Hans", "zh"),
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontSize: 13,
                      ) ??
                      TextStyle(color: textColor, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
