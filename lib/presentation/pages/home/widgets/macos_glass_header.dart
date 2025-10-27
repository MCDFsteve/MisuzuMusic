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
    required this.searchSuggestions,
    required this.onSearchPreviewChanged,
    required this.onSuggestionSelected,
    this.showBackButton = false,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.backTooltip = '返回上一层',
    this.sortMode,
    this.onSortModeChanged,
    this.showCreatePlaylistButton = true,
    this.showSelectFolderButton = true,
    this.onInteract,
  });

  final double height;
  final String sectionLabel;
  final String? statsLabel;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String>? onSearchPreviewChanged;
  final List<LibrarySearchSuggestion> searchSuggestions;
  final ValueChanged<LibrarySearchSuggestion>? onSuggestionSelected;
  final VoidCallback onSelectMusicFolder;
  final VoidCallback onCreatePlaylist;
  final bool showBackButton;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final String backTooltip;
  final TrackSortMode? sortMode;
  final ValueChanged<TrackSortMode>? onSortModeChanged;
  final bool showCreatePlaylistButton;
  final bool showSelectFolderButton;
  final VoidCallback? onInteract;

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
    final bool isWindows = Platform.isWindows;
    final double actionButtonSize = isWindows ? 32 : 36;
    final double primaryIconSize = isWindows ? 16 : 22;
    final double backIconSize = isWindows ? 14 : 20;
    final double actionSpacing = isWindows ? 4 : 8;

    void handleInteraction() => onInteract?.call();

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
                      locale: Locale("zh-Hans", "zh"),
                      style: theme.typography.title2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: sectionLabel),
                          if (statsLabel != null) ...[
                            TextSpan(text: '  |  '),
                            TextSpan(text: statsLabel),
                          ],
                        ],
                        style: theme.typography.caption1.copyWith(
                          color: textColor.withOpacity(0.68),
                        ),
                      ),
                      locale: Locale("zh-Hans", "zh"),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Flexible(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.only(right: isWindows ? 8 : 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 100, maxWidth: 320),
                          child: LibrarySearchField(
                            query: searchQuery,
                            onQueryChanged: onSearchChanged,
                            onPreviewChanged: onSearchPreviewChanged,
                            suggestions: searchSuggestions,
                            onSuggestionSelected: onSuggestionSelected,
                            onInteract: handleInteraction,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showBackButton)
                _HeaderTooltip(
                  useMacStyle: !isWindows,
                  message: backTooltip,
                  child: _HeaderIconButton(
                    baseColor: canNavigateBack
                        ? textColor.withOpacity(0.72)
                        : textColor.withOpacity(0.24),
                    hoverColor: textColor,
                    icon: CupertinoIcons.left_chevron,
                    onPressed: canNavigateBack
                        ? () {
                            handleInteraction();
                            onNavigateBack?.call();
                          }
                        : null,
                    size: actionButtonSize,
                    iconSize: backIconSize,
                    enabled: canNavigateBack,
                    isWindowsStyle: isWindows,
                  ),
                ),
              if (showBackButton && sortMode != null && onSortModeChanged != null)
                Padding(
                  padding: EdgeInsets.only(left: actionSpacing),
                  child: _HeaderTooltip(
                    useMacStyle: !isWindows,
                    message: '切换排序方式',
                    child: _SortModeButton(
                      sortMode: sortMode!,
                      onSortModeChanged: (mode) {
                        handleInteraction();
                        onSortModeChanged!(mode);
                      },
                      textColor: textColor,
                      enabled: canNavigateBack,
                      size: actionButtonSize,
                      iconSize: backIconSize,
                      isWindowsStyle: isWindows,
                    ),
                  ),
                ),
              if (showBackButton) SizedBox(width: actionSpacing),
              if (showCreatePlaylistButton)
                _HeaderTooltip(
                  useMacStyle: !isWindows,
                  message: '新建歌单',
                  child: _HeaderIconButton(
                    baseColor: textColor.withOpacity(0.72),
                    hoverColor: textColor,
                    size: actionButtonSize,
                    iconSize: primaryIconSize,
                    icon: CupertinoIcons.add,
                    onPressed: () {
                      handleInteraction();
                      onCreatePlaylist();
                    },
                    isWindowsStyle: isWindows,
                  ),
                ),
              if (showCreatePlaylistButton && showSelectFolderButton)
                SizedBox(width: actionSpacing),
              if (showSelectFolderButton)
                _HeaderTooltip(
                  useMacStyle: !isWindows,
                  message: '选择音乐文件夹',
                  child: _HeaderIconButton(
                    baseColor: textColor.withOpacity(0.72),
                    hoverColor: textColor,
                    size: actionButtonSize,
                    iconSize: primaryIconSize,
                    icon: CupertinoIcons.folder,
                    onPressed: () {
                      handleInteraction();
                      onSelectMusicFolder();
                    },
                    isWindowsStyle: isWindows,
                  ),
                ),
              if (isWindows) ...[
                const SizedBox(width: 8),
                _VerticalSeparator(color: textColor.withOpacity(0.18)),
                const SizedBox(width: 8),
                _WindowsWindowControls(isDarkMode: isDarkMode),
              ],
            ],
          ),
        ),
      ),
    );

    final draggable = (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
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
    this.isWindowsStyle = false,
  });

  final Color baseColor;
  final Color hoverColor;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool enabled;
  final bool isWindowsStyle;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderTooltip extends StatelessWidget {
  const _HeaderTooltip({
    required this.message,
    required this.child,
    required this.useMacStyle,
  });

  final String message;
  final Widget child;
  final bool useMacStyle;

  @override
  Widget build(BuildContext context) {
    if (useMacStyle) {
      return MacosTooltip(
        message: message,
        child: child,
      );
    }

    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xF0121212),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: child,
    );
  }
}

class _VerticalSeparator extends StatelessWidget {
  const _VerticalSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Center(child: Container(width: 1, height: 24, color: color)),
    );
  }
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
  void onWindowMaximize([int? windowId]) => _updateMaximized(true);

  @override
  void onWindowUnmaximize([int? windowId]) => _updateMaximized(false);

  void _updateMaximized(bool value) {
    if (!mounted || _isMaximized == value) {
      return;
    }
    setState(() => _isMaximized = value);
  }

  Color get _iconColor => widget.isDarkMode
      ? Colors.white.withOpacity(0.82)
      : Colors.black.withOpacity(0.7);

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
        const SizedBox(width: 4),
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
        const SizedBox(width: 4),
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
      child: _HeaderTooltip(
        useMacStyle: false,
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
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
    final bool windowsStyle = widget.isWindowsStyle;
    final Color targetColor = !isEnabled
        ? widget.baseColor
        : (_hovering ? widget.hoverColor : widget.baseColor);
    final double scale = !isEnabled || windowsStyle
        ? 1.0
        : (_pressing ? 0.95 : (_hovering ? 1.05 : 1.0));

    final BorderRadius borderRadius = windowsStyle
        ? BorderRadius.circular(4)
        : BorderRadius.circular(widget.size);

    final Color backgroundColor = windowsStyle
        ? (_hovering && isEnabled
              ? widget.hoverColor.withOpacity(0.14)
              : Colors.transparent)
        : Colors.transparent;

    final SystemMouseCursor cursor = windowsStyle
        ? SystemMouseCursors.basic
        : (isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic);

    return MouseRegion(
      cursor: cursor,
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
        onTapDown: isEnabled && !windowsStyle
            ? (_) => _updatePressing(true)
            : null,
        onTapUp: isEnabled && !windowsStyle
            ? (_) => _updatePressing(false)
            : null,
        onTapCancel: isEnabled && !windowsStyle
            ? () => _updatePressing(false)
            : null,
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
            ),
            child: Center(
              child: windowsStyle
                  ? Icon(widget.icon, size: widget.iconSize, color: targetColor)
                  : MacosIcon(
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

class _SortModeButton extends StatefulWidget {
  const _SortModeButton({
    required this.sortMode,
    required this.onSortModeChanged,
    required this.textColor,
    required this.enabled,
    required this.size,
    required this.iconSize,
    required this.isWindowsStyle,
  });

  final TrackSortMode sortMode;
  final ValueChanged<TrackSortMode> onSortModeChanged;
  final Color textColor;
  final bool enabled;
  final double size;
  final double iconSize;
  final bool isWindowsStyle;

  @override
  State<_SortModeButton> createState() => _SortModeButtonState();
}

class _SortModeButtonState extends State<_SortModeButton> {
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

  void _showSortModeMenu() async {
    if (!widget.enabled) return;

    final selectedMode = await showPlaylistModalDialog(
      context: context,
      builder: (context) => _PlaylistModalScaffold(
        title: '选择排序方式',
        maxWidth: 280,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: TrackSortMode.values.map((mode) {
            return _SortModeMenuItem(
              mode: mode,
              isSelected: mode == widget.sortMode,
              onTap: () => Navigator.of(context).pop(mode),
            );
          }).toList(),
        ),
        actions: [
          SheetActionButton.secondary(
            label: '取消',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

    if (selectedMode != null && selectedMode != widget.sortMode) {
      widget.onSortModeChanged(selectedMode);
    }
  }

  IconData _getSortIcon() {
    switch (widget.sortMode) {
      case TrackSortMode.titleAZ:
        return CupertinoIcons.sort_down;
      case TrackSortMode.titleZA:
        return CupertinoIcons.sort_up;
      case TrackSortMode.addedNewest:
        return CupertinoIcons.clock;
      case TrackSortMode.addedOldest:
        return CupertinoIcons.time;
      case TrackSortMode.artistAZ:
        return CupertinoIcons.person_crop_circle_badge_checkmark;
      case TrackSortMode.artistZA:
        return CupertinoIcons.person_crop_circle_badge_minus;
      case TrackSortMode.albumAZ:
        return CupertinoIcons.square_stack_3d_up;
      case TrackSortMode.albumZA:
        return CupertinoIcons.square_stack_3d_down_dottedline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.enabled;
    final bool windowsStyle = widget.isWindowsStyle;
    final baseColor = isEnabled
        ? widget.textColor.withOpacity(0.72)
        : widget.textColor.withOpacity(0.24);
    final Color targetColor = !isEnabled
        ? baseColor
        : (_hovering ? widget.textColor : baseColor);
    final double scale = !isEnabled || windowsStyle
        ? 1.0
        : (_pressing ? 0.95 : (_hovering ? 1.05 : 1.0));

    final BorderRadius borderRadius = windowsStyle
        ? BorderRadius.circular(4)
        : BorderRadius.circular(widget.size);

    final Color backgroundColor = windowsStyle
        ? (_hovering && isEnabled
              ? widget.textColor.withOpacity(0.14)
              : Colors.transparent)
        : Colors.transparent;

    final SystemMouseCursor cursor = windowsStyle
        ? SystemMouseCursors.basic
        : (isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic);

    return MouseRegion(
      cursor: cursor,
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
        onTapDown: isEnabled && !windowsStyle
            ? (_) => _updatePressing(true)
            : null,
        onTapUp: isEnabled && !windowsStyle
            ? (_) => _updatePressing(false)
            : null,
        onTapCancel: isEnabled && !windowsStyle
            ? () => _updatePressing(false)
            : null,
        onTap: isEnabled ? _showSortModeMenu : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
            ),
            child: Center(
              child: windowsStyle
                  ? Icon(_getSortIcon(), size: widget.iconSize, color: targetColor)
                  : MacosIcon(
                      _getSortIcon(),
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

class _SortModeMenuItem extends StatefulWidget {
  const _SortModeMenuItem({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final TrackSortMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SortModeMenuItem> createState() => _SortModeMenuItemState();
}

class _SortModeMenuItemState extends State<_SortModeMenuItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    final textColor = isDark
        ? Colors.white.withOpacity(0.88)
        : Colors.black.withOpacity(0.85);
    final hoverColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);
    final selectedColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? selectedColor
                : (_hovering ? hoverColor : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.mode.displayName,
                  locale: Locale("zh-Hans", "zh"),
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.isSelected)
                Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 16,
                  color: macTheme?.primaryColor ?? theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
