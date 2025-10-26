part of 'package:misuzu_music/presentation/pages/home_page.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  int _selectedIndex = 0;
  double _navigationWidth = 200;

  static const double _navMinWidth = 100;
  static const double _navMaxWidth = 220;
  String _searchQuery = '';
  String _activeSearchQuery = '';
  Timer? _searchDebounce;
  bool _lyricsVisible = false;
  Track? _lyricsActiveTrack;
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
      onKeyEvent: _handleKeyEvent,
      child: BlocListener<MusicLibraryBloc, MusicLibraryState>(
        listener: (context, state) {
          if (state is MusicLibraryScanComplete) {
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
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
      if (openAfterCreate) {
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
        if (!_lyricsVisible) {
          return;
        }

        if (playerState is PlayerInitial || playerState is PlayerError) {
          if (mounted) {
            setState(() {
              _lyricsVisible = false;
              _lyricsActiveTrack = null;
            });
          }
          return;
        }

        if (playerState is PlayerStopped) {
          final hasQueuedTracks = playerState.queue.isNotEmpty;
          if (!hasQueuedTracks) {
            if (mounted) {
              setState(() {
                _lyricsVisible = false;
                _lyricsActiveTrack = null;
              });
            }
          }
          return;
        }

        final track = _playerTrack(playerState);
        if (track == null) {
          return;
        }

        if (_lyricsActiveTrack != track) {
          if (mounted) {
            setState(() {
              _lyricsActiveTrack = track;
            });
          }
        }
      },
      builder: (context, playerState) {
        final artworkPath = _currentArtworkPath(playerState);
        final currentTrack = _playerTrack(playerState);
        const headerHeight = 76.0;
        final sectionLabel = _currentSectionLabel(_selectedIndex);
        final statsLabel = _composeHeaderStatsLabel(
          context.watch<MusicLibraryBloc>().state,
        );
        bool showBackButton = false;
        bool canNavigateBack = false;
        VoidCallback? onNavigateBack;
        String backTooltip = '返回上一层';
        TrackSortMode? sortMode;
        ValueChanged<TrackSortMode>? onSortModeChanged;
        final playlistsViewState = _playlistsViewKey.currentState;
        final musicLibraryViewState = _musicLibraryViewKey.currentState;

        switch (_selectedIndex) {
          case 0:
            showBackButton = true;
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
            backTooltip = '返回网易云歌单列表';
            if (canNavigateBack) {
              onNavigateBack = () =>
                  _neteaseViewKey.currentState?.exitToOverview();
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: artworkPath != null
                              ? _BlurredArtworkBackground(
                                  key: ValueKey<String>(artworkPath),
                                  artworkPath: artworkPath,
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
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _lyricsVisible
                                ? () => _toggleLyrics(playerState)
                                : null,
                            child: AbsorbPointer(
                              absorbing: _lyricsVisible,
                              child: _MacOSNavigationPane(
                                width: _navigationWidth,
                                collapsed: _navigationWidth <= 112,
                                selectedIndex: _selectedIndex,
                                onSelect: _handleNavigationChange,
                                onResize: (width) {
                                  if (_lyricsVisible) return;
                                  setState(() {
                                    _navigationWidth = width.clamp(
                                      _navMinWidth,
                                      _navMaxWidth,
                                    );
                                  });
                                },
                                enabled: !_lyricsVisible,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _lyricsVisible
                                      ? () => _toggleLyrics(playerState)
                                      : null,
                                  child: AbsorbPointer(
                                    absorbing: _lyricsVisible,
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      opacity: _lyricsVisible ? 0.6 : 1.0,
                                      child: _MacOSGlassHeader(
                                        height: headerHeight,
                                        sectionLabel: sectionLabel,
                                        statsLabel: statsLabel,
                                        searchQuery: _searchQuery,
                                        onSearchChanged: _onSearchQueryChanged,
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
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Offstage(
                                          offstage: _lyricsVisible,
                                          child: KeyedSubtree(
                                            key: const ValueKey(
                                              'mac_main_content',
                                            ),
                                            child: _buildMainContent(),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 280,
                                          ),
                                          switchInCurve: Curves.easeOut,
                                          switchOutCurve: Curves.easeIn,
                                          transitionBuilder:
                                              (child, animation) =>
                                                  FadeTransition(
                                                    opacity: animation,
                                                    child: child,
                                                  ),
                                          child: _lyricsVisible
                                              ? _buildLyricsOverlay(isMac: true)
                                              : const SizedBox.shrink(
                                                  key: ValueKey(
                                                    'lyrics_overlay_mac_empty',
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
    switch (_selectedIndex) {
      case 0:
        return MusicLibraryView(
          key: _musicLibraryViewKey,
          onAddToPlaylist: _handleAddTrackToPlaylist,
          onDetailStateChanged: (value) {
            if (_musicLibraryCanNavigateBack != value) {
              setState(() {
                _musicLibraryCanNavigateBack = value;
              });
            }
          },
        );
      case 1:
        return PlaylistsView(
          key: _playlistsViewKey,
          onAddToPlaylist: _handleAddTrackToPlaylist,
          onDetailStateChanged: (value) {
            if (_playlistsCanNavigateBack != value) {
              setState(() {
                _playlistsCanNavigateBack = value;
              });
            }
          },
        );
      case 2:
        return NeteaseView(
          key: _neteaseViewKey,
          onAddToPlaylist: _handleAddTrackToPlaylist,
          onDetailStateChanged: (value) {
            if (_neteaseCanNavigateBack != value) {
              setState(() {
                _neteaseCanNavigateBack = value;
              });
            }
          },
        );
      case 3:
        return PlaylistView(
          searchQuery: _activeSearchQuery,
          onAddToPlaylist: _handleAddTrackToPlaylist,
        );
      case 4:
        return const SettingsView();
      default:
        return MusicLibraryView(onAddToPlaylist: _handleAddTrackToPlaylist);
    }
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

    setState(() {
      _searchQuery = value;
      _activeSearchQuery = trimmed;
    });

    final bloc = context.read<MusicLibraryBloc>();
    if (trimmed.isEmpty) {
      bloc.add(const LoadAllTracks());
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
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
    });

    context.read<MusicLibraryBloc>().add(const LoadAllTracks());
  }

  void _handleNavigationChange(int index) {
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
        return '网易云音乐';
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

  String? _currentArtworkPath(PlayerBlocState state) {
    final track = _playerTrack(state);
    final path = track?.artworkPath;
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    return file.existsSync() ? path : null;
  }

  String? _composeHeaderStatsLabel(MusicLibraryState state) {
    if (state is! MusicLibraryLoaded) {
      return null;
    }

    final totalTracks = state.tracks.length;
    final totalDuration = state.tracks.fold<Duration>(
      Duration.zero,
      (previousValue, track) => previousValue + track.duration,
    );

    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);

    return '共 $totalTracks 首歌曲 · ${hours} 小时 ${minutes} 分钟';
  }

  Widget _buildLyricsOverlay({required bool isMac}) {
    if (!_lyricsVisible) {
      return const SizedBox.shrink();
    }

    final track = _lyricsActiveTrack;
    if (track == null) {
      return Center(
        child: Text(
          locale: Locale("zh-Hans", "zh"),
          '暂无播放',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    final artworkSignature = track.artworkPath?.isNotEmpty == true
        ? track.artworkPath
        : 'no_artwork';

    return LyricsOverlay(
      key: ValueKey(
        '${track.id}_${artworkSignature}_${isMac ? 'mac' : 'material'}',
      ),
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
      _lyricsActiveTrack = null;
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
    return showDialog<_WebDavConnectionFormResult>(
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
      showMacosAlertDialog(
        context: context,
        builder: (_) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.check_mark_circled_solid,
            color: CupertinoColors.systemGreen,
            size: 64,
          ),
          title: Text(
            locale: Locale("zh-Hans", "zh"),
            '扫描完成',
            style: MacosTheme.of(context).typography.headline,
          ),
          message: Text(
            locale: Locale("zh-Hans", "zh"),
            message,
            textAlign: TextAlign.center,
            style: MacosTheme.of(context).typography.body,
          ),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            child: const Text(locale: Locale("zh-Hans", "zh"), '好'),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
      showMacosAlertDialog(
        context: context,
        builder: (_) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: CupertinoColors.systemRed,
            size: 64,
          ),
          title: Text(
            locale: Locale("zh-Hans", "zh"),
            '发生错误',
            style: MacosTheme.of(context).typography.headline,
          ),
          message: Text(
            locale: Locale("zh-Hans", "zh"),
            message,
            textAlign: TextAlign.center,
            style: MacosTheme.of(context).typography.body,
          ),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            child: const Text(locale: Locale("zh-Hans", "zh"), '好'),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
