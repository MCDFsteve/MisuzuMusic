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
        final header = _buildMobileHeader(
          context,
          sectionLabel,
          statsLabel,
          neteaseState,
        );
        final theme = Theme.of(context);
        final bool isDarkMode = theme.brightness == Brightness.dark;
        final Color fallbackColor = theme.colorScheme.surface;
        final Color overlayTop = isDarkMode
            ? Colors.black.withValues(alpha: 0.58)
            : Colors.white.withValues(alpha: 0.72);
        final Color overlayBottom = isDarkMode
            ? Colors.black.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.65);

        final mainContent = KeyedSubtree(
          key: const ValueKey<String>('mobile_content_stack'),
          child: _buildMainContent(),
        );

        final double navReservedHeight = math.max(
          0,
          _mobileNowPlayingBottomPadding(context) - 20,
        );
        final double lyricsBottomInset =
            navReservedHeight + _HomePageContentState._mobileNowPlayingBarHeight;

        final layeredBody = SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
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
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [overlayTop, overlayBottom],
                  ),
                ),
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

        return AdaptiveScaffold(
          body: bodyWithFocusDismiss,
          bottomNavigationBar: AdaptiveBottomNavigationBar(
            items: _mobileDestinations,
            selectedIndex: _selectedIndex,
            onTap: _handleNavigationChange,
            selectedItemColor: const Color(0xFF1B66FF),
          ),
        );
      },
    );
  }

  double _mobileNowPlayingBottomPadding(BuildContext context) {
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final bool isiOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final double navBarHeight = isiOS
        ? 88.0
        : isAndroid
            ? 72.0
            : 64.0;
    const double visualGap = 12.0;
    return navBarHeight + safeAreaBottom + visualGap;
  }

  Widget _buildMobileHeader(
    BuildContext context,
    String sectionLabel,
    String? statsLabel,
    NeteaseState neteaseState,
  ) {
    final bool supportsSearch = _selectedIndex != 4;
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.8,
    );
    final bodySmall = theme.textTheme.bodySmall;
    final headingStyle = theme.textTheme.titleMedium ??
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

  Widget? _buildMobileLeading() {
    VoidCallback? onPressed;

    switch (_selectedIndex) {
      case 0:
        if (_hasActiveDetail) {
          onPressed = _clearActiveDetail;
        } else if (_musicLibraryCanNavigateBack) {
          onPressed = () => _musicLibraryViewKey.currentState?.exitToOverview();
        }
        break;
      case 1:
        if (_playlistsCanNavigateBack) {
          onPressed = () => _playlistsViewKey.currentState?.exitToOverview();
        }
        break;
      case 2:
        if (_neteaseCanNavigateBack) {
          onPressed = () => _neteaseViewKey.currentState?.exitToOverview();
        }
        break;
      default:
        onPressed = null;
    }

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

  void _handleMobileGlobalPointerDown(PointerDownEvent event) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) {
      return;
    }

    final focusContext = primaryFocus.context;
    final renderObject = focusContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize && renderObject.attached) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final Rect focusBounds = topLeft & renderObject.size;
      if (focusBounds.contains(event.position)) {
        return;
      }
    }

    primaryFocus.unfocus();
  }
}
