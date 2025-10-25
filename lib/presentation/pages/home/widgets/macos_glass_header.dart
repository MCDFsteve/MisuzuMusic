part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _MacOSGlassHeader extends StatelessWidget {
  const _MacOSGlassHeader({
    required this.height,
    required this.sectionLabel,
    required this.statsLabel,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSelectMusicFolder,
    required this.onCreatePlaylist,
    this.showBackButton = false,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.backTooltip = '返回上一层',
  });

  final double height;
  final String sectionLabel;
  final String? statsLabel;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectMusicFolder;
  final VoidCallback onCreatePlaylist;
  final bool showBackButton;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final String backTooltip;

  Future<void> _handleDoubleTap() async {
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return;
    }

    final bool isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : MacosColors.labelColor;

    final frostedColor = theme.canvasColor.withOpacity(
      isDarkMode ? 0.35 : 0.36,
    );

    final headerContent = ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: frostedColor,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.45),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Misuzu Music',
                      style: theme.typography.title2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sectionLabel,
                      style: theme.typography.caption1.copyWith(
                        color: textColor.withOpacity(0.68),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (statsLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      statsLabel!,
                      style: theme.typography.caption1.copyWith(
                        color: textColor.withOpacity(0.68),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 320,
                  ),
                  child: LibrarySearchField(
                    query: searchQuery,
                    onQueryChanged: onSearchChanged,
                  ),
                ),
              ),
              if (showBackButton)
                MacosTooltip(
                  message: backTooltip,
                  child: _HeaderIconButton(
                    baseColor: canNavigateBack
                        ? textColor.withOpacity(0.72)
                        : textColor.withOpacity(0.24),
                    hoverColor: textColor,
                    icon: CupertinoIcons.left_chevron,
                    onPressed: canNavigateBack ? onNavigateBack : null,
                    size: 36,
                    iconSize: 20,
                    enabled: canNavigateBack,
                  ),
                ),
              if (showBackButton) const SizedBox(width: 8),
              MacosTooltip(
                message: '新建歌单',
                child: _HeaderIconButton(
                  baseColor: textColor.withOpacity(0.72),
                  hoverColor: textColor,
                  size: 36,
                  iconSize: 22,
                  icon: CupertinoIcons.add,
                  onPressed: onCreatePlaylist,
                ),
              ),
              const SizedBox(width: 8),
              MacosTooltip(
                message: '选择音乐文件夹',
                child: _HeaderIconButton(
                  baseColor: textColor.withOpacity(0.72),
                  hoverColor: textColor,
                  size: 36,
                  iconSize: 22,
                  icon: CupertinoIcons.folder,
                  onPressed: onSelectMusicFolder,
                ),
              ),
              if (Platform.isWindows) ...[
                const SizedBox(width: 12),
                _WindowsWindowControls(isDarkMode: isDarkMode),
              ],
            ],
          ),
        ),
      ),
    );

    final draggable =
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
        ? DragToMoveArea(child: headerContent)
        : headerContent;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _handleDoubleTap,
      child: draggable,
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.baseColor,
    required this.hoverColor,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.iconSize = 22,
    this.enabled = true,
  });

  final Color baseColor;
  final Color hoverColor;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool enabled;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _WindowsWindowControls extends StatefulWidget {
  const _WindowsWindowControls({required this.isDarkMode});

  final bool isDarkMode;

  @override
  State<_WindowsWindowControls> createState() => _WindowsWindowControlsState();
}

class _WindowsWindowControlsState extends State<_WindowsWindowControls>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _isMaximized = isMaximized);
  }

  @override
  void onWindowMaximize() => _updateMaximized(true);

  @override
  void onWindowUnmaximize() => _updateMaximized(false);

  void _updateMaximized(bool value) {
    if (!mounted || _isMaximized == value) {
      return;
    }
    setState(() => _isMaximized = value);
  }

  Color get _iconColor => widget.isDarkMode
      ? Colors.white.withOpacity(0.85)
      : Colors.black.withOpacity(0.78);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowsCaptionButton(
          tooltip: '最小化',
          iconType: _CaptionIconType.minimize,
          foregroundColor: _iconColor,
          onPressed: () => windowManager.minimize(),
        ),
        _WindowsCaptionButton(
          tooltip: _isMaximized ? '还原' : '最大化',
          iconType: _isMaximized
              ? _CaptionIconType.restore
              : _CaptionIconType.maximize,
          foregroundColor: _iconColor,
          onPressed: () async {
            final isMaximized = await windowManager.isMaximized();
            if (isMaximized) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
            _syncWindowState();
          },
        ),
        _WindowsCaptionButton(
          tooltip: '关闭',
          iconType: _CaptionIconType.close,
          foregroundColor: _iconColor,
          hoverBackgroundColor: const Color(0xFFD70022),
          hoverForegroundColor: Colors.white,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

enum _CaptionIconType { minimize, maximize, restore, close }

class _WindowsCaptionButton extends StatefulWidget {
  const _WindowsCaptionButton({
    required this.tooltip,
    required this.iconType,
    required this.foregroundColor,
    required this.onPressed,
    this.hoverBackgroundColor,
    this.hoverForegroundColor,
  });

  final String tooltip;
  final _CaptionIconType iconType;
  final Color foregroundColor;
  final Color? hoverBackgroundColor;
  final Color? hoverForegroundColor;
  final VoidCallback onPressed;

  @override
  State<_WindowsCaptionButton> createState() => _WindowsCaptionButtonState();
}

class _WindowsCaptionButtonState extends State<_WindowsCaptionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final baseBackground = Colors.transparent;
    final baseForeground = widget.foregroundColor;
    final hoverBackground =
        widget.hoverBackgroundColor ?? widget.foregroundColor.withOpacity(0.12);
    final hoverForeground = widget.hoverForegroundColor ?? baseForeground;

    final backgroundColor = _hovering ? hoverBackground : baseBackground;
    final foregroundColor = _hovering ? hoverForeground : baseForeground;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: 32,
            color: backgroundColor,
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(16, 16),
              painter: _CaptionIconPainter(
                type: widget.iconType,
                color: foregroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionIconPainter extends CustomPainter {
  _CaptionIconPainter({required this.type, required this.color});

  final _CaptionIconType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    switch (type) {
      case _CaptionIconType.minimize:
        final y = size.height * 0.7;
        canvas.drawLine(
          Offset(size.width * 0.2, y),
          Offset(size.width * 0.8, y),
          paint,
        );
        break;
      case _CaptionIconType.maximize:
        final rect = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * 0.6,
          height: size.height * 0.6,
        );
        canvas.drawRect(rect, paint);
        break;
      case _CaptionIconType.restore:
        final backRect = Rect.fromCenter(
          center: size.center(Offset(-size.width * 0.08, size.height * 0.08)),
          width: size.width * 0.55,
          height: size.height * 0.55,
        );
        final frontRect = backRect.translate(
          size.width * 0.15,
          -size.height * 0.15,
        );
        canvas.drawRect(backRect, paint);
        canvas.drawRect(frontRect, paint);
        canvas.drawLine(
          frontRect.topLeft,
          Offset(frontRect.left, backRect.top),
          paint,
        );
        canvas.drawLine(
          frontRect.topLeft,
          Offset(backRect.right, frontRect.top),
          paint,
        );
        break;
      case _CaptionIconType.close:
        canvas.drawLine(
          Offset(size.width * 0.25, size.height * 0.25),
          Offset(size.width * 0.75, size.height * 0.75),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.75, size.height * 0.25),
          Offset(size.width * 0.25, size.height * 0.75),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovering = false;
  bool _pressing = false;

  void _updateHovering(bool value) {
    if (_hovering == value || !mounted) return;
    setState(() => _hovering = value);
  }

  void _updatePressing(bool value) {
    if (_pressing == value || !mounted) return;
    setState(() => _pressing = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.enabled && widget.onPressed != null;
    final Color targetColor = !isEnabled
        ? widget.baseColor
        : (_hovering ? widget.hoverColor : widget.baseColor);
    final double scale = !isEnabled
        ? 1.0
        : (_pressing ? 0.95 : (_hovering ? 1.05 : 1.0));

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isEnabled) {
          _updateHovering(true);
        }
      },
      onExit: (_) {
        _updateHovering(false);
        _updatePressing(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled ? (_) => _updatePressing(true) : null,
        onTapUp: isEnabled ? (_) => _updatePressing(false) : null,
        onTapCancel: isEnabled ? () => _updatePressing(false) : null,
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: MacosIcon(
                widget.icon,
                size: widget.iconSize,
                color: targetColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
