part of 'package:misuzu_music/presentation/pages/home_page.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  int _selectedIndex = 0;
  double _navigationWidth = 200;

  static const double _navMinWidth = 80;
  static const double _navMaxWidth = 220;
  static const List<AdaptiveNavigationDestination> _iosMobileDestinations = [
    AdaptiveNavigationDestination(icon: 'music.note.list', label: '音乐库'),
    AdaptiveNavigationDestination(icon: 'square.stack.3d.up', label: '歌单'),
    AdaptiveNavigationDestination(icon: 'cloud', label: '网络'),
    AdaptiveNavigationDestination(icon: 'music.note', label: '播放队列'),
    AdaptiveNavigationDestination(icon: 'gearshape', label: '设置'),
  ];

  static const List<AdaptiveNavigationDestination> _defaultMobileDestinations =
      [
        AdaptiveNavigationDestination(
          icon: CupertinoIcons.music_note_list,
          label: '音乐库',
        ),
        AdaptiveNavigationDestination(
          icon: CupertinoIcons.square_stack_3d_up,
          label: '歌单',
        ),
        AdaptiveNavigationDestination(icon: CupertinoIcons.cloud, label: '网络'),
        AdaptiveNavigationDestination(
          icon: CupertinoIcons.music_note,
          label: '播放队列',
        ),
        AdaptiveNavigationDestination(
          icon: CupertinoIcons.settings,
          label: '设置',
        ),
      ];

  List<AdaptiveNavigationDestination> get _mobileDestinations {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosMobileDestinations
        : _defaultMobileDestinations;
  }

  String _searchQuery = '';
  String _activeSearchQuery = '';
  List<LibrarySearchSuggestion> _searchSuggestions = const [];
  Timer? _searchDebounce;
  bool _lyricsVisible = false;
  Track? _lyricsActiveTrack;
  MusicLibraryLoaded? _cachedLibraryState;
  Artist? _activeArtistDetail;
  List<Track> _activeArtistTracks = const [];
  Album? _activeAlbumDetail;
  List<Track> _activeAlbumTracks = const [];
  final FocusNode _shortcutFocusNode = FocusNode();
  final GlobalKey<_PlaylistsViewState> _playlistsViewKey =
      GlobalKey<_PlaylistsViewState>();
  final GlobalKey<_MusicLibraryViewState> _musicLibraryViewKey =
      GlobalKey<_MusicLibraryViewState>();
  final GlobalKey<_NeteaseViewState> _neteaseViewKey =
      GlobalKey<_NeteaseViewState>();
  bool _musicLibraryCanNavigateBack = false;
  bool _playlistsCanNavigateBack = false;
  bool _neteaseCanNavigateBack = false;
  late final VoidCallback _focusManagerListener;

  @override
  void initState() {
    super.initState();
    _focusManagerListener = () {
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null && mounted && !_shortcutFocusNode.hasFocus) {
        _shortcutFocusNode.requestFocus();
      }
    };
    FocusManager.instance.addListener(_focusManagerListener);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    FocusManager.instance.removeListener(_focusManagerListener);
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      skipTraversal: true,
      focusNode: _shortcutFocusNode,
      child: BlocListener<MusicLibraryBloc, MusicLibraryState>(
        listener: (context, state) {
          if (state is MusicLibraryLoaded) {
            _cachedLibraryState = state;
          } else if (state is MusicLibraryScanComplete) {
            _showScanCompleteDialog(
              context,
              state.tracksAdded,
              webDavSource: state.webDavSource,
            );
          } else if (state is MusicLibraryError) {
            _showErrorDialog(context, state.message);
          }
        },
        child: prefersMacLikeUi() ? _buildMacOSLayout() : _buildMobileLayout(),
      ),
    );
  }

  bool get _hasActiveDetail =>
      _activeArtistDetail != null || _activeAlbumDetail != null;

  void _clearActiveDetail() {
    if (!_hasActiveDetail) {
      return;
    }
    setState(() {
      _activeArtistDetail = null;
      _activeArtistTracks = const [];
      _activeAlbumDetail = null;
      _activeAlbumTracks = const [];
    });
  }

  void _showArtistDetail(Artist artist, List<Track> tracks) {
    _searchDebounce?.cancel();
    _musicLibraryViewKey.currentState?.exitToOverview();
    setState(() {
      _selectedIndex = 0;
      _activeArtistDetail = artist;
      _activeArtistTracks = tracks;
      _activeAlbumDetail = null;
      _activeAlbumTracks = const [];
      _searchSuggestions = const [];
      _searchQuery = '';
      _activeSearchQuery = '';
    });
  }

  void _showAlbumDetail(Album album, List<Track> tracks) {
    _searchDebounce?.cancel();
    _musicLibraryViewKey.currentState?.exitToOverview();
    setState(() {
      _selectedIndex = 0;
      _activeAlbumDetail = album;
      _activeAlbumTracks = tracks;
      _activeArtistDetail = null;
      _activeArtistTracks = const [];
      _searchSuggestions = const [];
      _searchQuery = '';
      _activeSearchQuery = '';
    });
  }

  Future<void> _handleCreatePlaylistFromHeader() async {
    await _startPlaylistCreationFlow(openAfterCreate: true);
  }

  Future<String?> _startPlaylistCreationFlow({
    Track? initialTrack,
    required bool openAfterCreate,
  }) async {
    final playlistsCubit = context.read<PlaylistsCubit>();

    final mode = await showPlaylistCreationModeDialog(context);
    if (!mounted || mode == null) {
      return null;
    }

    if (mode == PlaylistCreationMode.local) {
      final newId = await showPlaylistCreationSheet(
        context,
        track: initialTrack,
      );
      if (!mounted || newId == null) {
        return null;
      }

      await playlistsCubit.ensurePlaylistTracks(newId, force: true);
      final hasTracks =
          playlistsCubit.state.playlistTracks[newId]?.isNotEmpty ?? false;
      if (openAfterCreate && hasTracks) {
        _navigateToPlaylistView(newId);
      }
      return newId;
    }

    final cloudId = await showCloudPlaylistIdDialog(
      context,
      title: '拉取云歌单',
      confirmLabel: '拉取',
      invalidMessage: playlistsCubit.cloudIdRuleDescription,
      description: '输入云端歌单的 ID，至少 5 位，支持字母、数字和下划线。',
      validator: playlistsCubit.isValidCloudPlaylistId,
    );
    if (!mounted || cloudId == null) {
      return null;
    }

    String? playlistId;
    String successMessage = '已拉取云歌单（ID: $cloudId）';
    String? errorMessage;

    await _runWithBlockingProgress(
      title: '正在拉取云歌单...',
      task: () async {
        final result = await playlistsCubit.importPlaylistFromCloud(cloudId);
        final (id, error) = result;
        playlistId = id;
        errorMessage = error;
        if (errorMessage != null || playlistId == null) {
          return;
        }
        if (initialTrack != null) {
          final added = await playlistsCubit.addTrackToPlaylist(
            playlistId!,
            initialTrack,
          );
          if (added) {
            successMessage = '已拉取云歌单并添加当前歌曲';
          } else {
            successMessage = '云歌单已拉取，歌曲已存在于该歌单';
          }
        }
      },
    );

    if (!mounted) {
      return playlistId;
    }

    if (errorMessage != null) {
      _showOperationSnackBar(errorMessage!, isError: true);
      return null;
    }
    if (playlistId == null) {
      return null;
    }

    _showOperationSnackBar(successMessage);

    if (openAfterCreate) {
      await playlistsCubit.ensurePlaylistTracks(playlistId!, force: true);
      final hasTracks =
          playlistsCubit.state.playlistTracks[playlistId!]?.isNotEmpty ?? false;
      if (!hasTracks) {
        return playlistId;
      }
      _navigateToPlaylistView(playlistId!);
    }
    return playlistId;
  }

  Future<void> _runWithBlockingProgress({
    required String title,
    required Future<void> Function() task,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showPlaylistModalDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PlaylistModalScaffold(
        title: title,
        body: const SizedBox(
          height: 80,
          child: Center(child: ProgressCircle()),
        ),
        actions: const [],
        maxWidth: 240,
        contentSpacing: 20,
        actionsSpacing: 0,
      ),
    );

    await Future<void>.delayed(Duration.zero);

    try {
      await task();
    } finally {
      if (mounted && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  void _navigateToPlaylistView(String playlistId) {
    if (_selectedIndex != 1) {
      setState(() {
        _selectedIndex = 1;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playlistsViewKey.currentState?.openPlaylistById(playlistId);
    });
  }

  void _showOperationSnackBar(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(locale: Locale("zh-Hans", "zh"), message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showPlaylistActionDialog({
    required String title,
    required String message,
    bool isError = false,
    String confirmLabel = '好的',
  }) async {
    if (!mounted) {
      return;
    }

    final icon = isError
        ? CupertinoIcons.exclamationmark_triangle_fill
        : CupertinoIcons.check_mark_circled_solid;
    final iconColor = isError
        ? MacosColors.systemRedColor
        : MacosColors.systemGreenColor;

    await showPlaylistModalDialog<void>(
      context: context,
      builder: (_) => _PlaylistModalScaffold(
        title: title,
        maxWidth: 360,
        contentSpacing: 16,
        actionsSpacing: 20,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MacosIcon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, locale: const Locale('zh-Hans', 'zh')),
            ),
          ],
        ),
        actions: [
          _SheetActionButton.primary(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMacOSLayout() {
    return BlocConsumer<PlayerBloc, PlayerBlocState>(
      buildWhen: _shouldRebuildForPlayerState,
      listener: (context, playerState) => _handlePlayerStateChange(playerState),
      builder: (context, playerState) {
        final artworkSource = _currentArtworkSources(playerState);
        final currentTrack = _playerTrack(playerState);
        const headerHeight = 76.0;
        final sectionLabel = _currentSectionLabel(_selectedIndex);
        final MusicLibraryState libraryState = context
            .watch<MusicLibraryBloc>()
            .state;
        final NeteaseState neteaseState = context.watch<NeteaseCubit>().state;

        final String? statsLabel = _selectedIndex == 2
            ? _composeNeteaseStatsLabel(neteaseState)
            : _composeHeaderStatsLabel(libraryState);
        bool showBackButton = false;
        bool canNavigateBack = false;
        VoidCallback? onNavigateBack;
        String backTooltip = '返回上一层';
        TrackSortMode? sortMode;
        ValueChanged<TrackSortMode>? onSortModeChanged;
        bool showLogoutButton = false;
        bool logoutEnabled = false;
        VoidCallback? onLogout;
        String logoutTooltip = '退出登录';
        final playlistsViewState = _playlistsViewKey.currentState;
        final musicLibraryViewState = _musicLibraryViewKey.currentState;

        switch (_selectedIndex) {
          case 0:
            showBackButton = true;
            if (_hasActiveDetail) {
              canNavigateBack = true;
              backTooltip = '返回音乐库';
              onNavigateBack = _clearActiveDetail;
            } else {
              canNavigateBack = _musicLibraryCanNavigateBack;
              backTooltip = '返回音乐库';
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
            backTooltip = '返回歌单列表';
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
            backTooltip = '返回网络歌曲歌单列表';
            if (canNavigateBack) {
              onNavigateBack = () =>
                  _neteaseViewKey.currentState?.exitToOverview();
            }
            if (neteaseState.hasSession) {
              showLogoutButton = true;
              logoutEnabled = !neteaseState.isSubmittingCookie;
              logoutTooltip = '退出网络歌曲登录';
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
                              selectedIndex: _selectedIndex,
                              onSelect: (index) {
                                _dismissLyricsOverlay();
                                _handleNavigationChange(index);
                              },
                              onResize: (width) {
                                _dismissLyricsOverlay();
                                setState(() {
                                  _navigationWidth = width.clamp(
                                    _navMinWidth,
                                    _navMaxWidth,
                                  );
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
                                    ],
                                  ),
                                ),
                                MacOSPlayerControlBar(
                                  onArtworkTap: currentTrack == null
                                      ? null
                                      : () => _toggleLyrics(playerState),
                                  isLyricsActive: _lyricsVisible,
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

        final double bottomReservedHeight = _mobileNowPlayingBottomPadding(
          context,
        );

        final layeredBody = SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomReservedHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: _lyricsVisible,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOut,
                            opacity: _lyricsVisible ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (searchHeader != null) searchHeader,
                                Expanded(child: mainContent),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: _LyricsOverlaySwitcher(
                          isVisible: _lyricsVisible,
                          builder: () => _buildLyricsOverlay(isMac: false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MobileNowPlayingBar(
                  playerState: playerState,
                  isLyricsActive: _lyricsVisible,
                  onArtworkTap: currentTrack == null
                      ? null
                      : () => _toggleLyrics(playerState),
                ),
              ],
            ),
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

  void _handlePlayerStateChange(PlayerBlocState playerState) {
    bool shouldHideLyrics = false;
    Track? nextTrack = _playerTrack(playerState);

    if (playerState is PlayerInitial || playerState is PlayerError) {
      shouldHideLyrics = true;
      nextTrack = null;
    } else if (playerState is PlayerStopped) {
      final hasQueuedTracks = playerState.queue.isNotEmpty;
      if (!hasQueuedTracks) {
        shouldHideLyrics = true;
        nextTrack = null;
      }
    }

    if (!mounted) {
      return;
    }

    // 保持当前歌词组件状态，避免切歌过渡时触发 dispose 导致桌面歌词被关闭。
    if (!shouldHideLyrics && nextTrack == null && _lyricsVisible) {
      nextTrack = _lyricsActiveTrack;
    }

    final bool needsHideUpdate = shouldHideLyrics && _lyricsVisible;
    final bool trackChanged = _lyricsActiveTrack != nextTrack;

    if (!needsHideUpdate && !trackChanged) {
      return;
    }

    setState(() {
      if (needsHideUpdate) {
        _lyricsVisible = false;
      }
      _lyricsActiveTrack = nextTrack;
    });
  }

  Widget _buildMainContent() {
    final pages = _buildSectionPages();
    final int safeIndex = _selectedIndex.clamp(0, pages.length - 1);

    return _AnimatedPageStack(activeIndex: safeIndex, children: pages);
  }

  List<Widget> _buildSectionPages() {
    final libraryView = MusicLibraryView(
      key: _musicLibraryViewKey,
      onAddToPlaylist: _handleAddTrackToPlaylist,
      onDetailStateChanged: (value) {
        if (_musicLibraryCanNavigateBack != value) {
          setState(() {
            _musicLibraryCanNavigateBack = value;
          });
        }
      },
      onViewArtist: _viewTrackArtist,
      onViewAlbum: _viewTrackAlbum,
    );

    final detailContent = _hasActiveDetail
        ? _buildDetailContent()
        : const SizedBox.shrink();

    final librarySection = _AnimatedPageStack(
      activeIndex: _hasActiveDetail ? 1 : 0,
      children: [libraryView, detailContent],
    );

    final playlistsSection = PlaylistsView(
      key: _playlistsViewKey,
      onAddToPlaylist: _handleAddTrackToPlaylist,
      onDetailStateChanged: (value) {
        if (_playlistsCanNavigateBack != value) {
          setState(() {
            _playlistsCanNavigateBack = value;
          });
        }
      },
      searchQuery: _activeSearchQuery,
      onViewArtist: _viewTrackArtist,
      onViewAlbum: _viewTrackAlbum,
    );

    final neteaseSection = NeteaseView(
      key: _neteaseViewKey,
      onAddToPlaylist: _handleAddTrackToPlaylist,
      onDetailStateChanged: (value) {
        if (_neteaseCanNavigateBack != value) {
          setState(() {
            _neteaseCanNavigateBack = value;
          });
        }
      },
      searchQuery: _activeSearchQuery,
      onViewArtist: _viewTrackArtist,
      onViewAlbum: _viewTrackAlbum,
    );

    final playlistSection = PlaylistView(
      key: ValueKey(_activeSearchQuery),
      searchQuery: _activeSearchQuery,
      onAddToPlaylist: _handleAddTrackToPlaylist,
      onViewArtist: _viewTrackArtist,
      onViewAlbum: _viewTrackAlbum,
    );

    final pages = <Widget>[
      librarySection,
      playlistsSection,
      neteaseSection,
      playlistSection,
      const SettingsView(),
    ];

    return pages;
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

  Widget _buildDetailContent() {
    if (_activeArtistDetail != null) {
      return ArtistDetailView(
        artist: _activeArtistDetail!,
        tracks: _activeArtistTracks,
        onAddToPlaylist: (track) => _handleAddTrackToPlaylist(track),
        onAddAllToPlaylist: _handleAddTracksToPlaylist,
        onViewArtist: _viewTrackArtist,
        onViewAlbum: _viewTrackAlbum,
      );
    }
    if (_activeAlbumDetail != null) {
      return AlbumDetailView(
        album: _activeAlbumDetail!,
        tracks: _activeAlbumTracks,
        onAddToPlaylist: (track) => _handleAddTrackToPlaylist(track),
        onAddAllToPlaylist: _handleAddTracksToPlaylist,
        onViewArtist: _viewTrackArtist,
        onViewAlbum: _viewTrackAlbum,
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleAddTrackToPlaylist(Track track) async {
    final playlistsCubit = context.read<PlaylistsCubit>();

    final result = await showPlaylistModalDialog<Object?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => BlocProvider.value(
        value: playlistsCubit,
        child: _PlaylistSelectionDialog(initialTracks: [track]),
      ),
    );

    if (!mounted) return;

    if (result == _PlaylistSelectionDialog.createSignal) {
      final newId = await _startPlaylistCreationFlow(
        initialTrack: track,
        openAfterCreate: false,
      );
      if (!mounted) return;
      if (newId != null) {
        await playlistsCubit.ensurePlaylistTracks(newId, force: true);
      }
    } else if (result is _PlaylistSelectionResult) {
      await playlistsCubit.ensurePlaylistTracks(result.playlistId, force: true);
    }
  }

  Future<void> _handleAddTracksToPlaylist(List<Track> tracks) async {
    if (tracks.isEmpty) {
      await _showPlaylistActionDialog(
        title: '添加到歌单',
        message: '当前没有可添加的歌曲',
        isError: true,
      );
      return;
    }

    final playlistsCubit = context.read<PlaylistsCubit>();

    final selection = await showPlaylistModalDialog<Object?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => BlocProvider.value(
        value: playlistsCubit,
        child: _PlaylistSelectionDialog(initialTracks: tracks),
      ),
    );

    if (!mounted) {
      return;
    }

    if (selection == _PlaylistSelectionDialog.createSignal) {
      final newId = await _startPlaylistCreationFlow(
        initialTrack: tracks.first,
        openAfterCreate: false,
      );
      if (!mounted || newId == null) {
        return;
      }

      final remaining = tracks.skip(1).toList(growable: false);
      PlaylistBulkAddResult? bulkResult;
      if (remaining.isNotEmpty) {
        bulkResult = await playlistsCubit.addTracksToPlaylist(newId, remaining);
        if (bulkResult.hasError) {
          await _showPlaylistActionDialog(
            title: '添加到歌单',
            message: bulkResult.errorMessage ?? '添加到歌单失败',
            isError: true,
          );
          return;
        }
      }

      await playlistsCubit.ensurePlaylistTracks(newId, force: true);

      final playlistName = _playlistNameById(newId) ?? '歌单';
      final added = 1 + (bulkResult?.addedCount ?? 0);
      final skipped = bulkResult?.skippedCount ?? 0;
      await _showPlaylistActionDialog(
        title: '添加到歌单',
        message: _formatBulkAddMessage(playlistName, added, skipped),
        isError: false,
      );
      return;
    }

    if (selection is _PlaylistSelectionResult) {
      await playlistsCubit.ensurePlaylistTracks(
        selection.playlistId,
        force: true,
      );

      final playlistName = _playlistNameById(selection.playlistId) ?? '歌单';

      if (selection.addedCount > 0) {
        await _showPlaylistActionDialog(
          title: '添加到歌单',
          message: _formatBulkAddMessage(
            playlistName,
            selection.addedCount,
            selection.skippedCount,
          ),
        );
      } else {
        await _showPlaylistActionDialog(
          title: '添加到歌单',
          message: '所选歌曲已存在于歌单',
          isError: true,
        );
      }
    }
  }

  String? _playlistNameById(String playlistId) {
    final playlists = context.read<PlaylistsCubit>().state.playlists;
    for (final playlist in playlists) {
      if (playlist.id == playlistId) {
        return playlist.name;
      }
    }
    return null;
  }

  String _formatBulkAddMessage(String playlistName, int added, int skipped) {
    final base = '已添加 $added 首歌曲到歌单 “$playlistName”';
    if (skipped <= 0) {
      return base;
    }
    return '$base（$skipped 首已存在）';
  }

  MusicLibraryLoaded? _effectiveLibraryState() {
    final blocState = context.read<MusicLibraryBloc>().state;
    if (blocState is MusicLibraryLoaded) {
      return blocState;
    }
    return _cachedLibraryState;
  }

  List<Track> _normalizedLibraryTracks(MusicLibraryLoaded library) {
    return library.allTracks
        .map((track) => applyDisplayInfo(track, deriveTrackDisplayInfo(track)))
        .toList(growable: false);
  }

  void _viewTrackArtist(Track track) {
    final name = track.artist.trim();
    if (name.isEmpty) {
      _showOperationSnackBar('该歌曲缺少歌手信息', isError: true);
      return;
    }

    final library = _effectiveLibraryState();
    if (library == null) {
      _showOperationSnackBar('音乐库尚未加载完成', isError: true);
      return;
    }

    final lowerName = name.toLowerCase();
    final normalizedTracks = _normalizedLibraryTracks(library);
    final artistTracks = normalizedTracks
        .where((t) => t.artist.trim().toLowerCase() == lowerName)
        .toList();
    if (artistTracks.isEmpty) {
      _showOperationSnackBar('音乐库中未找到该歌手', isError: true);
      return;
    }

    final artworkTrack = artistTracks.lastWhere(
      (t) => t.artworkPath != null && t.artworkPath!.isNotEmpty,
      orElse: () => artistTracks.first,
    );
    final artist = Artist(
      name: name,
      trackCount: artistTracks.length,
      artworkPath: artworkTrack.artworkPath,
    );

    _showArtistDetail(artist, artistTracks);
  }

  void _viewTrackAlbum(Track track) {
    final albumName = track.album.trim();
    final artistName = track.artist.trim();
    if (albumName.isEmpty) {
      _showOperationSnackBar('该歌曲缺少专辑信息', isError: true);
      return;
    }

    final library = _effectiveLibraryState();
    if (library == null) {
      _showOperationSnackBar('音乐库尚未加载完成', isError: true);
      return;
    }

    final lowerAlbum = albumName.toLowerCase();
    final lowerArtist = artistName.toLowerCase();
    final normalizedTracks = _normalizedLibraryTracks(library);
    final albumTracks = normalizedTracks
        .where(
          (t) =>
              t.album.trim().toLowerCase() == lowerAlbum &&
              t.artist.trim().toLowerCase() == lowerArtist,
        )
        .toList();

    if (albumTracks.isEmpty) {
      _showOperationSnackBar('音乐库中未找到该专辑', isError: true);
      return;
    }

    final sortedTracks = List<Track>.from(albumTracks)
      ..sort((a, b) {
        final trackCompare = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
        if (trackCompare != 0) {
          return trackCompare;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    final Duration totalDuration = sortedTracks.fold<Duration>(
      Duration.zero,
      (prev, item) => prev + item.duration,
    );
    final artworkTrack = sortedTracks.lastWhere(
      (t) => t.artworkPath != null && t.artworkPath!.isNotEmpty,
      orElse: () => sortedTracks.first,
    );
    final safeArtist = artistName.isEmpty ? 'Unknown Artist' : artistName;
    final album = Album(
      title: albumName,
      artist: safeArtist,
      trackCount: sortedTracks.length,
      year: sortedTracks.first.year,
      artworkPath: artworkTrack.artworkPath,
      totalDuration: totalDuration,
    );

    _showAlbumDetail(album, sortedTracks);
  }

  bool _shouldRebuildForPlayerState(
    PlayerBlocState previous,
    PlayerBlocState current,
  ) {
    if (identical(previous, current)) {
      return false;
    }
    if (previous.runtimeType != current.runtimeType) {
      return true;
    }

    if (previous is PlayerPlaying && current is PlayerPlaying) {
      final sameSnapshot = _arePlaybackContextsEqual(
        previousTrack: previous.track,
        currentTrack: current.track,
        previousDuration: previous.duration,
        currentDuration: current.duration,
        previousVolume: previous.volume,
        currentVolume: current.volume,
        previousMode: previous.playMode,
        currentMode: current.playMode,
        previousQueue: previous.queue,
        currentQueue: current.queue,
        previousIndex: previous.currentIndex,
        currentIndex: current.currentIndex,
      );
      if (sameSnapshot && previous.position != current.position) {
        return false;
      }
      return !sameSnapshot;
    }

    if (previous is PlayerPaused && current is PlayerPaused) {
      final sameSnapshot = _arePlaybackContextsEqual(
        previousTrack: previous.track,
        currentTrack: current.track,
        previousDuration: previous.duration,
        currentDuration: current.duration,
        previousVolume: previous.volume,
        currentVolume: current.volume,
        previousMode: previous.playMode,
        currentMode: current.playMode,
        previousQueue: previous.queue,
        currentQueue: current.queue,
        previousIndex: previous.currentIndex,
        currentIndex: current.currentIndex,
      );
      if (sameSnapshot && previous.position != current.position) {
        return false;
      }
      return !sameSnapshot;
    }

    if (previous is PlayerLoading && current is PlayerLoading) {
      final sameSnapshot = _arePlaybackContextsEqual(
        previousTrack: previous.track,
        currentTrack: current.track,
        previousDuration: previous.duration,
        currentDuration: current.duration,
        previousVolume: previous.volume,
        currentVolume: current.volume,
        previousMode: previous.playMode,
        currentMode: current.playMode,
        previousQueue: previous.queue,
        currentQueue: current.queue,
        previousIndex: previous.currentIndex,
        currentIndex: current.currentIndex,
      );
      if (sameSnapshot && previous.position != current.position) {
        return false;
      }
      return !sameSnapshot;
    }

    return true;
  }

  bool _arePlaybackContextsEqual({
    required Track? previousTrack,
    required Track? currentTrack,
    required Duration previousDuration,
    required Duration currentDuration,
    required double previousVolume,
    required double currentVolume,
    required PlayMode previousMode,
    required PlayMode currentMode,
    required List<Track> previousQueue,
    required List<Track> currentQueue,
    required int previousIndex,
    required int currentIndex,
  }) {
    if (previousTrack != currentTrack) {
      return false;
    }
    if (previousDuration != currentDuration) {
      return false;
    }
    if (previousVolume != currentVolume) {
      return false;
    }
    if (previousMode != currentMode) {
      return false;
    }
    if (previousIndex != currentIndex) {
      return false;
    }
    if (!identical(previousQueue, currentQueue) &&
        !listEquals(previousQueue, currentQueue)) {
      return false;
    }
    return true;
  }

  void navigateToSettingsFromMenu() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = 3;
    });
  }

  void _onSearchQueryChanged(String value) {
    final trimmed = value.trim();
    if (_searchQuery == value && _activeSearchQuery == trimmed) {
      return;
    }

    _searchDebounce?.cancel();

    final suggestions = trimmed.isEmpty
        ? const <LibrarySearchSuggestion>[]
        : _buildSearchSuggestions(trimmed);

    setState(() {
      _searchQuery = value;
      _activeSearchQuery = trimmed;
      _searchSuggestions = suggestions;
    });

    final bloc = context.read<MusicLibraryBloc>();
    if (trimmed.isEmpty) {
      bloc.add(const LoadAllTracks());
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _searchSuggestions = const [];
      });
      context.read<MusicLibraryBloc>().add(SearchTracksEvent(trimmed));
    });
  }

  void _resetSearch() {
    if (_searchQuery.isEmpty && _activeSearchQuery.isEmpty) {
      return;
    }

    _searchDebounce?.cancel();

    setState(() {
      _searchQuery = '';
      _activeSearchQuery = '';
      _searchSuggestions = const [];
      _activeArtistDetail = null;
      _activeArtistTracks = const [];
      _activeAlbumDetail = null;
      _activeAlbumTracks = const [];
    });

    context.read<MusicLibraryBloc>().add(const LoadAllTracks());
  }

  void _handleSearchPreviewChanged(String value) {
    if (!mounted) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      if (_searchSuggestions.isNotEmpty) {
        setState(() => _searchSuggestions = const []);
      }
      return;
    }

    final suggestions = _buildSearchSuggestions(trimmed);
    setState(() => _searchSuggestions = suggestions);
  }

  void _handleSearchSuggestionTapped(LibrarySearchSuggestion suggestion) {
    _searchDebounce?.cancel();
    debugPrint(
      '[HomeContent] Handle suggestion type=${suggestion.type} value=${suggestion.value} payload=${suggestion.payload.runtimeType}',
    );

    switch (suggestion.type) {
      case LibrarySearchSuggestionType.track:
        final track = suggestion.payload is Track
            ? suggestion.payload as Track
            : null;
        if (track == null) {
          _triggerSearchFallback(suggestion.value);
          return;
        }
        debugPrint('[HomeContent] Playing track suggestion ${track.title}');
        _playTrackAndShowLyrics(track);
        break;
      case LibrarySearchSuggestionType.artist:
        final artist = suggestion.payload is Artist
            ? suggestion.payload as Artist
            : null;
        if (artist == null) {
          _triggerSearchFallback(suggestion.value);
          return;
        }
        debugPrint('[HomeContent] Open artist detail ${artist.name}');
        _openArtistDetail(artist);
        break;
      case LibrarySearchSuggestionType.album:
        final album = suggestion.payload is Album
            ? suggestion.payload as Album
            : null;
        if (album == null) {
          _triggerSearchFallback(suggestion.value);
          return;
        }
        debugPrint('[HomeContent] Open album detail ${album.title}');
        _openAlbumDetail(album);
        break;
    }
  }

  void _triggerSearchFallback(String value) {
    final trimmed = value.trim();
    debugPrint('[HomeContent] Fallback search triggered for "$trimmed"');
    setState(() {
      _searchQuery = value;
      _activeSearchQuery = trimmed;
      _searchSuggestions = const [];
    });

    final bloc = context.read<MusicLibraryBloc>();
    if (trimmed.isEmpty) {
      bloc.add(const LoadAllTracks());
    } else {
      bloc.add(SearchTracksEvent(trimmed));
    }
  }

  List<LibrarySearchSuggestion> _buildSearchSuggestions(String query) {
    if (query.isEmpty) {
      return const [];
    }

    final lower = query.toLowerCase();
    final kanaVariants = RomajiTransliterator.toKanaVariants(query);
    final searchTerms = <String>{lower}
      ..addAll(kanaVariants)
      ..addAll(kanaVariants.map((e) => e.toLowerCase()))
      ..removeWhere((element) => element.isEmpty);

    bool matchesField(String text) {
      final lowerText = text.toLowerCase();
      for (final term in searchTerms) {
        if (term.isEmpty) continue;
        if (lowerText.contains(term) || text.contains(term)) {
          return true;
        }
      }
      return false;
    }

    final libraryState = context.read<MusicLibraryBloc>().state;
    final playlistsState = context.read<PlaylistsCubit>().state;
    final neteaseState = context.read<NeteaseCubit>().state;

    final bool onPlaylists = _selectedIndex == 1;
    final bool onNetease = _selectedIndex == 2;
    final bool onLibrary = _selectedIndex == 0;

    final List<LibrarySearchSuggestion> prioritized = [];
    final List<LibrarySearchSuggestion> fallback = [];
    final Set<String> seen = {};

    String suggestionKey(LibrarySearchSuggestion suggestion) {
      final payload = suggestion.payload;
      if (payload is Track) {
        return 'track:${payload.id}';
      }
      if (payload is Artist) {
        return 'artist:${payload.name}';
      }
      if (payload is Album) {
        return 'album:${payload.title}-${payload.artist}';
      }
      return '${suggestion.type.name}:${suggestion.value}:${suggestion.description ?? ''}';
    }

    void addSuggestion(
      LibrarySearchSuggestion suggestion, {
      bool prioritize = false,
    }) {
      final key = suggestionKey(suggestion);
      if (!seen.add(key)) {
        return;
      }
      if (prioritize) {
        prioritized.add(suggestion);
      } else {
        fallback.add(suggestion);
      }
    }

    void addTrackSuggestion(
      Track track, {
      String? description,
      bool prioritize = false,
    }) {
      final display = deriveTrackDisplayInfo(track);
      final normalizedTrack = applyDisplayInfo(track, display);
      addSuggestion(
        LibrarySearchSuggestion(
          value: display.title,
          label: '歌曲：${display.title}',
          description: description ?? '${display.artist} • ${display.album}',
          type: LibrarySearchSuggestionType.track,
          payload: normalizedTrack,
        ),
        prioritize: prioritize,
      );
    }

    void addArtistSuggestion(Artist artist, {bool prioritize = false}) {
      if (isUnknownMetadataValue(artist.name)) {
        return;
      }
      addSuggestion(
        LibrarySearchSuggestion(
          value: artist.name,
          label: '歌手：${artist.name}',
          description: '共 ${artist.trackCount} 首歌曲',
          type: LibrarySearchSuggestionType.artist,
          payload: artist,
        ),
        prioritize: prioritize,
      );
    }

    void addAlbumSuggestion(Album album, {bool prioritize = false}) {
      if (isUnknownMetadataValue(album.title)) {
        return;
      }
      addSuggestion(
        LibrarySearchSuggestion(
          value: album.title,
          label: '专辑：${album.title}',
          description: '${album.artist} • ${album.trackCount} 首',
          type: LibrarySearchSuggestionType.album,
          payload: album,
        ),
        prioritize: prioritize,
      );
    }

    Playlist? findPlaylist(String id) {
      for (final playlist in playlistsState.playlists) {
        if (playlist.id == id) return playlist;
      }
      return null;
    }

    NeteasePlaylist? findNeteasePlaylist(int id) {
      for (final playlist in neteaseState.playlists) {
        if (playlist.id == id) return playlist;
      }
      return null;
    }

    void collectPlaylistTracks({required bool prioritize, int maxResults = 3}) {
      if (playlistsState.playlistTracks.isEmpty) {
        return;
      }
      int added = 0;
      for (final entry in playlistsState.playlistTracks.entries) {
        final playlist = findPlaylist(entry.key);
        final tracks = entry.value;
        if (tracks.isEmpty) continue;
        for (final track in tracks) {
          final display = deriveTrackDisplayInfo(track);
          if (!matchesField(display.title) &&
              !matchesField(display.artist) &&
              !matchesField(display.album)) {
            continue;
          }
          final contextLabel = playlist == null
              ? display.artist
              : '${playlist.name} • ${display.artist}';
          addTrackSuggestion(
            track,
            description: contextLabel,
            prioritize: prioritize,
          );
          added++;
          if (added >= maxResults) {
            return;
          }
        }
      }
    }

    void collectNeteaseTracks({required bool prioritize, int maxResults = 3}) {
      if (neteaseState.playlistTracks.isEmpty) {
        return;
      }
      int added = 0;
      for (final entry in neteaseState.playlistTracks.entries) {
        final playlist = findNeteasePlaylist(entry.key);
        final tracks = entry.value;
        if (tracks.isEmpty) continue;
        for (final track in tracks) {
          final display = deriveTrackDisplayInfo(track);
          if (!matchesField(display.title) &&
              !matchesField(display.artist) &&
              !matchesField(display.album)) {
            continue;
          }
          final contextLabel = playlist == null
              ? display.artist
              : '${playlist.name} • ${display.artist}';
          addTrackSuggestion(
            track,
            description: contextLabel,
            prioritize: prioritize,
          );
          added++;
          if (added >= maxResults) {
            return;
          }
        }
      }
    }

    if (onPlaylists) {
      collectPlaylistTracks(prioritize: true);
    }
    if (onNetease) {
      collectNeteaseTracks(prioritize: true);
    }

    if (libraryState is MusicLibraryLoaded) {
      for (final track in libraryState.tracks) {
        final display = deriveTrackDisplayInfo(track);
        if (matchesField(display.title) ||
            matchesField(display.artist) ||
            matchesField(display.album)) {
          addTrackSuggestion(track, prioritize: onLibrary);
          break;
        }
      }

      for (final artist in libraryState.artists) {
        if (matchesField(artist.name)) {
          addArtistSuggestion(artist, prioritize: onLibrary);
          break;
        }
      }

      for (final album in libraryState.albums) {
        if (matchesField(album.title) || matchesField(album.artist)) {
          addAlbumSuggestion(album, prioritize: onLibrary);
          break;
        }
      }
    }

    if (!onPlaylists) {
      collectPlaylistTracks(prioritize: false, maxResults: 2);
    }
    if (!onNetease) {
      collectNeteaseTracks(prioritize: false, maxResults: 2);
    }

    final results = [...prioritized, ...fallback];
    if (results.length < 3) {
      addSuggestion(
        LibrarySearchSuggestion(
          value: query,
          label: '搜索“$query”',
          description: '在全部内容中继续查找',
          type: LibrarySearchSuggestionType.track,
        ),
        prioritize: results.isEmpty,
      );
      return [...prioritized, ...fallback].take(3).toList(growable: false);
    }

    return results.take(3).toList(growable: false);
  }

  void _playTrackAndShowLyrics(Track track) {
    debugPrint('[HomeContent] _playTrackAndShowLyrics -> ${track.title}');
    _clearActiveDetail();
    final musicState = context.read<MusicLibraryBloc>().state;
    if (musicState is MusicLibraryLoaded) {
      final allTracks = List<Track>.from(musicState.allTracks);
      final foundIndex = allTracks.indexWhere((t) => t.id == track.id);
      if (foundIndex != -1) {
        context.read<PlayerBloc>().add(
          PlayerSetQueue(allTracks, startIndex: foundIndex, autoPlay: true),
        );
      } else {
        context.read<PlayerBloc>().add(PlayerSetQueue([track], startIndex: 0));
      }
    } else {
      context.read<PlayerBloc>().add(PlayerSetQueue([track], startIndex: 0));
    }

    setState(() {
      _lyricsVisible = true;
      _lyricsActiveTrack = track;
      _searchSuggestions = const [];
      _searchQuery = '';
      _activeSearchQuery = '';
    });
  }

  void _openArtistDetail(Artist artist) {
    debugPrint('[HomeContent] _openArtistDetail ${artist.name}');
    final blocState = context.read<MusicLibraryBloc>().state;
    final MusicLibraryLoaded? effectiveState = blocState is MusicLibraryLoaded
        ? blocState
        : _cachedLibraryState;
    if (effectiveState == null) {
      debugPrint(
        '[HomeContent] Artist detail aborted: library not loaded, cache=${_cachedLibraryState != null}',
      );
      return;
    }
    final tracks = effectiveState.tracks
        .where((track) => track.artist == artist.name)
        .toList();
    if (tracks.isEmpty) {
      _showErrorDialog(context, '未找到该歌手的歌曲');
      debugPrint('[HomeContent] Artist detail aborted: no tracks');
      return;
    }
    _showArtistDetail(artist, tracks);
  }

  void _openAlbumDetail(Album album) {
    debugPrint('[HomeContent] _openAlbumDetail ${album.title}');
    final blocState = context.read<MusicLibraryBloc>().state;
    final MusicLibraryLoaded? effectiveState = blocState is MusicLibraryLoaded
        ? blocState
        : _cachedLibraryState;
    if (effectiveState == null) {
      debugPrint(
        '[HomeContent] Album detail aborted: library not loaded, cache=${_cachedLibraryState != null}',
      );
      return;
    }
    final tracks =
        effectiveState.tracks
            .where(
              (track) =>
                  track.album == album.title && track.artist == album.artist,
            )
            .toList()
          ..sort((a, b) {
            final trackCompare = (a.trackNumber ?? 0).compareTo(
              b.trackNumber ?? 0,
            );
            if (trackCompare != 0) {
              return trackCompare;
            }
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });

    if (tracks.isEmpty) {
      _showErrorDialog(context, '未找到该专辑的歌曲');
      debugPrint('[HomeContent] Album detail aborted: no tracks');
      return;
    }
    _showAlbumDetail(album, tracks);
  }

  void _handleNavigationChange(int index) {
    _dismissLyricsOverlay();

    if (_selectedIndex == index) {
      return;
    }

    final bool shouldResetSearch =
        index != 0 &&
        (_searchQuery.isNotEmpty || _activeSearchQuery.isNotEmpty);

    if (shouldResetSearch) {
      _resetSearch();
    }

    setState(() {
      _selectedIndex = index;
    });

    if (!shouldResetSearch && index == 0) {
      context.read<MusicLibraryBloc>().add(const LoadAllTracks());
    }
  }

  String _currentSectionLabel(int index) {
    switch (index) {
      case 0:
        return '音乐库';
      case 1:
        return '歌单';
      case 2:
        return '网络歌曲';
      case 3:
        return '播放列表';
      case 4:
        return '设置';
      default:
        return '音乐库';
    }
  }

  Track? _playerTrack(PlayerBlocState state) {
    if (state is PlayerPlaying) {
      return state.track;
    }
    if (state is PlayerPaused) {
      return state.track;
    }
    if (state is PlayerLoading && state.track != null) {
      return state.track!;
    }
    return null;
  }

  _ArtworkBackgroundSources _currentArtworkSources(PlayerBlocState state) {
    final track = _playerTrack(state);
    if (track == null) {
      return const _ArtworkBackgroundSources();
    }

    String? localArtworkPath = track.artworkPath;
    if (localArtworkPath != null && localArtworkPath.isNotEmpty) {
      final file = File(localArtworkPath);
      if (!file.existsSync()) {
        localArtworkPath = null;
      }
    }

    String? remoteArtworkUrl;
    if (track.sourceType == TrackSourceType.netease) {
      remoteArtworkUrl = track.httpHeaders?['x-netease-cover'];
    } else {
      remoteArtworkUrl = MysteryLibraryConstants.buildArtworkUrl(
        track.httpHeaders,
        thumbnail: false,
      );
    }

    return _ArtworkBackgroundSources(
      localPath: localArtworkPath,
      remoteUrl: remoteArtworkUrl,
    );
  }

  String? _composeHeaderStatsLabel(MusicLibraryState state) {
    if (state is! MusicLibraryLoaded) {
      return null;
    }

    final totalTracks = state.allTracks.length;
    final totalDuration = state.allTracks.fold<Duration>(
      Duration.zero,
      (previousValue, track) => previousValue + track.duration,
    );

    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);

    return '共 $totalTracks 首歌曲 · ${hours} 小时 ${minutes} 分钟';
  }

  String? _composeNeteaseStatsLabel(NeteaseState state) {
    if (!state.hasSession) {
      return '未登录网络歌曲';
    }
    final totalTracks = state.playlists.fold<int>(
      0,
      (sum, playlist) =>
          sum + (playlist.trackCount > 0 ? playlist.trackCount : 0),
    );
    if (totalTracks <= 0) {
      return '网络歌曲歌单';
    }
    return '网络歌曲共 $totalTracks 首歌曲';
  }

  Widget _buildLyricsOverlay({required bool isMac}) {
    final track = _lyricsActiveTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }

    return LyricsOverlay(
      key: ValueKey('lyrics_overlay_${isMac ? 'mac' : 'material'}'),
      initialTrack: track,
      isMac: isMac,
    );
  }

  void _toggleLyrics(PlayerBlocState state) {
    final track = _playerTrack(state);
    if (!_lyricsVisible) {
      if (track == null) {
        return;
      }
      setState(() {
        _lyricsVisible = true;
        _lyricsActiveTrack = track;
      });
      return;
    }

    setState(() {
      _lyricsVisible = false;
    });
  }

  void _dismissLyricsOverlay() {
    if (!_lyricsVisible) {
      return;
    }

    setState(() {
      _lyricsVisible = false;
    });
  }

  Future<void> _selectMusicFolder() async {
    final mode = await showLibraryMountModeDialog(context);
    if (!mounted || mode == null) {
      return;
    }

    switch (mode) {
      case LibraryMountMode.local:
        await _selectLocalFolder();
        break;
      case LibraryMountMode.mystery:
        await _selectMysteryLibrary();
        break;
    }
  }

  Future<void> _selectMysteryLibrary() async {
    final code = await showMysteryCodeDialog(context);
    if (!mounted || code == null) {
      return;
    }

    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      return;
    }

    if (normalizedCode.toLowerCase() != 'irigas') {
      _showErrorDialog(context, '神秘代码不正确');
      return;
    }

    context.read<MusicLibraryBloc>().add(
      MountMysteryLibraryEvent(
        code: normalizedCode,
        baseUri: Uri.parse(MysteryLibraryConstants.defaultBaseUrl),
      ),
    );
  }

  Future<void> _selectLocalFolder() async {
    try {
      print('🎵 开始选择音乐文件夹...');

      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择音乐文件夹',
      );

      if (result != null) {
        print('🎵 选择的文件夹: $result');

        if (mounted) {
          print('🎵 开始扫描音乐文件夹...');
          context.read<MusicLibraryBloc>().add(ScanDirectoryEvent(result));

          if (!prefersMacLikeUi()) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        locale: Locale("zh-Hans", "zh"),
                        '正在扫描文件夹: ${result.split('/').last}',
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 10),
              ),
            );
          }
        }
      } else {
        print('🎵 用户取消了文件夹选择');
      }
    } catch (e) {
      print('❌ 选择文件夹时出错: $e');
      if (mounted) {
        _showErrorDialog(context, e.toString());
      }
    }
  }

  // ignore: unused_element
  Future<void> _selectWebDavFolder() async {
    final connection = await _showWebDavConnectionDialog();
    if (connection == null) {
      debugPrint('🌐 WebDAV: 用户取消连接配置');
      return;
    }
    debugPrint('🌐 WebDAV: 连接成功，开始列举目录 (${connection.baseUrl})');

    final selectedPath = await _showWebDavDirectoryPicker(connection);
    if (selectedPath == null) {
      debugPrint('🌐 WebDAV: 用户取消目录选择');
      return;
    }
    debugPrint('🌐 WebDAV: 选定远程目录 -> $selectedPath');

    final displayName = connection.displayName?.trim();
    final friendlyName = displayName != null && displayName.isNotEmpty
        ? displayName
        : _friendlyNameFromPath(selectedPath);

    final source = WebDavSource(
      id: const Uuid().v4(),
      name: friendlyName,
      baseUrl: connection.baseUrl,
      rootPath: selectedPath,
      username: connection.username?.isEmpty ?? true
          ? null
          : connection.username,
      ignoreTls: connection.ignoreTls,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    debugPrint('🌐 WebDAV: 提交扫描任务');
    context.read<MusicLibraryBloc>().add(
      ScanWebDavDirectoryEvent(source: source, password: connection.password),
    );
  }

  String _friendlyNameFromPath(String path) {
    final normalized = path.trim().isEmpty ? '/' : path;
    if (normalized == '/') {
      return 'WebDAV 音乐库';
    }
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return 'WebDAV 音乐库';
    }
    return segments.last;
  }

  Future<_WebDavConnectionFormResult?> _showWebDavConnectionDialog() {
    if (prefersMacLikeUi()) {
      return showPlaylistModalDialog<_WebDavConnectionFormResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _WebDavConnectionDialog(
          testConnection: sl<TestWebDavConnection>(),
          useModalScaffold: true,
        ),
      );
    }

    return showDialog<_WebDavConnectionFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WebDavConnectionDialog(
        testConnection: sl<TestWebDavConnection>(),
        useModalScaffold: false,
      ),
    );
  }

  Future<String?> _showWebDavDirectoryPicker(
    _WebDavConnectionFormResult connection,
  ) {
    final baseSource = WebDavSource(
      id: 'preview',
      name: connection.displayName ?? 'WebDAV',
      baseUrl: connection.baseUrl,
      rootPath: '/',
      username: connection.username?.isEmpty ?? true
          ? null
          : connection.username,
      ignoreTls: connection.ignoreTls,
    );

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WebDavDirectoryPickerDialog(
        listDirectory: sl<ListWebDavDirectory>(),
        source: baseSource,
        password: connection.password,
      ),
    );
  }

  void _showScanCompleteDialog(
    BuildContext context,
    int tracksAdded, {
    WebDavSource? webDavSource,
  }) {
    final message = webDavSource == null
        ? '添加了 $tracksAdded 首新歌曲'
        : '添加了 $tracksAdded 首新歌曲\n来源: ${webDavSource.name}';
    if (prefersMacLikeUi()) {
      showPlaylistModalDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => PlaylistModalScaffold(
          title: '扫描完成',
          maxWidth: 360,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: CupertinoColors.systemGreen,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                locale: Locale("zh-Hans", "zh"),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SheetActionButton.primary(
              label: '好',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          contentSpacing: 18,
          actionsSpacing: 12,
        ),
      );
    } else {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(locale: Locale("zh-Hans", "zh"), '✅ 扫描完成！$message'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    if (prefersMacLikeUi()) {
      showPlaylistModalDialog<void>(
        context: context,
        builder: (_) => PlaylistModalScaffold(
          title: '发生错误',
          maxWidth: 360,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: CupertinoColors.systemRed,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                locale: Locale("zh-Hans", "zh"),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SheetActionButton.primary(
              label: '好',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          contentSpacing: 18,
          actionsSpacing: 12,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locale: Locale("zh-Hans", "zh"), '❌ $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _ArtworkBackgroundSources {
  const _ArtworkBackgroundSources({this.localPath, this.remoteUrl});

  final String? localPath;
  final String? remoteUrl;

  bool get hasLocal => localPath != null && localPath!.isNotEmpty;

  bool get hasRemote => remoteUrl != null && remoteUrl!.isNotEmpty;

  bool get hasSource => hasLocal || hasRemote;

  String get cacheKey {
    if (hasLocal) {
      return 'local_$localPath';
    }
    if (hasRemote) {
      return 'remote_$remoteUrl';
    }
    return 'none';
  }
}

/// Stack-based page switcher that keeps each page alive while animating
/// transitions between them.
class _AnimatedPageStack extends StatelessWidget {
  const _AnimatedPageStack({
    required this.activeIndex,
    required this.children,
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeInOutCubic,
    this.inactiveSlideAmount = 0.02,
  }) : assert(activeIndex >= 0);

  final int activeIndex;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;
  final double inactiveSlideAmount;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final int clampedIndex = activeIndex.clamp(0, children.length - 1);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: List.generate(children.length, (index) {
        final bool isActive = index == clampedIndex;
        final double horizontalShift;
        if (index < clampedIndex) {
          horizontalShift = -inactiveSlideAmount;
        } else if (index > clampedIndex) {
          horizontalShift = inactiveSlideAmount;
        } else {
          horizontalShift = 0.0;
        }

        return _AnimatedPageStackChild(
          key: ValueKey<int>(index),
          isActive: isActive,
          duration: duration,
          curve: curve,
          inactiveOffset: Offset(horizontalShift, 0),
          child: children[index],
        );
      }),
    );
  }
}

class _AnimatedPageStackChild extends StatelessWidget {
  const _AnimatedPageStackChild({
    super.key,
    required this.isActive,
    required this.duration,
    required this.curve,
    required this.inactiveOffset,
    required this.child,
  });

  final bool isActive;
  final Duration duration;
  final Curve curve;
  final Offset inactiveOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Offset targetOffset = isActive ? Offset.zero : inactiveOffset;

    return IgnorePointer(
      ignoring: !isActive,
      child: AnimatedOpacity(
        opacity: isActive ? 1 : 0,
        duration: duration,
        curve: curve,
        child: AnimatedSlide(
          offset: targetOffset,
          duration: duration,
          curve: curve,
          child: AnimatedScale(
            scale: isActive ? 1 : 0.985,
            duration: duration,
            curve: curve,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ArtworkBackgroundSwitcher extends StatefulWidget {
  const _ArtworkBackgroundSwitcher({
    super.key,
    required this.sources,
    required this.isDarkMode,
    required this.fallbackColor,
  });

  final _ArtworkBackgroundSources sources;
  final bool isDarkMode;
  final Color fallbackColor;

  @override
  State<_ArtworkBackgroundSwitcher> createState() =>
      _ArtworkBackgroundSwitcherState();
}

class _ArtworkBackgroundSwitcherState extends State<_ArtworkBackgroundSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<double> _scaleIn;
  late Animation<double> _scaleOut;

  Widget? _currentChild;
  Widget? _previousChild;
  String _currentKey = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _configureAnimations();
    _setInitialChild();
  }

  @override
  void didUpdateWidget(covariant _ArtworkBackgroundSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _childKey();
    final hasKeyChanged = nextKey != _currentKey;
    final themeChanged = widget.isDarkMode != oldWidget.isDarkMode;

    if (hasKeyChanged) {
      setState(() {
        _previousChild = _currentChild;
        _currentChild = _buildChild();
        _currentKey = nextKey;
      });
      _controller.forward(from: 0);
    } else if (themeChanged) {
      setState(() {
        _currentChild = _buildChild();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: widget.isDarkMode ? Colors.black : widget.fallbackColor,
          ),
          if (_previousChild != null)
            FadeTransition(
              opacity: _fadeOut,
              child: ScaleTransition(scale: _scaleOut, child: _previousChild),
            ),
          if (_currentChild != null)
            FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(scale: _scaleIn, child: _currentChild),
            ),
        ],
      ),
    );
  }

  void _configureAnimations() {
    final fadeCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic.flipped,
    );

    _fadeIn = fadeCurve;
    _fadeOut = ReverseAnimation(fadeCurve);

    _scaleIn = Tween<double>(begin: 0.975, end: 1.0).animate(fadeCurve);
    _scaleOut = Tween<double>(begin: 1.0, end: 1.01).animate(_fadeOut);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _previousChild = null);
      }
    });
  }

  void _setInitialChild() {
    _currentKey = _childKey();
    _currentChild = _buildChild();
    _controller.value = 1.0;
  }

  Widget _buildChild() {
    if (widget.sources.hasSource) {
      return _BlurredArtworkBackground(
        key: ValueKey<String>(widget.sources.cacheKey),
        artworkPath: widget.sources.localPath,
        remoteImageUrl: widget.sources.remoteUrl,
        isDarkMode: widget.isDarkMode,
      );
    }
    return Container(
      key: const ValueKey<String>('default_background'),
      color: widget.fallbackColor,
    );
  }

  String _childKey() {
    final mode = widget.isDarkMode ? 'dark' : 'light';
    return '${widget.sources.cacheKey}_$mode';
  }
}

typedef _LyricsOverlayBuilder = Widget Function();

class _LyricsOverlaySwitcher extends StatelessWidget {
  const _LyricsOverlaySwitcher({
    required this.isVisible,
    required _LyricsOverlayBuilder builder,
  }) : _builder = builder;

  static const ValueKey<String> _visibleKey = ValueKey<String>(
    'lyrics_overlay_visible',
  );
  static const ValueKey<String> _hiddenKey = ValueKey<String>(
    'lyrics_overlay_hidden',
  );

  final bool isVisible;
  final _LyricsOverlayBuilder _builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final key = child.key;
        if (key == _visibleKey) {
          final slideAnimation = animation.drive(
            Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero),
          );
          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        }
        return child;
      },
      child: isVisible
          ? KeyedSubtree(key: _visibleKey, child: _builder())
          : const _LyricsOverlayPlaceholder(),
    );
  }
}

class _LyricsOverlayPlaceholder extends StatelessWidget {
  const _LyricsOverlayPlaceholder()
    : super(key: _LyricsOverlaySwitcher._hiddenKey);

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(ignoring: true, child: SizedBox.shrink());
  }
}
