part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _MacOSGlassHeader extends StatefulWidget {
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
    required this.backTooltip,
    this.sortMode,
    this.onSortModeChanged,
    this.showCreatePlaylistButton = true,
    this.showSelectFolderButton = true,
    this.onInteract,
    this.showLogoutButton = false,
    this.logoutEnabled = true,
    this.onLogout,
    required this.logoutTooltip,
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
  final bool showLogoutButton;
  final bool logoutEnabled;
  final VoidCallback? onLogout;
  final String logoutTooltip;

  @override
  State<_MacOSGlassHeader> createState() => _MacOSGlassHeaderState();
}

class _MacOSGlassHeaderState extends State<_MacOSGlassHeader> {
  final GlobalKey _searchRegionKey = GlobalKey();
  final GlobalKey _backButtonKey = GlobalKey();
  final GlobalKey _sortButtonKey = GlobalKey();
  final GlobalKey _logoutButtonKey = GlobalKey();
  final GlobalKey _createPlaylistButtonKey = GlobalKey();
  final GlobalKey _selectFolderButtonKey = GlobalKey();
  final GlobalKey _windowsControlsKey = GlobalKey();

  Duration? _lastPrimaryTapUpTime;
  Offset? _lastPrimaryTapUpGlobalPosition;
  bool _dragRequested = false;
  bool _suppressDragUntilUp = false;
  bool _pointerStartedOverInteractive = false;
  Offset? _initialPointerPosition;
  bool _pendingDoubleClick = false;

  static const Duration _doubleClickTimeout = Duration(milliseconds: 500);
  static const double _doubleClickDistanceSquared = 144;
  static const double _dragInitiateDistanceSquared = 16;

  Widget _wrapInteractiveRegion({
    required Widget child,
    required GlobalKey key,
  }) {
    return KeyedSubtree(key: key, child: child);
  }

  Iterable<GlobalKey> get _activeInteractiveRegionKeys sync* {
    yield _searchRegionKey;
    if (widget.showBackButton) {
      yield _backButtonKey;
      if (widget.sortMode != null && widget.onSortModeChanged != null) {
        yield _sortButtonKey;
      }
    }
    if (widget.showLogoutButton) {
      yield _logoutButtonKey;
    }
    if (widget.showCreatePlaylistButton) {
      yield _createPlaylistButtonKey;
    }
    if (widget.showSelectFolderButton) {
      yield _selectFolderButtonKey;
    }
    if (Platform.isWindows || Platform.isLinux) {
      yield _windowsControlsKey;
    }
  }

  Widget _buildAnimatedSlot({
    required String slotKey,
    required bool isVisible,
    required Widget Function() builder,
  }) {
    final Widget child = isVisible
        ? KeyedSubtree(key: ValueKey<String>('slot_$slotKey'), child: builder())
        : SizedBox.shrink(key: ValueKey<String>('slot_${slotKey}_empty'));

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.centerLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
        opacity: isVisible ? 1 : 0,
        child: child,
      ),
    );
  }

  bool _isPointWithinInteractiveRegion(Offset globalPosition) {
    for (final key in _activeInteractiveRegionKeys) {
      final context = key.currentContext;
      if (context == null) {
        continue;
      }
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) {
        continue;
      }
      final Offset local = renderObject.globalToLocal(globalPosition);
      final Size size = renderObject.size;
      if (local.dx >= 0 &&
          local.dy >= 0 &&
          local.dx <= size.width &&
          local.dy <= size.height) {
        return true;
      }
    }
    return false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }

    final bool startedOverInteractive = _isPointWithinInteractiveRegion(
      event.position,
    );
    _pointerStartedOverInteractive = startedOverInteractive;
    if (startedOverInteractive) {
      _pendingDoubleClick = false;
      _suppressDragUntilUp = false;
      _initialPointerPosition = null;
      return;
    }

    _initialPointerPosition = event.position;

    final previousTime = _lastPrimaryTapUpTime;
    final previousGlobalPosition = _lastPrimaryTapUpGlobalPosition;

    _dragRequested = false;

    final bool isPotentialDoubleClick =
        previousTime != null &&
        previousGlobalPosition != null &&
        (event.timeStamp - previousTime) <= _doubleClickTimeout &&
        (event.position - previousGlobalPosition).distanceSquared <=
            _doubleClickDistanceSquared;

    _pendingDoubleClick = isPotentialDoubleClick;
    _suppressDragUntilUp = isPotentialDoubleClick;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_suppressDragUntilUp ||
        _dragRequested ||
        _pointerStartedOverInteractive ||
        event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }

    final startPosition = _initialPointerPosition;
    if (startPosition != null) {
      final double distanceSquared =
          (event.position - startPosition).distanceSquared;
      if (distanceSquared < _dragInitiateDistanceSquared) {
        return;
      }
    }

    _dragRequested = true;
    _pendingDoubleClick = false;
    _initialPointerPosition = null;
    unawaited(windowManager.startDragging());
  }

  void _resetPointerState() {
    _dragRequested = false;
    _suppressDragUntilUp = false;
    _pointerStartedOverInteractive = false;
    _initialPointerPosition = null;
    _pendingDoubleClick = false;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      _resetPointerState();
      return;
    }

    if (_pointerStartedOverInteractive) {
      _pendingDoubleClick = false;
      _lastPrimaryTapUpTime = null;
      _lastPrimaryTapUpGlobalPosition = null;
      _resetPointerState();
      return;
    }

    final bool isDoubleClick =
        _pendingDoubleClick &&
        !_dragRequested &&
        _lastPrimaryTapUpTime != null &&
        _lastPrimaryTapUpGlobalPosition != null &&
        (event.timeStamp - _lastPrimaryTapUpTime!) <= _doubleClickTimeout &&
        (event.position - _lastPrimaryTapUpGlobalPosition!).distanceSquared <=
            _doubleClickDistanceSquared;

    if (isDoubleClick) {
      unawaited(_toggleWindowMaximize());
    }

    if (_dragRequested) {
      _lastPrimaryTapUpTime = null;
      _lastPrimaryTapUpGlobalPosition = null;
    } else {
      _lastPrimaryTapUpTime = event.timeStamp;
      _lastPrimaryTapUpGlobalPosition = event.position;
    }
    _pendingDoubleClick = false;

    _resetPointerState();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _resetPointerState();
  }

  Future<void> _toggleWindowMaximize() async {
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
    final bool isWindowsStyle = Platform.isWindows || Platform.isLinux;
    final double actionButtonSize = isWindowsStyle ? 32 : 36;
    final double primaryIconSize = isWindowsStyle ? 16 : 22;
    final double backIconSize = isWindowsStyle ? 14 : 20;
    final double actionSpacing = isWindowsStyle ? 4 : 8;

    void handleInteraction() => widget.onInteract?.call();

    final frostedColor = theme.canvasColor.withOpacity(
      isDarkMode ? 0.35 : 0.36,
    );

    final headerContent = ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: widget.height,
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
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
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
                            TextSpan(text: widget.sectionLabel),
                            if (widget.statsLabel != null) ...[
                              TextSpan(text: '  |  '),
                              TextSpan(text: widget.statsLabel),
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
                    padding: EdgeInsets.only(right: isWindowsStyle ? 8 : 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _wrapInteractiveRegion(
                            key: _searchRegionKey,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 100,
                                maxWidth: 320,
                              ),
                              child: LibrarySearchField(
                                query: widget.searchQuery,
                                onQueryChanged: widget.onSearchChanged,
                                onPreviewChanged: widget.onSearchPreviewChanged,
                                suggestions: widget.searchSuggestions,
                                onSuggestionSelected:
                                    widget.onSuggestionSelected,
                                onInteract: handleInteraction,
                              ),
                            ),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'back',
                            isVisible: widget.showBackButton,
                            builder: () => _HeaderTooltip(
                              useMacStyle: !isWindowsStyle,
                              message: widget.backTooltip,
                              child: _wrapInteractiveRegion(
                                key: _backButtonKey,
                                child: _HeaderIconButton(
                                  baseColor: widget.canNavigateBack
                                      ? textColor.withOpacity(0.72)
                                      : textColor.withOpacity(0.24),
                                  hoverColor: textColor,
                                  icon: CupertinoIcons.left_chevron,
                                  onPressed: widget.canNavigateBack
                                      ? () {
                                          handleInteraction();
                                          widget.onNavigateBack?.call();
                                        }
                                      : null,
                                  size: actionButtonSize,
                                  iconSize: backIconSize,
                                  enabled: widget.canNavigateBack,
                                  isWindowsStyle: isWindowsStyle,
                                ),
                              ),
                            ),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'sort',
                            isVisible:
                                widget.showBackButton &&
                                widget.sortMode != null &&
                                widget.onSortModeChanged != null,
                            builder: () => Padding(
                              padding: EdgeInsets.only(left: actionSpacing),
                              child: _HeaderTooltip(
                                useMacStyle: !isWindowsStyle,
                                message: context.l10n.glassHeaderSortTooltip,
                                child: _wrapInteractiveRegion(
                                  key: _sortButtonKey,
                                  child: _SortModeButton(
                                    sortMode: widget.sortMode!,
                                    onSortModeChanged: (mode) {
                                      handleInteraction();
                                      widget.onSortModeChanged!(mode);
                                    },
                                    textColor: textColor,
                                    enabled: widget.canNavigateBack,
                                    size: actionButtonSize,
                                    iconSize: backIconSize,
                                    isWindowsStyle: isWindowsStyle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'back_spacing',
                            isVisible: widget.showBackButton,
                            builder: () => SizedBox(width: actionSpacing),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'logout_leading',
                            isVisible:
                                !widget.showBackButton &&
                                widget.showLogoutButton,
                            builder: () => SizedBox(width: actionSpacing),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'logout',
                            isVisible: widget.showLogoutButton,
                            builder: () => _HeaderTooltip(
                              useMacStyle: !isWindowsStyle,
                              message: widget.logoutTooltip,
                              child: _wrapInteractiveRegion(
                                key: _logoutButtonKey,
                                child: _HeaderIconButton(
                                  baseColor: widget.logoutEnabled
                                      ? textColor.withOpacity(0.72)
                                      : textColor.withOpacity(0.24),
                                  hoverColor: textColor,
                                  size: actionButtonSize,
                                  iconSize: primaryIconSize,
                                  icon: CupertinoIcons.square_arrow_left,
                                  onPressed: widget.logoutEnabled
                                      ? () {
                                          handleInteraction();
                                          widget.onLogout?.call();
                                        }
                                      : null,
                                  enabled: widget.logoutEnabled,
                                  isWindowsStyle: isWindowsStyle,
                                ),
                              ),
                            ),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'logout_spacing',
                            isVisible:
                                widget.showLogoutButton &&
                                (widget.showCreatePlaylistButton ||
                                    widget.showSelectFolderButton),
                            builder: () => SizedBox(width: actionSpacing),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'create_playlist',
                            isVisible: widget.showCreatePlaylistButton,
                            builder: () => _HeaderTooltip(
                              useMacStyle: !isWindowsStyle,
                              message:
                                  context.l10n.glassHeaderCreatePlaylistTooltip,
                              child: _wrapInteractiveRegion(
                                key: _createPlaylistButtonKey,
                                child: _HeaderIconButton(
                                  baseColor: textColor.withOpacity(0.72),
                                  hoverColor: textColor,
                                  size: actionButtonSize,
                                  iconSize: primaryIconSize,
                                  icon: CupertinoIcons.add,
                                  onPressed: () {
                                    handleInteraction();
                                    widget.onCreatePlaylist();
                                  },
                                  isWindowsStyle: isWindowsStyle,
                                ),
                              ),
                            ),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'create_playlist_spacing',
                            isVisible:
                                widget.showCreatePlaylistButton &&
                                widget.showSelectFolderButton,
                            builder: () => SizedBox(width: actionSpacing),
                          ),
                          _buildAnimatedSlot(
                            slotKey: 'select_folder',
                            isVisible: widget.showSelectFolderButton,
                            builder: () => _HeaderTooltip(
                              useMacStyle: !isWindowsStyle,
                              message:
                                  context.l10n.glassHeaderSelectFolderTooltip,
                              child: _wrapInteractiveRegion(
                                key: _selectFolderButtonKey,
                                child: _HeaderIconButton(
                                  baseColor: textColor.withOpacity(0.72),
                                  hoverColor: textColor,
                                  size: actionButtonSize,
                                  iconSize: primaryIconSize,
                                  icon: CupertinoIcons.folder,
                                  onPressed: () {
                                    handleInteraction();
                                    widget.onSelectMusicFolder();
                                  },
                                  isWindowsStyle: isWindowsStyle,
                                ),
                              ),
                            ),
                          ),
                          if (isWindowsStyle) ...[
                            const SizedBox(width: 8),
                            _VerticalSeparator(
                              color: textColor.withOpacity(0.18),
                            ),
                            const SizedBox(width: 8),
                            _wrapInteractiveRegion(
                              key: _windowsControlsKey,
                              child: _WindowsWindowControls(
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return headerContent;
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
      return MacosTooltip(message: message, child: child);
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
          tooltip: context.l10n.windowMinimize,
          iconType: _CaptionIconType.minimize,
          foregroundColor: _iconColor,
          onPressed: () => windowManager.minimize(),
        ),
        const SizedBox(width: 4),
        _WindowsCaptionButton(
          tooltip: _isMaximized
              ? context.l10n.windowRestore
              : context.l10n.windowMaximize,
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
          tooltip: context.l10n.windowClose,
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
        title: context.l10n.glassHeaderSortTitle,
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
            label: context.l10n.actionCancel,
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
                  ? Icon(
                      _getSortIcon(),
                      size: widget.iconSize,
                      color: targetColor,
                    )
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
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
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
