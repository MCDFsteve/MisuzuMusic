part of 'package:misuzu_music/presentation/pages/home_page.dart';

enum _SheetActionVariant { primary, secondary }

class _SheetActionButton extends StatefulWidget {
  const _SheetActionButton._({
    required this.label,
    required this.onPressed,
    required this.variant,
    this.isBusy = false,
  });

  factory _SheetActionButton.primary({
    required String label,
    required VoidCallback? onPressed,
    bool isBusy = false,
  }) {
    return _SheetActionButton._(
      label: label,
      onPressed: onPressed,
      variant: _SheetActionVariant.primary,
      isBusy: isBusy,
    );
  }

  factory _SheetActionButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    bool isBusy = false,
  }) {
    return _SheetActionButton._(
      label: label,
      onPressed: onPressed,
      variant: _SheetActionVariant.secondary,
      isBusy: isBusy,
    );
  }

  final String label;
  final VoidCallback? onPressed;
  final _SheetActionVariant variant;
  final bool isBusy;

  @override
  State<_SheetActionButton> createState() => _SheetActionButtonState();
}

class _SheetActionButtonState extends State<_SheetActionButton> {
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
    final isPrimary = widget.variant == _SheetActionVariant.primary;
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
    final baseColor = isDark
        ? const Color(0xFF1C1C1E).withOpacity(0.33)
        : Colors.white.withOpacity(0.5);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.07);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.6),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.28) : Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: child,
          ),
        ),
      ),
    );

    return HoverGlowOverlay(
      isDarkMode: isDark,
      borderRadius: BorderRadius.circular(14),
      blurSigma: 0,
      glowOpacity: 0.33,
      glowRadius: 0.65,
      child: card,
    );
  }
}

class _PlaylistModalScaffold extends StatelessWidget {
  const _PlaylistModalScaffold({
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
    final isDark = theme.brightness == Brightness.dark;

    final actionRowChildren = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) {
        actionRowChildren.add(const SizedBox(width: 10));
      }
      actionRowChildren.add(actions[i]);
    }

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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: contentSpacing),
                body,
                SizedBox(height: actionsSpacing),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actionRowChildren,
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
