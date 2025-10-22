import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:misuzu_music/presentation/widgets/common/hover_glow_overlay.dart';
enum SheetActionVariant { primary, secondary }

class SheetActionButton extends StatefulWidget {
  const SheetActionButton._({
    required this.label,
    required this.onPressed,
    required this.variant,
    this.isBusy = false,
  });

  factory SheetActionButton.primary({
    required String label,
    required VoidCallback? onPressed,
    bool isBusy = false,
  }) {
    return SheetActionButton._(
      label: label,
      onPressed: onPressed,
      variant: SheetActionVariant.primary,
      isBusy: isBusy,
    );
  }

  factory SheetActionButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    bool isBusy = false,
  }) {
    return SheetActionButton._(
      label: label,
      onPressed: onPressed,
      variant: SheetActionVariant.secondary,
      isBusy: isBusy,
    );
  }

  final String label;
  final VoidCallback? onPressed;
  final SheetActionVariant variant;
  final bool isBusy;

  @override
  State<SheetActionButton> createState() => _SheetActionButtonState();
}

class _SheetActionButtonState extends State<SheetActionButton> {
  bool _hovering = false;
  bool _pressing = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isBusy;

  void _setHovering(bool value) {
    if (_hovering == value) {
      return;
    }
    setState(() {
      _hovering = value;
      if (!value) {
        _pressing = false;
      }
    });
  }

  void _setPressing(bool value) {
    if (_pressing == value) {
      return;
    }
    setState(() {
      _pressing = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final isPrimary = widget.variant == SheetActionVariant.primary;
    final enabled = _isEnabled;

    final baseBackground = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.88 : 0.84)
        : (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04));
    final hoverBackground = isPrimary
        ? macTheme.primaryColor
        : (isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08));
    final pressBackground = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.84 : 0.9)
        : (isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.black.withOpacity(0.12));
    final disabledBackground = isPrimary
        ? macTheme.primaryColor.withOpacity(0.28)
        : (isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03));

    final baseBorder = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.55 : 0.42)
        : (isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.black.withOpacity(0.1));
    final hoverBorder = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.75 : 0.58)
        : (isDark
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.16));
    final pressBorder = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.68 : 0.5)
        : (isDark
              ? Colors.white.withOpacity(0.24)
              : Colors.black.withOpacity(0.2));
    final disabledBorder = isPrimary
        ? macTheme.primaryColor.withOpacity(0.18)
        : Colors.transparent;

    final baseTextColor = isPrimary
        ? Colors.white
        : (isDark
              ? Colors.white.withOpacity(0.82)
              : Colors.black.withOpacity(0.75));
    final disabledTextColor = isPrimary
        ? Colors.white.withOpacity(0.6)
        : (isDark
              ? Colors.white.withOpacity(0.36)
              : Colors.black.withOpacity(0.36));

    final backgroundColor = !enabled
        ? disabledBackground
        : _pressing
        ? pressBackground
        : (_hovering ? hoverBackground : baseBackground);
    final borderColor = !enabled
        ? disabledBorder
        : _pressing
        ? pressBorder
        : (_hovering ? hoverBorder : baseBorder);
    final textColor = !enabled ? disabledTextColor : baseTextColor;

    final boxShadow = isPrimary && enabled && (_hovering || _pressing)
        ? [
            BoxShadow(
              color: macTheme.primaryColor.withOpacity(
                _pressing ? (isDark ? 0.45 : 0.28) : (isDark ? 0.36 : 0.24),
              ),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

    Widget child;
    if (widget.isBusy) {
      child = const SizedBox(
        key: ValueKey('busy'),
        width: 14,
        height: 14,
        child: ProgressCircle(radius: 5),
      );
    } else {
      child = Text(
        widget.label,
        key: ValueKey(widget.label),
        style: macTheme.typography.body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
          letterSpacing: -0.1,
        ),
      );
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) {
          _setHovering(true);
        }
      },
      onExit: (_) => _setHovering(false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressing(true) : null,
        onTapCancel: enabled ? () => _setPressing(false) : null,
        onTapUp: enabled ? (_) => _setPressing(false) : null,
        onTap: enabled ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          constraints: const BoxConstraints(minHeight: 30, minWidth: 74),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.9),
            boxShadow: boxShadow,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostedDialogSurface extends StatelessWidget {
  const _FrostedDialogSurface({required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surfaceTint = isDark
        ? const Color(0xFF1C1C23).withOpacity(0.56)
        : Colors.white.withOpacity(0.52);
    final overlayTint = isDark
        ? const Color(0xFF0D0D11).withOpacity(0.42)
        : const Color(0xFFFBFDFF).withOpacity(0.58);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.07);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.65),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [surfaceTint, overlayTint],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.33)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: child,
          ),
        ),
      ),
    );

    return HoverGlowOverlay(
      isDarkMode: isDark,
      borderRadius: BorderRadius.circular(14),
      blurSigma: 0,
      glowOpacity: 0.22,
      glowRadius: 0.58,
      child: card,
    );
  }
}

class PlaylistModalScaffold extends StatelessWidget {
  const PlaylistModalScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.maxWidth = 340,
    this.contentSpacing = 14,
    this.actionsSpacing = 16,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 28,
    ),
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
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    final actionRowChildren = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) {
        actionRowChildren.add(const SizedBox(width: 10));
      }
      actionRowChildren.add(actions[i]);
    }

    final titleColor = isDark
        ? Colors.white.withOpacity(0.95)
        : Colors.black.withOpacity(0.88);
    final bodyColor = isDark
        ? Colors.white.withOpacity(0.86)
        : Colors.black.withOpacity(0.78);
    final captionColor = isDark
        ? Colors.white.withOpacity(0.62)
        : Colors.black.withOpacity(0.58);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(240.0, maxWidth);
          final dialogContent = _FrostedDialogSurface(
            isDark: isDark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style:
                      theme.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ) ??
                      TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ),
                ),
                SizedBox(height: contentSpacing),
                DefaultTextStyle.merge(
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                        color: bodyColor,
                        height: 1.4,
                      ) ??
                      TextStyle(color: bodyColor, height: 1.4, fontSize: 13),
                  child: IconTheme(
                    data: IconTheme.of(context).copyWith(color: bodyColor),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 120),
                      style:
                          theme.textTheme.bodyMedium?.copyWith(
                            color: bodyColor,
                          ) ??
                          TextStyle(color: bodyColor),
                      child: body,
                    ),
                  ),
                ),
                SizedBox(height: actionsSpacing),
                DefaultTextStyle.merge(
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                        color: captionColor,
                      ) ??
                      TextStyle(color: captionColor, fontSize: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actionRowChildren,
                  ),
                ),
              ],
            ),
          );

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: dialogContent,
            ),
          );
        },
      ),
    );
  }
}

Future<T?> showPlaylistModalDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final materialLocalizations = Localizations.of<MaterialLocalizations>(
    context,
    MaterialLocalizations,
  );
  final barrierLabel = materialLocalizations?.modalBarrierDismissLabel ?? '关闭';
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withOpacity(0.28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}