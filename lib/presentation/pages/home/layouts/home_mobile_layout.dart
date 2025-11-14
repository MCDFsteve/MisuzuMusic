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
        final appBar = _buildMobileAppBar(
          sectionLabel,
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

        final header = _buildMobileHeader(
          context,
          statsLabel,
        );

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

        return AdaptiveScaffold(
          appBar: appBar,
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

  AdaptiveAppBar _buildMobileAppBar(
    String sectionLabel,
    NeteaseState neteaseState,
  ) {
    final actions = _buildMobileAppBarActions(neteaseState);
    final leading = _buildMobileLeading();
    return AdaptiveAppBar(
      title: sectionLabel,
      leading: leading,
      actions: actions.isEmpty ? null : actions,
      useNativeToolbar: true,
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    String? statsLabel,
  ) {
    final bool supportsSearch = _selectedIndex != 4;
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.8,
    );
    final bodySmall = theme.textTheme.bodySmall;

    final children = <Widget>[];

    if (supportsSearch) {
      children.add(
        LibrarySearchField(
          query: _searchQuery,
          onQueryChanged: _onSearchQueryChanged,
          onPreviewChanged: _handleSearchPreviewChanged,
          suggestions: _searchSuggestions,
          onSuggestionSelected: _handleSearchSuggestionTapped,
          onInteract: _dismissLyricsOverlay,
        ),
      );
    }

    if (statsLabel != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        Text(
          statsLabel,
          locale: const Locale('zh-Hans', 'zh'),
          style: bodySmall?.copyWith(color: secondaryColor),
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox(height: 12);
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
            _neteaseViewController.prepareForLogout();
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
          onPressed = _musicLibraryViewController.exitToOverview;
        }
        break;
      case 1:
        if (_playlistsCanNavigateBack) {
          onPressed = _playlistsViewController.exitToOverview;
        }
        break;
      case 2:
        if (_neteaseCanNavigateBack) {
          onPressed = _neteaseViewController.exitToOverview;
        }
        break;
      default:
        onPressed = null;
    }

    if (onPressed == null) {
      return null;
    }

    return _AdaptiveLeadingButton(onPressed: onPressed);
  }
}

class _AdaptiveLeadingButton extends StatelessWidget {
  const _AdaptiveLeadingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;

    if (PlatformInfo.isIOS) {
      return AdaptiveButton.child(
        onPressed: onPressed,
        style: AdaptiveButtonStyle.plain,
        size: AdaptiveButtonSize.small,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minSize: const Size(32, 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.chevron_left, size: 18, color: color),
            const SizedBox(width: 2),
            Text(
              '返回',
              locale: const Locale('zh-Hans', 'zh'),
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ) ??
                  TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return AdaptiveButton.icon(
      onPressed: onPressed,
      icon: Icons.arrow_back_rounded,
      iconColor: color,
      style: AdaptiveButtonStyle.plain,
      size: AdaptiveButtonSize.small,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      minSize: const Size(40, 40),
    );
  }
}
