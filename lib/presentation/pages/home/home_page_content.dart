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
        child: _buildMacOSLayout(),
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

  Widget _buildMacOSLayout() {
    return BlocConsumer<PlayerBloc, PlayerBlocState>(
      listener: (context, playerState) {
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
      },
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: MacosTheme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.black
                                  : MacosTheme.of(context).canvasColor,
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              child: artworkSource.hasSource
                                  ? _BlurredArtworkBackground(
                                      key: ValueKey<String>(
                                        artworkSource.cacheKey,
                                      ),
                                      artworkPath: artworkSource.localPath,
                                      remoteImageUrl: artworkSource.remoteUrl,
                                      isDarkMode:
                                          MacosTheme.of(context).brightness ==
                                          Brightness.dark,
                                    )
                                  : Container(
                                      key: const ValueKey<String>(
                                        'default_background',
                                      ),
                                      color: MacosTheme.of(context).canvasColor,
                                    ),
                            ),
                          ],
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
                                        child: Offstage(
                                          offstage: _lyricsVisible,
                                          child: KeyedSubtree(
                                            key: ValueKey(
                                              _hasActiveDetail
                                                  ? 'mac_detail_content'
                                                  : 'mac_main_content',
                                            ),
                                            child: _buildMainContent(),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 280,
                                          ),
                                          curve: Curves.easeInOut,
                                          opacity: _lyricsVisible ? 1 : 0,
                                          child: IgnorePointer(
                                            ignoring: !_lyricsVisible,
                                            child: _buildLyricsOverlay(
                                              isMac: true,
                                            ),
                                          ),
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

  Widget _buildMainContent() {
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

    final librarySection = IndexedStack(
      index: _hasActiveDetail ? 1 : 0,
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

    final int safeIndex = _selectedIndex.clamp(0, pages.length - 1);

    return IndexedStack(index: safeIndex, children: pages);
  }

  Widget _buildDetailContent() {
    if (_activeArtistDetail != null) {
      return ArtistDetailView(
        artist: _activeArtistDetail!,
        tracks: _activeArtistTracks,
        onAddToPlaylist: (track) => _handleAddTrackToPlaylist(track),
        onViewArtist: _viewTrackArtist,
        onViewAlbum: _viewTrackAlbum,
      );
    }
    if (_activeAlbumDetail != null) {
      return AlbumDetailView(
        album: _activeAlbumDetail!,
        tracks: _activeAlbumTracks,
        onAddToPlaylist: (track) => _handleAddTrackToPlaylist(track),
        onViewArtist: _viewTrackArtist,
        onViewAlbum: _viewTrackAlbum,
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleAddTrackToPlaylist(Track track) async {
    final playlistsCubit = context.read<PlaylistsCubit>();

    final result = await showPlaylistModalDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => BlocProvider.value(
        value: playlistsCubit,
        child: _PlaylistSelectionDialog(track: track),
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
    } else if (result != null && result.isNotEmpty) {
      await playlistsCubit.ensurePlaylistTracks(result, force: true);
    }
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
