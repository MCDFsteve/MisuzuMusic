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
        final searchHeader = _buildMobileSearchHeader(context, statsLabel);
        final actions = _buildMobileAppBarActions(neteaseState);
        final leading = _buildMobileLeading();
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
        final double contentBottomPadding =
            navReservedHeight + _HomePageContentState._mobileNowPlayingBarHeight;

        final layeredBody = SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(bottom: contentBottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (searchHeader != null) searchHeader,
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
              ),
              Positioned.fill(
                child: _LyricsOverlaySwitcher(
                  isVisible: _lyricsVisible,
                  builder: () => _buildLyricsOverlay(
                    isMac: false,
                    bottomSafeInset: contentBottomPadding,
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

        return AdaptiveScaffold(
          appBar: AdaptiveAppBar(
            title: sectionLabel,
            useNativeToolbar: false,
            leading: leading,
            actions: actions.isEmpty ? null : actions,
          ),
          body: themedBody,
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

  Widget? _buildMobileSearchHeader(BuildContext context, String? statsLabel) {
    final bool supportsSearch = _selectedIndex != 4;
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.8,
    );
    final bodySmall = theme.textTheme.bodySmall;

    if (!supportsSearch) {
      if (statsLabel == null) {
        return null;
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(
          statsLabel,
          locale: const Locale('zh-Hans', 'zh'),
          style: bodySmall?.copyWith(color: secondaryColor),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
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
      onPressed: onPressed,
      child: const Icon(CupertinoIcons.chevron_left, size: 22),
    );
  }
}
