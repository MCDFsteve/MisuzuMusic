part of 'package:misuzu_music/presentation/pages/home_page.dart';

extension _HomePageDesktopLayout on _HomePageContentState {
  Widget _buildMacOSLayout() {
    return BlocConsumer<PlayerBloc, PlayerBlocState>(
      buildWhen: _shouldRebuildForPlayerState,
      listener: (context, playerState) => _handlePlayerStateChange(playerState),
      builder: (context, playerState) {
        final artworkSource = _currentArtworkSources(playerState);
        final currentTrack = _playerTrack(playerState);
        final queueSnapshot = _queueSnapshotFromState(playerState);
        const headerHeight = 76.0;
        final sectionLabel = _currentSectionLabel(_selectedIndex);
        final MusicLibraryState libraryState = context
            .watch<MusicLibraryBloc>()
            .state;
        final NeteaseState neteaseState = context.watch<NeteaseCubit>().state;

        final l10n = context.l10n;
        final desktopSections = _desktopSectionIndices;
        final desktopNavIndex = _navigationSelectedIndex(desktopSections);
        final String? statsLabel = _selectedIndex == 2
            ? _composeNeteaseStatsLabel(neteaseState)
            : _composeHeaderStatsLabel(libraryState);
        bool showBackButton = false;
        bool canNavigateBack = false;
        VoidCallback? onNavigateBack;
        String backTooltip = l10n.homeBackTooltipDefault;
        TrackSortMode? sortMode;
        ValueChanged<TrackSortMode>? onSortModeChanged;
        bool showLogoutButton = false;
        bool logoutEnabled = false;
        VoidCallback? onLogout;
        String logoutTooltip = l10n.homeLogoutTooltipDefault;
        final playlistsViewState = _playlistsViewKey.currentState;
        final musicLibraryViewState = _musicLibraryViewKey.currentState;

        switch (_selectedIndex) {
          case 0:
            showBackButton = true;
            if (_hasActiveDetail) {
              canNavigateBack = true;
              backTooltip = l10n.homeBackTooltipLibrary;
              onNavigateBack = _clearActiveDetail;
            } else {
              canNavigateBack = _musicLibraryCanNavigateBack;
              backTooltip = l10n.homeBackTooltipLibrary;
              if (canNavigateBack) {
                onNavigateBack = () => musicLibraryViewState?.exitToOverview();
                final musicState = context.read<MusicLibraryBloc>().state;
                if (musicState is MusicLibraryLoaded) {
                  sortMode = musicState.sortMode;
                  onSortModeChanged = (mode) {
                    context.read<MusicLibraryBloc>().add(
                      ChangeSortModeEvent(mode),
                    );
                  };
                }
              }
            }
            break;
          case 1:
            showBackButton = true;
            canNavigateBack = _playlistsCanNavigateBack;
            backTooltip = l10n.homeBackTooltipPlaylists;
            if (canNavigateBack) {
              onNavigateBack = () => playlistsViewState?.exitToOverview();
              sortMode = context.read<PlaylistsCubit>().state.sortMode;
              onSortModeChanged = (mode) {
                context.read<PlaylistsCubit>().changeSortMode(mode);
              };
            }
            break;
          case 2:
            showBackButton = true;
            canNavigateBack = _neteaseCanNavigateBack;
            backTooltip = l10n.homeBackTooltipNetease;
            if (canNavigateBack) {
              onNavigateBack = () =>
                  _neteaseViewKey.currentState?.exitToOverview();
            }
            if (neteaseState.hasSession) {
              showLogoutButton = true;
              logoutEnabled = !neteaseState.isSubmittingCookie;
              logoutTooltip = l10n.homeLogoutTooltipNetease;
              onLogout = () {
                _neteaseViewKey.currentState?.prepareForLogout();
                context.read<NeteaseCubit>().logout();
              };
            }
            break;
          default:
            showBackButton = false;
        }
        final bool showCreatePlaylistButton = _selectedIndex == 1;
        final bool showSelectFolderButton = _selectedIndex == 0;

        return MacosWindow(
          titleBar: null,
          child: MacosScaffold(
            toolBar: null,
            children: [
              ContentArea(
                builder: (context, scrollController) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: _ArtworkBackgroundSwitcher(
                          sources: artworkSource,
                          isDarkMode:
                              MacosTheme.of(context).brightness ==
                              Brightness.dark,
                          fallbackColor: MacosTheme.of(context).canvasColor,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) => _dismissLyricsOverlay(),
                            child: _MacOSNavigationPane(
                              width: _navigationWidth,
                              collapsed: _navigationWidth <= 112,
                              items: _macNavigationItems(desktopSections),
                              selectedIndex: desktopNavIndex,
                              onSelect: (index) {
                                _dismissLyricsOverlay();
                                final targetSection = desktopSections[index];
                                _handleNavigationChange(targetSection);
                              },
                              onResize: (width) {
                                _dismissLyricsOverlay();
                                setState(() {
                                  final clamped = width
                                      .clamp(
                                        _HomePageContentState._navMinWidth,
                                        _HomePageContentState._navMaxWidth,
                                      )
                                      .toDouble();
                                  _navigationWidth = clamped;
                                });
                              },
                              enabled: true,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _MacOSGlassHeader(
                                  height: headerHeight,
                                  sectionLabel: sectionLabel,
                                  statsLabel: statsLabel,
                                  searchQuery: _searchQuery,
                                  onSearchChanged: _onSearchQueryChanged,
                                  onSearchPreviewChanged:
                                      _handleSearchPreviewChanged,
                                  searchSuggestions: _searchSuggestions,
                                  onSuggestionSelected:
                                      _handleSearchSuggestionTapped,
                                  onSelectMusicFolder: _selectMusicFolder,
                                  onCreatePlaylist:
                                      _handleCreatePlaylistFromHeader,
                                  showBackButton: showBackButton,
                                  canNavigateBack: canNavigateBack,
                                  onNavigateBack: onNavigateBack,
                                  backTooltip: backTooltip,
                                  sortMode: sortMode,
                                  onSortModeChanged: onSortModeChanged,
                                  showCreatePlaylistButton:
                                      showCreatePlaylistButton,
                                  showSelectFolderButton:
                                      showSelectFolderButton,
                                  showLogoutButton: showLogoutButton,
                                  logoutEnabled: logoutEnabled,
                                  onLogout: onLogout,
                                  logoutTooltip: logoutTooltip,
                                  onInteract: _dismissLyricsOverlay,
                                ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          ignoring: _lyricsVisible,
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 260,
                                            ),
                                            curve: Curves.easeInOut,
                                            opacity: _lyricsVisible ? 0 : 1,
                                            child: KeyedSubtree(
                                              key: const ValueKey<String>(
                                                'mac_content_stack',
                                              ),
                                              child: _buildMainContent(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: _LyricsOverlaySwitcher(
                                          isVisible: _lyricsVisible,
                                          builder: () =>
                                              _buildLyricsOverlay(isMac: true),
                                        ),
                                      ),
                                      _PlaybackQueueOverlay(
                                        visible: _queuePanelVisible,
                                        snapshot: queueSnapshot,
                                        onDismiss: _dismissQueueOverlay,
                                        onSelectTrack: (index) =>
                                            _playQueueEntry(
                                              queueSnapshot.queue,
                                              index,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                MacOSPlayerControlBar(
                                  onArtworkTap: currentTrack == null
                                      ? null
                                      : () => _toggleLyrics(playerState),
                                  isLyricsActive: _lyricsVisible,
                                  onQueuePressed: () {
                                    _dismissLyricsOverlay();
                                    setState(() {
                                      _queuePanelVisible = !_queuePanelVisible;
                                    });
                                  },
                                  isQueueVisible: _queuePanelVisible,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
