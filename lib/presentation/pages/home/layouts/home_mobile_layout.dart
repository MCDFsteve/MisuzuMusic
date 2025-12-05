part of 'package:misuzu_music/presentation/pages/home_page.dart';

extension _HomePageMobileLayout on _HomePageContentState {
  Widget _buildMobileLayout() {
    return BlocConsumer<PlayerBloc, PlayerBlocState>(
      buildWhen: _shouldRebuildForPlayerState,
      listener: (context, playerState) => _handlePlayerStateChange(playerState),
      builder: (context, playerState) {
        final artworkSource = _currentArtworkSources(playerState);
        final libraryState = context.watch<MusicLibraryBloc>().state;
        final neteaseState = context.watch<NeteaseCubit>().state;
        final sectionLabel = _currentSectionLabel(_selectedIndex);
        final String? statsLabel = _selectedIndex == 2
            ? _composeNeteaseStatsLabel(neteaseState)
            : _composeHeaderStatsLabel(libraryState);
        final currentTrack = _playerTrack(playerState);
        final mediaQuery = MediaQuery.of(context);
        final double statusBarInset = mediaQuery.padding.top;
        final header = _buildMobileHeader(
          context,
          sectionLabel,
          statsLabel,
          neteaseState,
          blurBackground: _lyricsVisible,
        );
        final Widget headerSection = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _lyricsVisible
              ? const SizedBox.shrink(key: ValueKey('mobile_header_hidden'))
              : KeyedSubtree(
                  key: const ValueKey('mobile_header_visible'),
                  child: Padding(
                    padding: EdgeInsets.only(top: statusBarInset),
                    child: header,
                  ),
                ),
        );
        final theme = Theme.of(context);
        final bool isDarkMode = theme.brightness == Brightness.dark;
        final Color fallbackColor = theme.colorScheme.surface;

        final mainContent = KeyedSubtree(
          key: const ValueKey<String>('mobile_content_stack'),
          child: _buildMainContent(),
        );

        final bool useLegacyCupertinoTabBar =
            defaultTargetPlatform == TargetPlatform.iOS &&
            !PlatformInfo.isIOS26OrHigher();
        final double navReservedPadding = _mobileNowPlayingBottomPadding(
          context,
          useLegacyCupertinoTabBar: useLegacyCupertinoTabBar,
        );
        final double navOverlapHeight = useLegacyCupertinoTabBar
            ? _FrostedLegacyCupertinoTabBar.barHeight
            : 20.0;
        final double navReservedHeight = math.max(
          0,
          navReservedPadding - navOverlapHeight,
        );
        final double lyricsBottomInset =
            navReservedHeight +
            _HomePageContentState._mobileNowPlayingBarHeight;

        final layeredBody = SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerSection,
                    Expanded(
                      child: IgnorePointer(
                        ignoring: _lyricsVisible,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeInOut,
                          opacity: _lyricsVisible ? 0 : 1,
                          child: mainContent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: _LyricsOverlaySwitcher(
                  isVisible: _lyricsVisible,
                  builder: () => _buildLyricsOverlay(
                    isMac: false,
                    bottomSafeInset: lyricsBottomInset,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: navReservedHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MobileNowPlayingBar(
                    playerState: playerState,
                    isLyricsActive: _lyricsVisible,
                    onArtworkTap: currentTrack == null
                        ? null
                        : () => _toggleLyrics(playerState),
                  ),
                ),
              ),
            ],
          ),
        );

        final Widget backgroundStack = Stack(
          children: [
            Positioned.fill(
              child: _ArtworkBackgroundSwitcher(
                sources: artworkSource,
                isDarkMode: isDarkMode,
                fallbackColor: fallbackColor,
              ),
            ),
            Positioned.fill(child: layeredBody),
          ],
        );

        final macosThemeData = Theme.of(context).brightness == Brightness.dark
            ? MacosThemeData.dark()
            : MacosThemeData.light();

        final themedBody = MacosTheme(
          data: macosThemeData,
          child: Material(color: Colors.transparent, child: backgroundStack),
        );

        final bodyWithFocusDismiss = Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerDown: _handleMobileGlobalPointerDown,
          child: themedBody,
        );

        final VoidCallback? backAction =
            defaultTargetPlatform == TargetPlatform.iOS
            ? _resolveMobileBackAction()
            : null;

        Widget interactiveBody = bodyWithFocusDismiss;
        if (backAction != null) {
          interactiveBody = _IOSSwipeBackDetector(
            onBack: backAction,
            child: interactiveBody,
          );
        }

        final visibleSectionIndices = _mobileDestinationSectionIndices;
        final navSelectedIndex = _mobileNavigationSelectedIndex(
          visibleSectionIndices,
        );
        final navItems = _mobileDestinations;
        void handleNavigationTap(int visibleIndex) {
          final targetSection = visibleSectionIndices[visibleIndex];
          _handleNavigationChange(targetSection);
        }

        Widget scaffoldBody = interactiveBody;
        AdaptiveBottomNavigationBar? scaffoldBottomBar;

        if (useLegacyCupertinoTabBar) {
          scaffoldBody = Stack(
            children: [
              Positioned.fill(child: interactiveBody),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _FrostedLegacyCupertinoTabBar(
                  currentIndex: navSelectedIndex,
                  isDarkMode: isDarkMode,
                  items: _buildLegacyCupertinoNavItems(navItems),
                  onTap: handleNavigationTap,
                ),
              ),
            ],
          );
        } else {
          scaffoldBottomBar = AdaptiveBottomNavigationBar(
            items: navItems,
            selectedIndex: navSelectedIndex,
            onTap: handleNavigationTap,
            selectedItemColor: const Color(0xFF1B66FF),
          );
        }

        return AdaptiveScaffold(
          body: scaffoldBody,
          bottomNavigationBar: scaffoldBottomBar,
        );
      },
    );
  }

  List<BottomNavigationBarItem> _buildLegacyCupertinoNavItems(
    List<AdaptiveNavigationDestination> destinations,
  ) {
    return destinations
        .map(
          (destination) => BottomNavigationBarItem(
            icon: Icon(_resolveNavigationIcon(destination.icon), size: 26),
            activeIcon: Icon(
              _resolveNavigationIcon(
                destination.selectedIcon ?? destination.icon,
              ),
              size: 26,
            ),
            label: destination.label,
          ),
        )
        .toList(growable: false);
  }

  IconData _resolveNavigationIcon(dynamic icon) {
    if (icon is IconData) {
      return icon;
    }
    if (icon is String) {
      switch (icon) {
        case 'music.note.list':
          return CupertinoIcons.music_note_list;
        case 'square.stack.3d.up':
          return CupertinoIcons.square_stack_3d_up;
        case 'cloud':
          return CupertinoIcons.cloud;
        case 'music.note':
          return CupertinoIcons.music_note;
        case 'gearshape':
          return CupertinoIcons.settings;
      }
    }
    return CupertinoIcons.circle;
  }

  double _mobileNowPlayingBottomPadding(
    BuildContext context, {
    bool useLegacyCupertinoTabBar = false,
  }) {
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final bool isiOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final double navBarHeight = isiOS
        ? (useLegacyCupertinoTabBar
              ? _FrostedLegacyCupertinoTabBar.barHeight
              : 20.0)
        : isAndroid
        ? 72.0
        : 64.0;
    final double visualGap = useLegacyCupertinoTabBar ? 80.0 : 12.0;
    return navBarHeight + safeAreaBottom + visualGap;
  }

  Widget _buildMobileHeader(
    BuildContext context,
    String sectionLabel,
    String? statsLabel,
    NeteaseState neteaseState, {
    bool blurBackground = false,
  }) {
    final bool supportsSearch = _selectedIndex != 4;
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.8,
    );
    final bodySmall = theme.textTheme.bodySmall;
    final headingStyle =
        theme.textTheme.titleMedium ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
    final leading = _buildMobileLeading();
    final actionButtons = _buildMobileActionButtons(neteaseState);

    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            SizedBox(height: 36, width: 36, child: leading),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              sectionLabel,
              locale: const Locale('zh-Hans', 'zh'),
              style: headingStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          for (int i = 0; i < actionButtons.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            actionButtons[i],
          ],
        ],
      ),
    ];

    if (supportsSearch) {
      children.addAll([
        const SizedBox(height: 12),
        LibrarySearchField(
          query: _searchQuery,
          onQueryChanged: _onSearchQueryChanged,
          onPreviewChanged: _handleSearchPreviewChanged,
          suggestions: _searchSuggestions,
          onSuggestionSelected: _handleSearchSuggestionTapped,
          onInteract: _dismissLyricsOverlay,
          useFrostedStyle: blurBackground,
        ),
        if (statsLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            statsLabel,
            locale: const Locale('zh-Hans', 'zh'),
            style: bodySmall?.copyWith(color: secondaryColor),
          ),
        ],
      ]);
    } else if (statsLabel != null) {
      children.addAll([
        const SizedBox(height: 8),
        Text(
          statsLabel,
          locale: const Locale('zh-Hans', 'zh'),
          style: bodySmall?.copyWith(color: secondaryColor),
        ),
      ]);
    }

    final double bottomPadding = supportsSearch ? 12 : 8;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  List<Widget> _buildMobileActionButtons(NeteaseState neteaseState) {
    final actions = _buildMobileAppBarActions(neteaseState);
    if (actions.isEmpty) {
      return const <Widget>[];
    }

    return actions
        .map(
          (action) => CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minSize: 32,
            onPressed: action.onPressed,
            child: action.icon != null
                ? Icon(action.icon, size: 22)
                : (action.title != null
                      ? Text(
                          action.title!,
                          locale: const Locale('zh-Hans', 'zh'),
                        )
                      : const Icon(Icons.more_horiz, size: 20)),
          ),
        )
        .toList(growable: false);
  }

  List<AdaptiveAppBarAction> _buildMobileAppBarActions(
    NeteaseState neteaseState,
  ) {
    final actions = <AdaptiveAppBarAction>[];

    if (_selectedIndex == 0) {
      final libraryState = context.read<MusicLibraryBloc>().state;
      if (libraryState is MusicLibraryLoaded) {
        actions.add(
          AdaptiveAppBarAction(
            iosSymbol: 'arrow.up.arrow.down.circle',
            icon: CupertinoIcons.arrow_up_arrow_down_circle,
            onPressed: _showMusicLibrarySortOptions,
          ),
        );
      }
      actions.add(
        AdaptiveAppBarAction(
          iosSymbol: 'folder.badge.plus',
          icon: CupertinoIcons.folder_badge_plus,
          onPressed: _selectMusicFolder,
        ),
      );
    }

    if (_selectedIndex == 1) {
      actions.add(
        AdaptiveAppBarAction(
          iosSymbol: 'arrow.up.arrow.down.circle',
          icon: CupertinoIcons.arrow_up_arrow_down_circle,
          onPressed: _showPlaylistSortOptions,
        ),
      );
      actions.add(
        AdaptiveAppBarAction(
          iosSymbol: 'plus.circle',
          icon: CupertinoIcons.add_circled,
          onPressed: _handleCreatePlaylistFromHeader,
        ),
      );
    }

    if (_selectedIndex == 2 &&
        neteaseState.hasSession &&
        !neteaseState.isSubmittingCookie) {
      actions.add(
        AdaptiveAppBarAction(
          iosSymbol: 'rectangle.portrait.and.arrow.right',
          icon: CupertinoIcons.square_arrow_right,
          onPressed: () {
            _neteaseViewKey.currentState?.prepareForLogout();
            context.read<NeteaseCubit>().logout();
          },
        ),
      );
    }

    return actions;
  }

  Future<void> _showMusicLibrarySortOptions() async {
    final libraryState = context.read<MusicLibraryBloc>().state;
    if (libraryState is! MusicLibraryLoaded) {
      return;
    }
    final currentMode = libraryState.sortMode;

    final selectedMode = await showPlaylistModalDialog<TrackSortMode>(
      context: context,
      builder: (dialogContext) => _PlaylistModalScaffold(
        title: context.l10n.glassHeaderSortTitle,
        maxWidth: 360,
        contentSpacing: 18,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: TrackSortMode.values
              .map(
                (mode) => _MobileSortModeTile(
                  mode: mode,
                  isSelected: mode == currentMode,
                  onSelected: () => Navigator.of(dialogContext).pop(mode),
                ),
              )
              .toList(growable: false),
        ),
        actions: [
          _SheetActionButton.secondary(
            label: context.l10n.actionCancel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );

    if (selectedMode != null && selectedMode != currentMode) {
      context.read<MusicLibraryBloc>().add(ChangeSortModeEvent(selectedMode));
    }
  }

  Future<void> _showPlaylistSortOptions() async {
    final playlistsCubit = context.read<PlaylistsCubit>();
    final currentMode = playlistsCubit.state.sortMode;

    final selectedMode = await showPlaylistModalDialog<TrackSortMode>(
      context: context,
      builder: (dialogContext) => _PlaylistModalScaffold(
        title: context.l10n.glassHeaderSortTitle,
        maxWidth: 360,
        contentSpacing: 18,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: TrackSortMode.values
              .map(
                (mode) => _MobileSortModeTile(
                  mode: mode,
                  isSelected: mode == currentMode,
                  onSelected: () => Navigator.of(dialogContext).pop(mode),
                ),
              )
              .toList(growable: false),
        ),
        actions: [
          _SheetActionButton.secondary(
            label: context.l10n.actionCancel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );

    if (selectedMode != null && selectedMode != currentMode) {
      playlistsCubit.changeSortMode(selectedMode);
    }
  }

  Widget? _buildMobileLeading() {
    final onPressed = _resolveMobileBackAction();
    if (onPressed == null) {
      return null;
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 32,
      onPressed: onPressed,
      child: const Icon(CupertinoIcons.chevron_left, size: 22),
    );
  }

  VoidCallback? _resolveMobileBackAction() {
    switch (_selectedIndex) {
      case 0:
        if (_hasActiveDetail) {
          return _clearActiveDetail;
        }
        if (_musicLibraryCanNavigateBack) {
          return () => _musicLibraryViewKey.currentState?.exitToOverview();
        }
        break;
      case 1:
        if (_playlistsCanNavigateBack) {
          return () => _playlistsViewKey.currentState?.exitToOverview();
        }
        break;
      case 2:
        if (_neteaseCanNavigateBack) {
          return () => _neteaseViewKey.currentState?.exitToOverview();
        }
        break;
      default:
        break;
    }
    return null;
  }

  void _handleMobileGlobalPointerDown(PointerDownEvent event) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) {
      return;
    }

    final focusContext = primaryFocus.context;
    final renderObject = focusContext?.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.attached) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final Rect focusBounds = topLeft & renderObject.size;
      if (focusBounds.contains(event.position)) {
        return;
      }
    }

    primaryFocus.unfocus();
  }
}

class _MobileSortModeTile extends StatelessWidget {
  const _MobileSortModeTile({
    required this.mode,
    required this.isSelected,
    required this.onSelected,
  });

  final TrackSortMode mode;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    final background = isSelected
        ? theme.colorScheme.primary.withOpacity(0.12)
        : theme.colorScheme.surface.withOpacity(0.35);
    final borderColor = isSelected
        ? theme.colorScheme.primary.withOpacity(0.45)
        : theme.dividerColor.withOpacity(0.2);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                mode.localizedLabel(context.l10n),
                style:
                    theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: baseColor,
                    ) ??
                    TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: baseColor,
                    ),
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 18,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _IOSSwipeBackDetector extends StatefulWidget {
  const _IOSSwipeBackDetector({
    required this.child,
    required this.onBack,
    this.edgeWidth = 28,
    this.triggerOffset = 56,
  });

  final Widget child;
  final VoidCallback onBack;
  final double edgeWidth;
  final double triggerOffset;

  @override
  State<_IOSSwipeBackDetector> createState() => _IOSSwipeBackDetectorState();
}

class _IOSSwipeBackDetectorState extends State<_IOSSwipeBackDetector> {
  double _dragProgress = 0;
  bool _isTracking = false;

  void _handleDragStart(DragStartDetails details) {
    _dragProgress = 0;
    _isTracking = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isTracking) {
      return;
    }

    _dragProgress += details.primaryDelta ?? 0;
    if (_dragProgress > widget.triggerOffset) {
      _isTracking = false;
      widget.onBack();
    } else if (_dragProgress < -8) {
      _isTracking = false;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _isTracking = false;
  }

  void _handleDragCancel() {
    _isTracking = false;
  }

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _EdgeSwipeGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EdgeSwipeGestureRecognizer>(
              () => _EdgeSwipeGestureRecognizer(
                edgeWidth: widget.edgeWidth,
                gestureSettings: gestureSettings,
              ),
              (recognizer) {
                recognizer
                  ..onStart = _handleDragStart
                  ..onUpdate = _handleDragUpdate
                  ..onEnd = _handleDragEnd
                  ..onCancel = _handleDragCancel;
              },
            ),
      },
      child: widget.child,
    );
  }
}

class _EdgeSwipeGestureRecognizer extends HorizontalDragGestureRecognizer {
  _EdgeSwipeGestureRecognizer({
    required this.edgeWidth,
    DeviceGestureSettings? gestureSettings,
  }) {
    super.gestureSettings = gestureSettings;
  }

  final double edgeWidth;

  @override
  void addPointer(PointerDownEvent event) {
    if (event.position.dx <= edgeWidth) {
      super.addPointer(event);
    }
  }
}

class _FrostedLegacyCupertinoTabBar extends StatelessWidget {
  const _FrostedLegacyCupertinoTabBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.isDarkMode,
  });

  final int currentIndex;
  final List<BottomNavigationBarItem> items;
  final ValueChanged<int> onTap;
  final bool isDarkMode;

  static const double barHeight = 55.0;
  static const double _blurSigma = 20.0;

  @override
  Widget build(BuildContext context) {
    final Color glassColor = isDarkMode
        ? Colors.black.withOpacity(0.35)
        : Colors.white.withOpacity(0.75);
    final Color borderColor = (isDarkMode ? Colors.white : Colors.black)
        .withOpacity(0.1);

    final tabBar = CupertinoTabBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
      height: barHeight,
      border: Border(top: BorderSide(color: borderColor, width: 0.8)),
      backgroundColor: Colors.transparent,
      activeColor: const Color(0xFF1B66FF),
      inactiveColor: CupertinoColors.inactiveGray,
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(color: glassColor),
          child: tabBar,
        ),
      ),
    );
  }
}
