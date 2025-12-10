part of 'package:misuzu_music/presentation/pages/home_page.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  int _selectedIndex = 0;
  double _navigationWidth = 200;

  AppLocalizations get l10n => context.l10n;

  static const double _navMinWidth = 80;
  static const double _navMaxWidth = 220;
  List<AdaptiveNavigationDestination> get _mobileDestinations {
    final l10n = context.l10n;
    final iosDestinations = <AdaptiveNavigationDestination>[
      AdaptiveNavigationDestination(
        icon: 'music.note.list',
        label: l10n.navLibrary,
      ),
      AdaptiveNavigationDestination(
        icon: 'square.stack.3d.up',
        label: l10n.navPlaylists,
      ),
      AdaptiveNavigationDestination(icon: 'cloud', label: l10n.navOnlineTracks),
      AdaptiveNavigationDestination(icon: 'music.note', label: l10n.navQueue),
      AdaptiveNavigationDestination(icon: 'gearshape', label: l10n.navSettings),
    ];

    final defaultDestinations = <AdaptiveNavigationDestination>[
      AdaptiveNavigationDestination(
        icon: CupertinoIcons.music_note_list,
        label: l10n.navLibrary,
      ),
      AdaptiveNavigationDestination(
        icon: CupertinoIcons.square_stack_3d_up,
        label: l10n.navPlaylists,
      ),
      AdaptiveNavigationDestination(
        icon: CupertinoIcons.cloud,
        label: l10n.navOnlineTracks,
      ),
      AdaptiveNavigationDestination(
        icon: CupertinoIcons.music_note,
        label: l10n.navQueue,
      ),
      AdaptiveNavigationDestination(
        icon: CupertinoIcons.settings,
        label: l10n.navSettings,
      ),
    ];

    final baseDestinations =
        defaultTargetPlatform == TargetPlatform.iOS &&
            PlatformInfo.isIOS26OrHigher()
        ? iosDestinations
        : defaultDestinations;
    return _mobileDestinationSectionIndices
        .map((index) => baseDestinations[index])
        .toList(growable: false);
  }

  static const double _mobileNowPlayingBarHeight = 118;
  static const String _iosSandboxFolderName = 'MisuzuMusic';

  bool get _shouldHideNeteaseOnIOS =>
      defaultTargetPlatform == TargetPlatform.iOS;

  List<int> get _mobileDestinationSectionIndices {
    return _shouldHideNeteaseOnIOS
        ? const [0, 1, 3, 4]
        : const [0, 1, 2, 3, 4];
  }

  List<int> get _desktopSectionIndices {
    return _shouldHideNeteaseOnIOS
        ? const [0, 1, 3, 4]
        : const [0, 1, 2, 3, 4];
  }

  List<_NavigationItem> _macNavigationItems(List<int> sectionOrder) {
    final l10n = context.l10n;
    return sectionOrder.map((section) {
      switch (section) {
        case 0:
          return _NavigationItem(
            icon: CupertinoIcons.music_albums_fill,
            label: l10n.navLibrary,
          );
        case 1:
          return _NavigationItem(
            icon: CupertinoIcons.square_stack_3d_up,
            label: l10n.navPlaylists,
          );
        case 2:
          return _NavigationItem(
            icon: CupertinoIcons.cloud,
            label: l10n.navOnlineTracks,
          );
        case 3:
          return _NavigationItem(
            icon: CupertinoIcons.music_note_list,
            label: l10n.navQueue,
          );
        case 4:
          return _NavigationItem(
            icon: CupertinoIcons.settings,
            label: l10n.navSettings,
          );
        default:
          return _NavigationItem(
            icon: CupertinoIcons.music_albums_fill,
            label: l10n.navLibrary,
          );
      }
    }).toList(growable: false);
  }

  int _navigationSelectedIndex(List<int> sectionOrder) {
    final navIndex = sectionOrder.indexOf(_selectedIndex);
    if (navIndex != -1) {
      return navIndex;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (sectionOrder.contains(_selectedIndex)) {
        return;
      }
      setState(() {
        _selectedIndex = sectionOrder.first;
      });
    });
    return 0;
  }

  String _searchQuery = '';
  String _activeSearchQuery = '';
  List<LibrarySearchSuggestion> _searchSuggestions = const [];
  Timer? _searchDebounce;
  bool _lyricsVisible = false;
  bool _queuePanelVisible = false;
  final bool _mobileNowPlayingBarVisible = true;
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
  late final SongDetailService _songDetailService;
  String? _prefetchedLyricsTrackId;
  bool _isScanningDialogVisible = false;
  final IcloudStorageSync _icloudStorageSync = IcloudStorageSync();

  @override
  void initState() {
    super.initState();
    _songDetailService = sl<SongDetailService>();
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
          if (state is MusicLibraryScanning) {
            if (!_isScanningDialogVisible) {
              _isScanningDialogVisible = true;
              showPlaylistModalDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    _ScanningDialog(path: state.directoryPath),
              ).then((_) {
                if (mounted) {
                  _isScanningDialogVisible = false;
                }
              });
            }
          } else if (state is MusicLibraryScanComplete ||
              state is MusicLibraryError) {
            if (_isScanningDialogVisible) {
              Navigator.of(context).pop();
              _isScanningDialogVisible = false;
            }
          }

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
      title: l10n.homePullCloudPlaylistTitle,
      confirmLabel: l10n.homePullCloudPlaylistConfirm,
      invalidMessage: playlistsCubit.cloudIdRuleDescription,
      description: l10n.homePullCloudPlaylistDescription,
      validator: playlistsCubit.isValidCloudPlaylistId,
    );
    if (!mounted || cloudId == null) {
      return null;
    }

    String? playlistId;
    String successMessage = l10n.homePullCloudPlaylistSuccess(cloudId);
    String? errorMessage;

    await _runWithBlockingProgress(
      title: l10n.homePullCloudPlaylistProgress,
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
            successMessage = l10n.homePullCloudPlaylistAddCurrent;
          } else {
            successMessage = l10n.homePullCloudPlaylistAlready;
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
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _tryShowSnackBar(
    SnackBar snackBar, {
    bool clearExisting = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('⚠️ ScaffoldMessenger 不可用，跳过 SnackBar 显示: $snackBar');
      return false;
    }
    if (clearExisting) {
      messenger.clearSnackBars();
    }
    messenger.showSnackBar(snackBar);
    return true;
  }

  Future<void> _showPlaylistActionDialog({
    required String title,
    required String message,
    bool isError = false,
    String? confirmLabel,
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
            Expanded(child: Text(message)),
          ],
        ),
        actions: [
          _SheetActionButton.primary(
            label: confirmLabel ?? l10n.actionOk,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _prefetchTrackResources(Track? track) {
    if (!mounted || track == null) {
      return;
    }
    if (_prefetchedLyricsTrackId == track.id) {
      return;
    }
    _prefetchedLyricsTrackId = track.id;
    try {
      context.read<LyricsCubit>().loadLyricsForTrack(track);
    } catch (error) {
      debugPrint('[HomeContent] 预加载歌词失败: $error');
    }
    unawaited(
      _songDetailService
          .prefetchDetail(
            title: track.title,
            artist: track.artist,
            album: track.album,
          )
          .catchError((error) {
            debugPrint('[HomeContent] 歌曲详情预加载失败: $error');
          }),
    );
  }

  void _handlePlayerStateChange(PlayerBlocState playerState) {
    bool shouldHideLyrics = false;
    final Track? playerTrack = _playerTrack(playerState);
    Track? nextTrack = playerTrack;
    final queueSnapshot = _queueSnapshotFromState(playerState);
    final bool shouldHideQueueOverlay =
        _queuePanelVisible && !queueSnapshot.hasQueue;

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

    _prefetchTrackResources(playerTrack);

    // 保持当前歌词组件状态，避免切歌过渡时触发 dispose 导致桌面歌词被关闭。
    if (!shouldHideLyrics && nextTrack == null && _lyricsVisible) {
      nextTrack = _lyricsActiveTrack;
    }

    final bool needsHideUpdate = shouldHideLyrics && _lyricsVisible;
    final bool trackChanged = _lyricsActiveTrack != nextTrack;

    if (!needsHideUpdate && !trackChanged && !shouldHideQueueOverlay) {
      return;
    }

    setState(() {
      if (needsHideUpdate) {
        _lyricsVisible = false;
      }
      if (shouldHideQueueOverlay) {
        _queuePanelVisible = false;
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
        title: l10n.homeAddToPlaylistTitle,
        message: l10n.homeAddToPlaylistEmpty,
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
            title: l10n.homeAddToPlaylistTitle,
            message: bulkResult.errorMessage ?? l10n.homeAddToPlaylistFailed,
            isError: true,
          );
          return;
        }
      }

      await playlistsCubit.ensurePlaylistTracks(newId, force: true);

      final playlistName = _playlistNameById(newId) ?? l10n.playlistDefaultName;
      final added = 1 + (bulkResult?.addedCount ?? 0);
      final skipped = bulkResult?.skippedCount ?? 0;
      await _showPlaylistActionDialog(
        title: l10n.homeAddToPlaylistTitle,
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

      final playlistName =
          _playlistNameById(selection.playlistId) ?? l10n.playlistDefaultName;

      if (selection.addedCount > 0) {
        await _showPlaylistActionDialog(
          title: l10n.homeAddToPlaylistTitle,
          message: _formatBulkAddMessage(
            playlistName,
            selection.addedCount,
            selection.skippedCount,
          ),
        );
      } else {
        await _showPlaylistActionDialog(
          title: l10n.homeAddToPlaylistTitle,
          message: l10n.homeAddToPlaylistExists,
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
    final base = l10n.homeAddToPlaylistSummary(added, playlistName);
    if (skipped <= 0) {
      return base;
    }
    return l10n.homeAddToPlaylistSummaryWithSkipped(base, skipped);
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

  void _viewTrackArtist(Track track) async {
    final name = track.artist.trim();
    debugPrint(
      '[HomeContent] View artist request from track "${track.title}" by "${track.artist}"',
    );
    if (name.isEmpty) {
      _showOperationSnackBar(l10n.homeSongMissingArtist, isError: true);
      return;
    }

    final library = _effectiveLibraryState();
    if (library == null) {
      _showOperationSnackBar(l10n.homeLibraryNotReady, isError: true);
      return;
    }

    final lowerName = name.toLowerCase();
    final separatorPattern = RegExp(r'[/、,，&＆]+');
    final normalizedTracks = _normalizedLibraryTracks(library);
    final buckets = <String, List<Track>>{};
    void addToBucket(String key, Track track) {
      final trimmed = key.trim().toLowerCase();
      if (trimmed.isEmpty) return;
      final list = buckets.putIfAbsent(trimmed, () => []);
      final alreadyExists = list.any((t) => t.id == track.id);
      if (!alreadyExists) {
        list.add(track);
      }
    }

    for (final item in normalizedTracks) {
      final artistValue = item.artist.trim();
      addToBucket(artistValue, item);
      final parts = artistValue.split(separatorPattern);
      for (final part in parts) {
        if (part.trim().isEmpty) continue;
        addToBucket(part, item);
      }
    }

    final slashParts = name
        .split(separatorPattern)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final candidateNames = <String>[
      ...slashParts,
      if (!slashParts.any((part) => part.toLowerCase() == lowerName)) name,
    ];
    final matchedArtists = <MapEntry<String, List<Track>>>[];
    final seenKeys = <String>{};

    for (final candidate in candidateNames) {
      final key = candidate.toLowerCase();
      if (!seenKeys.add(key)) continue;
      final tracks = buckets[key];
      if (tracks == null || tracks.isEmpty) continue;

      matchedArtists.add(MapEntry(candidate, tracks));
    }

    if (matchedArtists.isEmpty) {
      debugPrint('[HomeContent] No artist match for "$name"');
    } else {
      final matchedNames =
          matchedArtists.map((entry) => '"${entry.key}"').join(', ');
      debugPrint(
        '[HomeContent] Found artist matches ($matchedNames), count=${matchedArtists.length}',
      );
    }

    if (matchedArtists.isEmpty) {
      _showOperationSnackBar(l10n.homeArtistNotFound, isError: true);
      return;
    }

    MapEntry<String, List<Track>> selectedArtist;
    if (matchedArtists.length == 1) {
      selectedArtist = matchedArtists.first;
    } else {
      final selection = await _showArtistSelectionDialog(matchedArtists);
      if (selection == null) return;
      selectedArtist = selection;
    }

    final artistTracks = selectedArtist.value;
    final artworkTrack = artistTracks.lastWhere(
      (t) => t.artworkPath != null && t.artworkPath!.isNotEmpty,
      orElse: () => artistTracks.first,
    );
    final artist = Artist(
      name: selectedArtist.key.trim().isEmpty ? name : selectedArtist.key,
      trackCount: artistTracks.length,
      artworkPath: artworkTrack.artworkPath,
    );
    debugPrint(
      '[HomeContent] Open artist detail "${artist.name}" (${artist.trackCount} tracks)',
    );

    _showArtistDetail(artist, artistTracks);
  }

  Future<MapEntry<String, List<Track>>?> _showArtistSelectionDialog(
    List<MapEntry<String, List<Track>>> options,
  ) {
    if (!mounted) return Future.value(null);

    return showPlaylistModalDialog<MapEntry<String, List<Track>>>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return _PlaylistModalScaffold(
          title: dialogContext.l10n.homeArtistSelectionTitle,
          maxWidth: 420,
          contentSpacing: 12,
          actionsSpacing: 14,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dialogContext.l10n.homeArtistSelectionHint,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              FrostedSelectionContainer(
                maxHeight: 320,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: options.length,
                  itemBuilder: (ctx, index) {
                    final option = options[index];
                    return FrostedOptionTile(
                      title: option.key,
                      subtitle: dialogContext
                          .l10n
                          .homeArtistDescription(option.value.length),
                      onPressed: () => Navigator.of(ctx).pop(option),
                    );
                  },
                  separatorBuilder: (ctx, index) {
                    final dividerColor =
                        theme.dividerColor.withOpacity(0.25);
                    return Divider(
                      height: 1,
                      thickness: 0.6,
                      indent: 14,
                      endIndent: 14,
                      color: dividerColor,
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            _SheetActionButton.secondary(
              label: dialogContext.l10n.actionCancel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  void _viewTrackAlbum(Track track) {
    final albumName = track.album.trim();
    final artistName = track.artist.trim();
    if (albumName.isEmpty) {
      _showOperationSnackBar(l10n.homeSongMissingAlbum, isError: true);
      return;
    }

    final library = _effectiveLibraryState();
    if (library == null) {
      _showOperationSnackBar(l10n.homeLibraryNotReady, isError: true);
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
      _showOperationSnackBar(l10n.homeAlbumNotFound, isError: true);
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
          label: l10n.homeSongLabel(display.title),
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
          label: l10n.homeArtistLabel(artist.name),
          description: l10n.homeArtistDescription(artist.trackCount),
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
          label: l10n.homeAlbumLabel(album.title),
          description: l10n.homeAlbumDescription(
            album.artist,
            album.trackCount,
          ),
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
          label: l10n.homeSearchQuerySuggestion(query),
          description: l10n.homeSearchQueryDescription,
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
      _showErrorDialog(context, l10n.homeArtistNotFoundDialog);
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
      _showErrorDialog(context, l10n.homeAlbumNotFoundDialog);
      debugPrint('[HomeContent] Album detail aborted: no tracks');
      return;
    }
    _showAlbumDetail(album, tracks);
  }

  void _handleNavigationChange(int index) {
    _dismissLyricsOverlay();
    _dismissQueueOverlay();

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
        return l10n.navLibrary;
      case 1:
        return l10n.navPlaylists;
      case 2:
        return l10n.navOnlineTracks;
      case 3:
        return l10n.navQueue;
      case 4:
        return l10n.navSettings;
      default:
        return l10n.navLibrary;
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

    return l10n.homeLibraryStats(totalTracks, hours, minutes);
  }

  String? _composeNeteaseStatsLabel(NeteaseState state) {
    if (!state.hasSession) {
      return l10n.homeOnlineNotLoggedIn;
    }
    final totalTracks = state.playlists.fold<int>(
      0,
      (sum, playlist) =>
          sum + (playlist.trackCount > 0 ? playlist.trackCount : 0),
    );
    if (totalTracks <= 0) {
      return l10n.homeOnlinePlaylists;
    }
    return l10n.homeOnlineStats(totalTracks);
  }

  Widget _buildLyricsOverlay({
    required bool isMac,
    double bottomSafeInset = 0,
  }) {
    final track = _lyricsActiveTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }

    return LyricsOverlay(
      key: ValueKey('lyrics_overlay_${isMac ? 'mac' : 'material'}'),
      initialTrack: track,
      isMac: isMac,
      bottomSafeInset: bottomSafeInset,
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

  void _dismissQueueOverlay() {
    if (!_queuePanelVisible) {
      return;
    }
    setState(() {
      _queuePanelVisible = false;
    });
  }

  void _playQueueEntry(List<Track> queue, int index) {
    if (queue.isEmpty || index < 0 || index >= queue.length) {
      return;
    }
    context.read<PlayerBloc>().add(
          PlayerSetQueue(queue, startIndex: index, autoPlay: true),
        );
  }

  Future<void> _showQueueBottomSheet() async {
    final playerBloc = context.read<PlayerBloc>();

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => BlocProvider.value(
        value: playerBloc,
        child: _PlaybackQueueSheet(
          onPlayTrack: _playQueueEntry,
        ),
      ),
    );
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
      case LibraryMountMode.icloud:
        await _selectICloudFolder();
        break;
      case LibraryMountMode.webdav:
        await _selectWebDavFolder();
        break;
    }
  }

  Future<void> _selectLocalFolder() async {
    if (Platform.isIOS) {
      await _selectIOSMisuzuFolder();
      return;
    }

    try {
      print('🎵 开始选择音乐文件夹...');

      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.homeSelectFolderTitle,
      );

      if (result != null) {
        print('🎵 选择的文件夹: $result');

        if (mounted) {
          print('🎵 开始扫描音乐文件夹...');
          context.read<MusicLibraryBloc>().add(ScanDirectoryEvent(result));

          if (!prefersMacLikeUi()) {
            _tryShowSnackBar(
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
                        l10n.homeScanningFolder(result.split('/').last),
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

  Future<void> _selectICloudFolder() async {
    if (!Platform.isIOS) {
      debugPrint('☁️ iCloud 挂载目前仅支持 iOS，当前平台: ${Platform.operatingSystem}');
      return;
    }

    const containerId = AppConstants.iosICloudContainerId;
    if (containerId.isEmpty) {
      if (mounted) {
        _showErrorDialog(context, l10n.homeICloudContainerMissing);
      }
      return;
    }

    try {
      debugPrint('☁️ 准备获取 iCloud 文件列表，containerId: $containerId');
      final files = await _withBlockingLoader(() {
        return _icloudStorageSync.getCloudFiles(containerId: containerId);
      });

      if (!mounted || files == null) {
        debugPrint(
          '☁️ getCloudFiles 返回 null 或组件已卸载，mounted: $mounted, files: $files',
        );
        return;
      }

      debugPrint(
        '☁️ getCloudFiles 成功返回，文件总数: ${files.length}，示例前 3 个: ${files.take(3).map((f) => _decodeICloudPath(f.relativePath)).toList()}',
      );

      if (files.isEmpty) {
        debugPrint(
          '☁️ getCloudFiles 返回空列表，可能原因：容器无文件或插件捕获了 PlatformException（未登录/权限/容器 ID 不匹配）',
        );
        _showErrorDialog(context, l10n.homeICloudEmptyFolder);
        return;
      }

      final selectedDirectory = await _showICloudDirectoryPicker(files);
      if (!mounted || selectedDirectory == null) {
        debugPrint(
          '☁️ 用户未选择目录或组件卸载，selectedDirectory: $selectedDirectory, mounted: $mounted',
        );
        return;
      }

      debugPrint('☁️ 用户选择的 iCloud 目录: "$selectedDirectory"');
      final cachedPath = await _withBlockingLoader(() {
        return _cacheICloudDirectory(
          files: files,
          containerId: containerId,
          directory: selectedDirectory,
        );
      });

      if (!mounted || cachedPath == null) {
        debugPrint(
          '☁️ 缓存 iCloud 目录失败或组件卸载，cachedPath: $cachedPath, mounted: $mounted',
        );
        return;
      }

      debugPrint('☁️ 已将 iCloud 目录缓存到本地: $cachedPath，开始扫描');
      context.read<MusicLibraryBloc>().add(ScanDirectoryEvent(cachedPath));

      if (!prefersMacLikeUi()) {
        final folderLabel = selectedDirectory.isEmpty
            ? l10n.homeICloudRootName
            : selectedDirectory.split('/').last;
        _tryShowSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.homeScanningFolder(folderLabel))),
              ],
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('☁️ iCloud 挂载失败: $error\n$stackTrace');
      if (mounted) {
        _showErrorDialog(context, error.toString());
      }
    }
  }

  Future<T?> _withBlockingLoader<T>(Future<T> Function() runner) async {
    if (!mounted) {
      return runner();
    }
    final overlay = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BlockingLoadingDialog(),
    );
    try {
      return await runner();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await overlay.catchError((_) {});
    }
  }

  Future<String?> _showICloudDirectoryPicker(List<CloudFiles> files) async {
    if (!mounted) {
      return null;
    }
    final decodedPaths = files
        .map((file) => _decodeICloudPath(file.relativePath))
        .where((path) => path.isNotEmpty)
        .toList();
    if (decodedPaths.isEmpty) {
      _showErrorDialog(context, l10n.homeICloudEmptyFolder);
      return null;
    }
    final tree = _ICloudDirectoryTree.fromPaths(decodedPaths);
    if (!tree.hasDirectories && !tree.hasFiles('')) {
      _showErrorDialog(context, l10n.homeICloudNoSubfolders);
      return null;
    }
    var currentPath = tree.initialPath ?? '';
    return showPlaylistModalDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final modalTheme = Theme.of(dialogContext);
        return StatefulBuilder(
          builder: (stateContext, setState) {
            final subDirs = tree.childrenOf(currentPath);
            final canSelect = tree.hasFiles(currentPath);
            final currentLabel = currentPath.isEmpty
                ? dialogContext.l10n.homeICloudRootName
                : currentPath;

            return _PlaylistModalScaffold(
              title: dialogContext.l10n.libraryMountOptionICloudTitle,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (currentPath.isNotEmpty)
                        IconButton(
                          tooltip: dialogContext.l10n.homeBackTooltipDefault,
                          onPressed: () {
                            setState(() {
                              currentPath = tree.parentOf(currentPath) ?? '';
                            });
                          },
                          icon: const Icon(CupertinoIcons.back),
                        ),
                      Expanded(
                        child: Text(
                          currentLabel,
                          style:
                              modalTheme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ) ??
                              TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: modalTheme.colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: subDirs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                dialogContext.l10n.homeICloudNoSubfolders,
                                style: modalTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                      color: modalTheme
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemBuilder: (_, index) {
                              final folderPath = subDirs[index];
                              final folderName = folderPath.split('/').last;
                              final itemCount =
                                  tree.fileCounts[folderPath] ?? 0;
                              return _ICloudFolderTile(
                                name: folderName,
                                description: dialogContext.l10n
                                    .homeICloudFolderFileCount(itemCount),
                                onTap: () => setState(() {
                                  currentPath = folderPath;
                                }),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemCount: subDirs.length,
                          ),
                  ),
                  if (!canSelect)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        dialogContext.l10n.homeICloudEmptyFolder,
                        style: modalTheme.textTheme.bodySmall?.copyWith(
                          color: modalTheme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                _SheetActionButton.secondary(
                  label: dialogContext.l10n.actionCancel,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                _SheetActionButton.primary(
                  label: dialogContext.l10n.libraryMountConfirmButton,
                  onPressed: canSelect
                      ? () => Navigator.of(dialogContext).pop(currentPath)
                      : null,
                ),
              ],
              maxWidth: 420,
              contentSpacing: 18,
              actionsSpacing: 16,
            );
          },
        );
      },
    );
  }

  Future<String> _cacheICloudDirectory({
    required List<CloudFiles> files,
    required String containerId,
    required String directory,
  }) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final mountRoot = Directory(p.join(documentsDir.path, 'icloud_mounts'));
    if (!await mountRoot.exists()) {
      await mountRoot.create(recursive: true);
    }
    final safeName = directory.isEmpty
        ? 'root'
        : directory.replaceAll('/', '_');
    final targetDir = Directory(p.join(mountRoot.path, safeName));
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);

    final prefix = directory.isEmpty ? '' : '$directory/';
    debugPrint(
      '☁️ 开始缓存 iCloud 目录，原始文件数: ${files.length}, 选择目录: "$directory", prefix: "$prefix", 本地缓存目录: ${targetDir.path}',
    );
    final filtered = files.where((file) {
      final relative = _decodeICloudPath(file.relativePath);
      if (relative.isEmpty) {
        return false;
      }
      return directory.isEmpty || relative.startsWith(prefix);
    }).toList();

    if (filtered.isEmpty) {
      debugPrint(
        '☁️ 过滤后没有文件，可能目录为空或路径解码失败，示例原始 relativePath: ${files.take(3).map((f) => f.relativePath).toList()}',
      );
      throw Exception(l10n.homeICloudEmptyFolder);
    }

    debugPrint(
      '☁️ 过滤后待缓存文件数: ${filtered.length}，前 5 个: ${filtered.take(5).map((f) => _decodeICloudPath(f.relativePath)).toList()}',
    );

    for (final cloudFile in filtered) {
      final relativePath = _decodeICloudPath(cloudFile.relativePath);
      if (relativePath.isEmpty) {
        continue;
      }
      final withinSelection = directory.isEmpty
          ? relativePath
          : relativePath.substring(
              relativePath.startsWith(prefix) ? prefix.length : 0,
            );
      if (withinSelection.trim().isEmpty) {
        continue;
      }
      final destination = File(p.join(targetDir.path, withinSelection));
      await destination.parent.create(recursive: true);

      final localSourcePath = _decodeICloudPath(cloudFile.filePath);
      if (localSourcePath.isNotEmpty) {
        final localSource = File(localSourcePath);
        if (await localSource.exists()) {
          debugPrint('☁️ 本地已存在下载文件，直接复制: $localSourcePath -> ${destination.path}');
          await localSource.copy(destination.path);
          continue;
        }
      }

      debugPrint(
        '☁️ 本地未找到文件，尝试从 iCloud 下载: relative=$relativePath -> ${destination.path}',
      );
      await _icloudStorageSync.download(
        containerId: containerId,
        relativePath: relativePath,
        destinationFilePath: destination.path,
      );
    }

    return targetDir.path;
  }

  String _decodeICloudPath(String? path) {
    if (path == null) {
      return '';
    }
    try {
      return Uri.decodeFull(path);
    } catch (_) {
      return path;
    }
  }

  Future<void> _selectIOSMisuzuFolder() async {
    try {
      final selectedPath = await _showMisuzuMusicFolderPicker();
      if (!mounted || selectedPath == null) {
        return;
      }

      print('🎵 iOS 选择的 MisuzuMusic 文件夹: $selectedPath');
      context.read<MusicLibraryBloc>().add(ScanDirectoryEvent(selectedPath));

      if (!prefersMacLikeUi()) {
        final folderName = p.basename(selectedPath);
        _tryShowSnackBar(
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
                  child: Text(l10n.homeScanningMisuzuFolder(folderName)),
                ),
              ],
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      print('❌ 选择 MisuzuMusic 文件夹时出错: $e');
      if (mounted) {
        _showErrorDialog(context, e.toString());
      }
    }
  }

  Future<String?> _showMisuzuMusicFolderPicker() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final rootDir = Directory(p.join(documentsDir.path, _iosSandboxFolderName));
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }

    final localL10n = l10n;

    Future<List<_MisuzuFolderOption>> loadOptions() async {
      final folders = <_MisuzuFolderOption>[
        _MisuzuFolderOption(
          path: rootDir.path,
          name: localL10n.homeMisuzuRootName,
          description: localL10n.homeMisuzuRootDescription,
          isRoot: true,
        ),
      ];

      await for (final entity in rootDir.list(followLinks: false)) {
        if (entity is Directory) {
          final folderName = p.basename(entity.path);
          folders.add(
            _MisuzuFolderOption(
              path: entity.path,
              name: folderName,
              description: localL10n.homeMisuzuFilesPath(folderName),
            ),
          );
        }
      }

      folders.sort((a, b) {
        if (a.isRoot && !b.isRoot) {
          return -1;
        }
        if (!a.isRoot && b.isRoot) {
          return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return folders;
    }

    var options = await loadOptions();
    var refreshing = false;

    return showPlaylistModalDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> refreshOptions() async {
              setState(() {
                refreshing = true;
              });
              final updated = await loadOptions();
              setState(() {
                options = updated;
                refreshing = false;
              });
            }

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final subFolderCount = options.isEmpty ? 0 : options.length - 1;
            final filesRootLabel = _filesAppRootLabel(context, l10n);

            return _PlaylistModalScaffold(
              title: l10n.homePickMisuzuFolderTitle,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      l10n.homeMisuzuFilesHint(filesRootLabel),
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.white.withOpacity(0.75)
                                : Colors.black.withOpacity(0.7),
                          ) ??
                          TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withOpacity(0.75)
                                : Colors.black.withOpacity(0.7),
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.homeMisuzuSubfolderCount(subFolderCount),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.actionRefresh,
                        onPressed: refreshing ? null : refreshOptions,
                        icon: refreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(CupertinoIcons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: Scrollbar(
                      thumbVisibility: options.length > 4,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          return _MisuzuFolderTile(
                            option: option,
                            onTap: () =>
                                Navigator.of(dialogContext).pop(option.path),
                          );
                        },
                      ),
                    ),
                  ),
                  if (subFolderCount == 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.homeMisuzuNoSubfolders,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                _SheetActionButton.secondary(
                  label: l10n.actionCancel,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
              maxWidth: 420,
              contentSpacing: 18,
              actionsSpacing: 16,
            );
          },
        );
      },
    );
  }

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
      return l10n.homeWebDavLibrary;
    }
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return l10n.homeWebDavLibrary;
    }
    return segments.last;
  }

  Future<_WebDavConnectionFormResult?> _showWebDavConnectionDialog() {
    return showPlaylistModalDialog<_WebDavConnectionFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _WebDavConnectionDialog(testConnection: sl<TestWebDavConnection>()),
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

    return showPlaylistModalDialog<String>(
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
        ? l10n.homeWebDavScanSummary(tracksAdded)
        : l10n.homeWebDavScanSummaryWithSource(tracksAdded, webDavSource.name);
    if (prefersMacLikeUi()) {
      showPlaylistModalDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => PlaylistModalScaffold(
          title: l10n.homeScanCompletedTitle,
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
              Text(message, textAlign: TextAlign.center),
            ],
          ),
          actions: [
            SheetActionButton.primary(
              label: l10n.actionOk,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          contentSpacing: 18,
          actionsSpacing: 12,
        ),
      );
    } else {
      final shown = _tryShowSnackBar(
        SnackBar(
          content: Text(l10n.homeScanCompletedMessage(message)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
        clearExisting: true,
      );
      if (!shown) {
        showPlaylistModalDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => PlaylistModalScaffold(
            title: l10n.homeScanCompletedTitle,
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
                Text(message, textAlign: TextAlign.center),
              ],
            ),
            actions: [
              SheetActionButton.primary(
                label: l10n.actionOk,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            contentSpacing: 18,
            actionsSpacing: 12,
          ),
        );
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    if (prefersMacLikeUi()) {
      showPlaylistModalDialog<void>(
        context: context,
        builder: (_) => PlaylistModalScaffold(
          title: l10n.homeErrorTitle,
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
              Text(message, textAlign: TextAlign.center),
            ],
          ),
          actions: [
            SheetActionButton.primary(
              label: l10n.actionOk,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          contentSpacing: 18,
          actionsSpacing: 12,
        ),
      );
    } else {
      final shown = _tryShowSnackBar(
        SnackBar(
          content: Text(locale: const Locale('zh-Hans', 'zh'), '❌ $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
        clearExisting: true,
      );
      if (!shown) {
        showPlaylistModalDialog<void>(
          context: context,
          builder: (_) => PlaylistModalScaffold(
            title: l10n.homeErrorTitle,
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
                Text(message, textAlign: TextAlign.center),
              ],
            ),
            actions: [
              SheetActionButton.primary(
                label: l10n.actionOk,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            contentSpacing: 18,
            actionsSpacing: 12,
          ),
        );
      }
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

class _BlockingLoadingDialog extends StatelessWidget {
  const _BlockingLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.dialogBackgroundColor;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: background.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _ICloudFolderTile extends StatelessWidget {
  const _ICloudFolderTile({
    required this.name,
    required this.description,
    required this.onTap,
  });

  final String name;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle =
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withOpacity(0.92)
              : Colors.black.withOpacity(0.9),
        ) ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withOpacity(0.92)
              : Colors.black.withOpacity(0.9),
        );
    final descriptionStyle =
        theme.textTheme.bodySmall?.copyWith(
          color: isDark
              ? Colors.white.withOpacity(0.68)
              : Colors.black.withOpacity(0.65),
        ) ??
        TextStyle(
          fontSize: 12,
          color: isDark
              ? Colors.white.withOpacity(0.68)
              : Colors.black.withOpacity(0.65),
        );

    return _HoverableCard(
      baseColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04),
      hoverColor: isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.08),
      borderColor: isDark
          ? Colors.white.withOpacity(0.14)
          : Colors.black.withOpacity(0.08),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.folder_solid,
              size: 22,
              color: isDark
                  ? Colors.white.withOpacity(0.92)
                  : Colors.black.withOpacity(0.78),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(locale: Locale("zh-Hans", "zh"), name, style: titleStyle),
                const SizedBox(height: 4),
                Text(
                  locale: Locale("zh-Hans", "zh"),
                  description,
                  style: descriptionStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: isDark
                ? Colors.white.withOpacity(0.45)
                : Colors.black.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _ICloudDirectoryTree {
  _ICloudDirectoryTree(this.children, this.fileCounts);

  final Map<String, Set<String>> children;
  final Map<String, int> fileCounts;

  bool get hasDirectories =>
      children.entries.any((entry) => entry.value.isNotEmpty);

  bool hasFiles(String path) => (fileCounts[path] ?? 0) > 0;

  List<String> childrenOf(String path) {
    final current = children[path];
    if (current == null || current.isEmpty) {
      return const [];
    }
    final list = current.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  String? parentOf(String path) {
    if (path.isEmpty) {
      return null;
    }
    final segments = path.split('/');
    if (segments.length <= 1) {
      return '';
    }
    return segments.sublist(0, segments.length - 1).join('/');
  }

  String? get initialPath {
    if (children['']?.contains('MisuzuMusic') ?? false) {
      return 'MisuzuMusic';
    }
    final rootChildren = childrenOf('');
    if (rootChildren.isEmpty) {
      return '';
    }
    return rootChildren.first;
  }

  static _ICloudDirectoryTree fromPaths(List<String> paths) {
    final children = <String, Set<String>>{'': <String>{}};
    final counts = <String, int>{'': 0};

    void ensurePath(String path) {
      children.putIfAbsent(path, () => <String>{});
      counts.putIfAbsent(path, () => 0);
    }

    for (final path in paths) {
      final segments = path
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (segments.isEmpty) {
        continue;
      }
      final parents = segments.length > 1
          ? segments.sublist(0, segments.length - 1)
          : <String>[];
      var parentPath = '';
      ensurePath(parentPath);

      if (parents.isEmpty) {
        counts[parentPath] = (counts[parentPath] ?? 0) + 1;
        continue;
      }

      for (int i = 0; i < parents.length; i++) {
        final currentPath = parents.sublist(0, i + 1).join('/');
        ensurePath(currentPath);
        children[parentPath]!.add(currentPath);
        counts[parentPath] = (counts[parentPath] ?? 0) + 1;
        parentPath = currentPath;
      }

      counts[parentPath] = (counts[parentPath] ?? 0) + 1;
    }

    for (final entry in children.entries) {
      counts.putIfAbsent(entry.key, () => 0);
    }

    return _ICloudDirectoryTree(children, counts);
  }
}

class _MisuzuFolderOption {
  const _MisuzuFolderOption({
    required this.path,
    required this.name,
    required this.description,
    this.isRoot = false,
  });

  final String path;
  final String name;
  final String description;
  final bool isRoot;
}

class _MisuzuFolderTile extends StatelessWidget {
  const _MisuzuFolderTile({required this.option, required this.onTap});

  final _MisuzuFolderOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle =
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withOpacity(0.92)
              : Colors.black.withOpacity(0.9),
        ) ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withOpacity(0.92)
              : Colors.black.withOpacity(0.9),
        );
    final descriptionStyle =
        theme.textTheme.bodySmall?.copyWith(
          color: isDark
              ? Colors.white.withOpacity(0.68)
              : Colors.black.withOpacity(0.65),
        ) ??
        TextStyle(
          fontSize: 12,
          color: isDark
              ? Colors.white.withOpacity(0.68)
              : Colors.black.withOpacity(0.65),
        );

    return _HoverableCard(
      baseColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04),
      hoverColor: isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.08),
      borderColor: isDark
          ? Colors.white.withOpacity(0.14)
          : Colors.black.withOpacity(0.08),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              option.isRoot
                  ? CupertinoIcons.folder_fill
                  : CupertinoIcons.folder_solid,
              size: 22,
              color: isDark
                  ? Colors.white.withOpacity(0.92)
                  : Colors.black.withOpacity(0.78),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale: Locale("zh-Hans", "zh"),
                  option.name,
                  style: titleStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  locale: Locale("zh-Hans", "zh"),
                  option.description,
                  style: descriptionStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: isDark
                ? Colors.white.withOpacity(0.45)
                : Colors.black.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _ScanningDialog extends StatelessWidget {
  const _ScanningDialog({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friendlyPath = path.split('/').last;
    return _PlaylistModalScaffold(
      title: l10n.homeScanningFolder(friendlyPath),
      body: const SizedBox(height: 100, child: Center(child: ProgressCircle())),
      actions: const [],
      maxWidth: 320,
      contentSpacing: 20,
      actionsSpacing: 0,
    );
  }
}
