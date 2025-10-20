import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../core/di/dependency_injection.dart';
import '../../domain/entities/webdav_entities.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/usecases/music_usecases.dart';
import '../../domain/usecases/player_usecases.dart';
import '../../domain/repositories/playback_history_repository.dart';
import '../blocs/music_library/music_library_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/playback_history/playback_history_cubit.dart';
import '../blocs/playback_history/playback_history_state.dart';
import '../widgets/macos/macos_player_control_bar.dart';
import '../widgets/macos/macos_music_library_view.dart';
import '../widgets/material/material_player_control_bar.dart';
import '../widgets/material/material_music_library_view.dart';
import '../widgets/common/artwork_thumbnail.dart';
import '../widgets/common/adaptive_scrollbar.dart';
import '../widgets/common/library_search_field.dart';
import '../widgets/common/track_list_tile.dart';
import '../widgets/common/hover_glow_overlay.dart';
import '../../domain/entities/music_entities.dart';
import 'settings/settings_view.dart';
import 'lyrics/lyrics_overlay.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => MusicLibraryBloc(
            getAllTracks: sl<GetAllTracks>(),
            searchTracks: sl<SearchTracks>(),
            scanMusicDirectory: sl<ScanMusicDirectory>(),
            getAllArtists: sl<GetAllArtists>(),
            getAllAlbums: sl<GetAllAlbums>(),
            getLibraryDirectories: sl<GetLibraryDirectories>(),
            scanWebDavDirectory: sl<ScanWebDavDirectory>(),
            getWebDavSources: sl<GetWebDavSources>(),
            ensureWebDavTrackMetadata: sl<EnsureWebDavTrackMetadata>(),
            getWebDavPassword: sl<GetWebDavPassword>(),
            removeLibraryDirectory: sl<RemoveLibraryDirectory>(),
            deleteWebDavSource: sl<DeleteWebDavSource>(),
          )..add(const LoadAllTracks()),
        ),
        BlocProvider(
          create: (context) => PlayerBloc(
            playTrack: sl<PlayTrack>(),
            pausePlayer: sl<PausePlayer>(),
            resumePlayer: sl<ResumePlayer>(),
            stopPlayer: sl<StopPlayer>(),
            seekToPosition: sl<SeekToPosition>(),
            setVolume: sl<SetVolume>(),
            skipToNext: sl<SkipToNext>(),
            skipToPrevious: sl<SkipToPrevious>(),
            audioPlayerService: sl<AudioPlayerService>(),
          )..add(const PlayerRestoreLastSession()),
        ),
        BlocProvider(
          create: (context) =>
              PlaybackHistoryCubit(sl<PlaybackHistoryRepository>()),
        ),
      ],
      child: const HomePageContent(),
    );
  }
}

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
  final MusicLibraryView _libraryView = const MusicLibraryView();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MusicLibraryBloc, MusicLibraryState>(
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
      child: defaultTargetPlatform == TargetPlatform.macOS
          ? _buildMacOSLayout()
          : _buildMaterialLayout(),
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
                                          duration:
                                              const Duration(milliseconds: 280),
                                          switchInCurve: Curves.easeOut,
                                          switchOutCurve: Curves.easeIn,
                                          transitionBuilder:
                                              (child, animation) => FadeTransition(
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

  Widget _buildMaterialLayout() {
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
        final track = _playerTrack(playerState);

        return Scaffold(
          body: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _lyricsVisible ? () => _toggleLyrics(playerState) : null,
                child: AbsorbPointer(
                  absorbing: _lyricsVisible,
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _handleNavigationChange,
                    extended: true,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music),
                        label: Text('音乐库'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.playlist_play_outlined),
                        selectedIcon: Icon(Icons.playlist_play),
                        label: Text('播放列表'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('设置'),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _lyricsVisible
                          ? () => _toggleLyrics(playerState)
                          : null,
                      child: AbsorbPointer(
                        absorbing: _lyricsVisible,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: _lyricsVisible ? 0.55 : 1.0,
                          child: _buildMaterialToolbar(),
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
                                  'material_main_content',
                                ),
                                child: _buildMainContent(),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder:
                                  (child, animation) => FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              child: _lyricsVisible
                                  ? _buildLyricsOverlay(isMac: false)
                                  : const SizedBox.shrink(
                                      key: ValueKey(
                                        'lyrics_overlay_material_empty',
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: MaterialPlayerControlBar(
              onArtworkTap: track == null
                  ? null
                  : () => _toggleLyrics(playerState),
              isLyricsActive: _lyricsVisible,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaterialToolbar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text(
            'Misuzu Music',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          SizedBox(
            width: 260,
            child: LibrarySearchField(
              query: _searchQuery,
              onQueryChanged: _onSearchQueryChanged,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '选择音乐文件夹',
            onPressed: _selectMusicFolder,
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _libraryView;
      case 1:
        return PlaylistView(searchQuery: _activeSearchQuery);
      case 2:
        return const SettingsView();
      default:
        return _libraryView;
    }
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
        return '播放列表';
      case 2:
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
    if (state is MusicLibraryLoaded) {
      final base =
          '${state.tracks.length} 首歌曲 • ${state.artists.length} 位艺术家 • ${state.albums.length} 张专辑';
      if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
        return '$base • 搜索: ${state.searchQuery}';
      }
      return base;
    }
    if (state is MusicLibraryScanning) {
      return '正在扫描音乐库…';
    }
    if (state is MusicLibraryLoading) {
      return '正在加载音乐库…';
    }
    if (state is MusicLibraryError) {
      return '加载失败';
    }
    return null;
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

  Widget _buildLyricsOverlay({required bool isMac}) {
    final track = _lyricsActiveTrack;
    if (track == null) {
      return Center(
        child: Text('暂无播放', style: Theme.of(context).textTheme.titleMedium),
      );
    }

    return LyricsOverlay(
      key: ValueKey('${track.id}_${isMac ? 'mac' : 'material'}'),
      initialTrack: track,
      isMac: isMac,
    );
  }

  Future<void> _selectMusicFolder() async {
    await _selectLocalFolder();
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

          if (defaultTargetPlatform != TargetPlatform.macOS) {
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
                    Expanded(child: Text('正在扫描文件夹: ${result.split('/').last}')),
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

  Future<void> _selectWebDavFolder() async {
    final connection = await _showWebDavConnectionDialog();
    if (connection == null) {
      debugPrint('🌐 WebDAV: 用户取消连接配置');
      return;
    }
    debugPrint(
      '🌐 WebDAV: 连接成功，开始列举目录 (${connection.baseUrl})',
    );

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
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      showMacosAlertDialog(
        context: context,
        builder: (_) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.check_mark_circled_solid,
            color: CupertinoColors.systemGreen,
            size: 64,
          ),
          title: Text(
            '扫描完成',
            style: MacosTheme.of(context).typography.headline,
          ),
          message: Text(
            message,
            textAlign: TextAlign.center,
            style: MacosTheme.of(context).typography.body,
          ),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            child: const Text('好'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } else {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ 扫描完成！$message'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      showMacosAlertDialog(
        context: context,
        builder: (_) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: CupertinoColors.systemRed,
            size: 64,
          ),
          title: Text(
            '发生错误',
            style: MacosTheme.of(context).typography.headline,
          ),
          message: Text(
            message,
            textAlign: TextAlign.center,
            style: MacosTheme.of(context).typography.body,
          ),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            child: const Text('好'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _MacOSGlassHeader extends StatelessWidget {
  const _MacOSGlassHeader({
    required this.height,
    required this.sectionLabel,
    required this.statsLabel,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSelectMusicFolder,
  });

  final double height;
  final String sectionLabel;
  final String? statsLabel;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectMusicFolder;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : MacosColors.labelColor;

    final frostedColor = theme.canvasColor.withOpacity(
      isDarkMode ? 0.35 : 0.36,
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: height,
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Misuzu Music',
                      style: theme.typography.title2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sectionLabel,
                      style: theme.typography.caption1.copyWith(
                        color: textColor.withOpacity(0.68),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (statsLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      statsLabel!,
                      style: theme.typography.caption1.copyWith(
                        color: textColor.withOpacity(0.68),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 320,
                  ),
                  child: LibrarySearchField(
                    query: searchQuery,
                    onQueryChanged: onSearchChanged,
                  ),
                ),
              ),
              MacosTooltip(
                message: '选择音乐文件夹',
                child: _HeaderIconButton(
                  baseColor: textColor.withOpacity(0.72),
                  hoverColor: textColor,
                  size: 36,
                  iconSize: 22,
                  onPressed: onSelectMusicFolder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.baseColor,
    required this.hoverColor,
    required this.onPressed,
    this.size = 36,
    this.iconSize = 22,
  });

  final Color baseColor;
  final Color hoverColor;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
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
    final Color targetColor = _hovering ? widget.hoverColor : widget.baseColor;
    final double scale = _pressing ? 0.95 : (_hovering ? 1.05 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _updateHovering(true),
      onExit: (_) {
        _updateHovering(false);
        _updatePressing(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _updatePressing(true),
        onTapUp: (_) => _updatePressing(false),
        onTapCancel: () => _updatePressing(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: MacosIcon(
                CupertinoIcons.folder,
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


class _WebDavConnectionFormResult {
  const _WebDavConnectionFormResult({
    required this.baseUrl,
    this.username,
    required this.password,
    required this.ignoreTls,
    this.displayName,
  });

  final String baseUrl;
  final String? username;
  final String password;
  final bool ignoreTls;
  final String? displayName;
}

class _WebDavConnectionDialog extends StatefulWidget {
  const _WebDavConnectionDialog({required this.testConnection});

  final TestWebDavConnection testConnection;

  @override
  State<_WebDavConnectionDialog> createState() =>
      _WebDavConnectionDialogState();
}

class _WebDavConnectionDialogState extends State<_WebDavConnectionDialog> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _ignoreTls = false;
  bool _testing = false;
  String? _error;
  String? _urlError;
  String? _passwordError;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    if (isMac) {
      return MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.cloud),
        title: const Text('连接到 WebDAV'),
        message: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MacosField(
                label: '服务器地址',
                placeholder: 'https://example.com/webdav',
                controller: _urlController,
                errorText: _urlError,
                enabled: !_testing,
              ),
              const SizedBox(height: 12),
              _MacosField(
                label: '用户名 (可选)',
                controller: _usernameController,
                enabled: !_testing,
              ),
              const SizedBox(height: 12),
              _MacosField(
                label: '密码',
                controller: _passwordController,
                errorText: _passwordError,
                obscureText: true,
                enabled: !_testing,
              ),
              const SizedBox(height: 12),
              _MacosField(
                label: '自定义名称 (可选)',
                controller: _displayNameController,
                enabled: !_testing,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  MacosCheckbox(
                    value: _ignoreTls,
                    onChanged: _testing
                        ? null
                        : (value) =>
                            setState(() => _ignoreTls = value ?? false),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(child: Text('忽略 TLS 证书校验')),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: MacosTheme.of(context)
                      .typography
                      .body
                      .copyWith(color: MacosColors.systemRedColor),
                ),
              ],
            ],
          ),
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: _testing ? null : _onConnect,
          child: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressCircle(),
                )
              : const Text('连接'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: _testing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      );
    }

    return AlertDialog(
      title: const Text('连接到 WebDAV'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://example.com/webdav',
              errorText: _urlError,
            ),
            enabled: !_testing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration:
                const InputDecoration(labelText: '用户名 (可选)'),
            enabled: !_testing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: '密码',
              errorText: _passwordError,
            ),
            obscureText: true,
            enabled: !_testing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _displayNameController,
            decoration:
                const InputDecoration(labelText: '自定义名称 (可选)'),
            enabled: !_testing,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _ignoreTls,
            onChanged: (value) =>
                setState(() => _ignoreTls = value ?? false),
            title: const Text('忽略 TLS 证书校验'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _testing ? null : _onConnect,
          child: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('连接'),
        ),
      ],
    );
  }

  Future<void> _onConnect() async {
    final rawUrl = _urlController.text.trim();
    String? urlError;
    if (rawUrl.isEmpty) {
      urlError = '请输入服务器地址';
    } else if (!rawUrl.startsWith('http://') &&
        !rawUrl.startsWith('https://')) {
      urlError = '地址必须以 http:// 或 https:// 开头';
    }

    final password = _passwordController.text;
    String? passwordError;
    if (password.isEmpty) {
      passwordError = '请输入密码';
    }

    if (urlError != null || passwordError != null) {
      setState(() {
        _urlError = urlError;
        _passwordError = passwordError;
        _error = null;
      });
      return;
    }

    setState(() {
      _testing = true;
      _error = null;
      _urlError = null;
      _passwordError = null;
    });

    final baseUrl = rawUrl.endsWith('/')
        ? rawUrl.substring(0, rawUrl.length - 1)
        : rawUrl;
    final username = _usernameController.text.trim();
    final passwordValue = password;
    final displayName = _displayNameController.text.trim();

    final tempSource = WebDavSource(
      id: 'preview',
      name: displayName.isEmpty ? 'WebDAV' : displayName,
      baseUrl: baseUrl,
      rootPath: '/',
      username: username.isEmpty ? null : username,
      ignoreTls: _ignoreTls,
    );

    try {
      await widget.testConnection(source: tempSource, password: passwordValue);

      if (!mounted) return;
      Navigator.of(context).pop(
        _WebDavConnectionFormResult(
          baseUrl: baseUrl,
          username: username.isEmpty ? null : username,
          password: passwordValue,
          ignoreTls: _ignoreTls,
          displayName: displayName.isEmpty ? null : displayName,
        ),
      );
    } catch (e) {
      debugPrint('❌ WebDAV: 连接测试失败 -> $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }
}

class _MacosField extends StatelessWidget {
  const _MacosField({
    required this.label,
    required this.controller,
    this.placeholder,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final String? errorText;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: typography.body),
        const SizedBox(height: 6),
        MacosTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          enabled: enabled,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: typography.caption1.copyWith(
              color: MacosColors.systemRedColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _WebDavDirectoryPickerDialog extends StatefulWidget {
  const _WebDavDirectoryPickerDialog({
    required this.listDirectory,
    required this.source,
    required this.password,
  });

  final ListWebDavDirectory listDirectory;
  final WebDavSource source;
  final String password;

  @override
  State<_WebDavDirectoryPickerDialog> createState() =>
      _WebDavDirectoryPickerDialogState();
}

class _WebDavDirectoryPickerDialogState
    extends State<_WebDavDirectoryPickerDialog> {
  late String _currentPath;
  bool _loading = true;
  String? _error;
  List<WebDavEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.source.rootPath;
    _load(_currentPath);
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
    });
    try {
      final entries = await widget.listDirectory(
        source: widget.source,
        password: widget.password,
        path: path,
      );
      if (mounted) {
        setState(() => _entries = entries);
      }
    } catch (e) {
      debugPrint('❌ WebDAV: 目录读取失败 ($path) -> $e');
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _parentPath(String path) {
    final normalized = _normalize(path);
    if (normalized == '/') {
      return '/';
    }
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length <= 1) {
      return '/';
    }
    segments.removeLast();
    return '/${segments.join('/')}';
  }

  String _normalize(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) return '/';
    if (!normalized.startsWith('/')) normalized = '/$normalized';
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择 WebDAV 文件夹'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('当前路径: $_currentPath', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount:
                          _entries.length + (_currentPath == '/' ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (_currentPath != '/' && index == 0) {
                          return ListTile(
                            leading: const Icon(Icons.arrow_upward),
                            title: const Text('..'),
                            onTap: () => _load(_parentPath(_currentPath)),
                          );
                        }
                        final entryIndex = _currentPath == '/'
                            ? index
                            : index - 1;
                        final entry = _entries[entryIndex];
                        return ListTile(
                          leading: Icon(
                            entry.isDirectory ? Icons.folder : Icons.audiotrack,
                          ),
                          title: Text(entry.name),
                          onTap: entry.isDirectory
                              ? () => _load(entry.path)
                              : null,
                          subtitle: Text(entry.path, maxLines: 1),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_currentPath),
          child: const Text('选择此文件夹'),
        ),
      ],
    );
  }
}

class _MacOSNavigationPane extends StatelessWidget {
  const _MacOSNavigationPane({
    required this.width,
    required this.collapsed,
    required this.selectedIndex,
    required this.onSelect,
    required this.onResize,
    this.enabled = true,
  });

  final double width;
  final bool collapsed;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<double> onResize;
  final bool enabled;

  static const _items = <_NavigationItem>[
    _NavigationItem(icon: CupertinoIcons.music_albums_fill, label: '音乐库'),
    _NavigationItem(icon: CupertinoIcons.music_note_list, label: '播放列表'),
    _NavigationItem(icon: CupertinoIcons.settings, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : MacosColors.labelColor;
    final frostedColor = theme.canvasColor.withOpacity(
      isDarkMode ? 0.35 : 0.32,
    );

    return Stack(
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: frostedColor,
                border: Border(
                  right: BorderSide(
                    color: theme.dividerColor.withOpacity(0.35),
                    width: 0.5,
                  ),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 84, 0, 92),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final bool active = selectedIndex == index;
                  return _NavigationTile(
                    item: item,
                    active: active,
                    collapsed: collapsed,
                    textColor: textColor,
                    enabled: enabled,
                    onTap: () => onSelect(index),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: enabled
                ? (details) => onResize(width + details.delta.dx)
                : null,
            child: MouseRegion(
              cursor: enabled
                  ? SystemMouseCursors.resizeColumn
                  : SystemMouseCursors.basic,
              child: const SizedBox(width: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigationItem {
  const _NavigationItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.textColor,
    required this.onTap,
    this.enabled = true,
  });

  final _NavigationItem item;
  final bool active;
  final bool collapsed;
  final Color textColor;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    const activeBackground = Color(0xFF1b66ff);
    final Color inactiveColor = textColor.withOpacity(0.72);
    final Color iconColor = active ? Colors.white : inactiveColor;
    final Color effectiveIconColor = enabled
        ? iconColor
        : iconColor.withOpacity(0.45);
    final Color labelColor = active
        ? Colors.white
        : textColor.withOpacity(0.82);
    final Color effectiveLabelColor = enabled
        ? labelColor
        : labelColor.withOpacity(0.45);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? activeBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: collapsed
              ? Center(
                  child: MacosIcon(
                    item.icon,
                    size: 18,
                    color: effectiveIconColor,
                  ),
                )
              : Row(
                  children: [
                    MacosIcon(item.icon, size: 18, color: effectiveIconColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: theme.typography.body.copyWith(
                          color: effectiveLabelColor,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BlurredArtworkBackground extends StatelessWidget {
  const _BlurredArtworkBackground({
    super.key,
    required this.artworkPath,
    required this.isDarkMode,
  });

  final String artworkPath;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final file = File(artworkPath);
    if (!file.existsSync()) {
      return Container(color: MacosTheme.of(context).canvasColor);
    }

    final Color overlayStrong;
    final Color overlayMid;
    final Color overlayWeak;

    if (isDarkMode) {
      overlayStrong = Colors.black.withOpacity(0.6);
      overlayMid = Colors.black.withOpacity(0.38);
      overlayWeak = Colors.black.withOpacity(0.48);
    } else {
      overlayStrong = Colors.white.withOpacity(0.42);
      overlayMid = Colors.white.withOpacity(0.28);
      overlayWeak = Colors.white.withOpacity(0.22);
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                isDarkMode
                    ? Colors.black.withOpacity(0.22)
                    : Colors.white.withOpacity(0.28),
                isDarkMode ? BlendMode.darken : BlendMode.screen,
              ),
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [overlayStrong, overlayMid, overlayWeak],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 音乐库视图
class MusicLibraryView extends StatefulWidget {
  const MusicLibraryView({super.key});

  @override
  State<MusicLibraryView> createState() => _MusicLibraryViewState();
}

class _MusicLibraryViewState extends State<MusicLibraryView> {
  bool _showList = false;
  String? _activeFilterKey;

  bool _hasArtwork(Track track) {
    final artworkPath = track.artworkPath;
    if (artworkPath == null || artworkPath.isEmpty) {
      return false;
    }
    try {
      return File(artworkPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  Track? _findPreviewTrack(List<Track> tracks) {
    if (tracks.isEmpty) {
      return null;
    }
    final withArtwork = tracks.where(_hasArtwork).toList();
    if (withArtwork.isEmpty) {
      return tracks.first;
    }

    if (withArtwork.length == 1) {
      return withArtwork.first;
    }

    withArtwork.sort((a, b) {
      final at = (a.title).toLowerCase();
      final bt = (b.title).toLowerCase();
      final titleCompare = at.compareTo(bt);
      if (titleCompare != 0) {
        return titleCompare;
      }
      final aa = (a.artist).toLowerCase();
      final ba = (b.artist).toLowerCase();
      final artistCompare = aa.compareTo(ba);
      if (artistCompare != 0) {
        return artistCompare;
      }
      final al = (a.album).toLowerCase();
      final bl = (b.album).toLowerCase();
      final albumCompare = al.compareTo(bl);
      if (albumCompare != 0) {
        return albumCompare;
      }
      return a.filePath.compareTo(b.filePath);
    });
    return withArtwork[withArtwork.length ~/ 2];
  }

  bool _isTrackInDirectory(Track track, String directoryPath) {
    if (track.sourceType != TrackSourceType.local) {
      return false;
    }
    final normalizedDirectory = p.normalize(directoryPath);
    final trackPath = p.normalize(track.filePath);
    if (trackPath == normalizedDirectory) {
      return true;
    }
    return p.isWithin(normalizedDirectory, trackPath);
  }

  List<_DirectorySummaryData> _buildLibrarySummariesData(
    MusicLibraryLoaded state,
  ) {
    final localSummaries = <_DirectorySummaryData>[];
    final localTracks = state.tracks
        .where((track) => track.sourceType == TrackSourceType.local)
        .toList();

    final normalizedDirectories = <String>{
      ...state.libraryDirectories.map((dir) => p.normalize(dir)),
    };

    if (normalizedDirectories.isEmpty) {
      normalizedDirectories.addAll(
        localTracks.map(
          (track) => p.normalize(File(track.filePath).parent.path),
        ),
      );
    }

    for (final directory in normalizedDirectories) {
      final normalizedDirectory = directory;
      final directoryTracks = localTracks
          .where((track) => _isTrackInDirectory(track, normalizedDirectory))
          .toList();

      if (directoryTracks.isEmpty) {
        continue;
      }

      final previewTrack = _findPreviewTrack(directoryTracks);
      final hasArtwork = previewTrack != null && _hasArtwork(previewTrack);
      final displayName = normalizedDirectory.isEmpty
          ? '全部歌曲'
          : p.basename(normalizedDirectory);

      localSummaries.add(
        _DirectorySummaryData(
          filterKey: normalizedDirectory,
          displayName: displayName,
          directoryPath: normalizedDirectory,
          previewTrack: previewTrack,
          totalTracks: directoryTracks.length,
          hasArtwork: hasArtwork,
        ),
      );
    }

    final remoteSummaries = <_DirectorySummaryData>[];
    for (final source in state.webDavSources) {
      final remoteTracks = state.tracks
          .where(
            (track) =>
                track.sourceType == TrackSourceType.webdav &&
                track.sourceId == source.id,
          )
          .toList();
      if (remoteTracks.isEmpty) {
        continue;
      }

      final previewTrack = _findPreviewTrack(remoteTracks);
      final hasArtwork = previewTrack != null && _hasArtwork(previewTrack);
      remoteSummaries.add(
        _DirectorySummaryData(
          filterKey: 'webdav://${source.id}',
          displayName: source.name,
          directoryPath: source.rootPath,
          webDavSource: source,
          previewTrack: previewTrack,
          totalTracks: remoteTracks.length,
          hasArtwork: hasArtwork,
        ),
      );
    }

    final allPreviewTrack = _findPreviewTrack(state.tracks);
    final allHasArtwork =
        allPreviewTrack != null && _hasArtwork(allPreviewTrack);
    final allSummary = _DirectorySummaryData(
      filterKey: _DirectorySummaryData.allKey,
      displayName: '全部歌曲',
      directoryPath: null,
      previewTrack: allPreviewTrack,
      totalTracks: state.tracks.length,
      hasArtwork: allHasArtwork,
    );

    final filteredLocalSummaries =
        localSummaries.length == 1 &&
                localSummaries.first.totalTracks == allSummary.totalTracks
            ? <_DirectorySummaryData>[]
            : List<_DirectorySummaryData>.from(localSummaries);

    final summaries = [
      ...filteredLocalSummaries,
      ...remoteSummaries,
    ];

    summaries.sort((a, b) {
      if (a.isRemote != b.isRemote) {
        return a.isRemote ? 1 : -1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    if (summaries.isEmpty) {
      summaries.add(allSummary);
    } else {
      summaries.insert(0, allSummary);
    }

    return summaries;
  }

  Future<void> _confirmRemoveSummary(_DirectorySummaryData summary) async {
    if (summary.isAll) {
      return;
    }

    final isRemote = summary.isRemote;
    final title = isRemote ? '移除 WebDAV 音乐库' : '移除音乐文件夹';
    final name = summary.displayName;
    final message = isRemote
        ? '确定要移除 "$name" 吗？移除后将不再同步该 WebDAV 源的歌曲。'
        : '确定要移除 "$name" 目录吗？这将从音乐库中移除该目录中的所有歌曲。';

    bool? confirmed;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      confirmed = await showMacosAlertDialog<bool>(
        context: context,
        builder: (context) => MacosAlertDialog(
          appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
          title: Text(title),
          message: Text(message),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
          secondaryButton: PushButton(
            controlSize: ControlSize.large,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('移除'),
            ),
          ],
        ),
      );
    }

    if (confirmed != true) {
      return;
    }

    final bloc = context.read<MusicLibraryBloc>();
    if (isRemote && summary.webDavSource != null) {
      bloc.add(RemoveWebDavSourceEvent(summary.webDavSource!));
    } else if (summary.directoryPath != null) {
      bloc.add(RemoveLibraryDirectoryEvent(summary.directoryPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;

    return BlocBuilder<MusicLibraryBloc, MusicLibraryState>(
      builder: (context, state) {
        if (state is MusicLibraryLoading || state is MusicLibraryScanning) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProgressCircle(),
                SizedBox(height: 16),
                Text('正在加载音乐库...'),
              ],
            ),
          );
        }

        if (state is MusicLibraryError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MacosIcon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 64,
                  color: CupertinoColors.systemRed,
                ),
                const SizedBox(height: 16),
                Text('加载失败', style: MacosTheme.of(context).typography.title1),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: MacosTheme.of(context).typography.body.copyWith(
                    color: MacosColors.systemGrayColor,
                  ),
                ),
                const SizedBox(height: 16),
                PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () {
                    context.read<MusicLibraryBloc>().add(const LoadAllTracks());
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (state is MusicLibraryLoaded) {
          if (state.tracks.isEmpty) {
            return _PlaylistMessage(
              icon: CupertinoIcons.music_albums,
              message: '音乐库为空',
            );
          }

          final summariesData = _buildLibrarySummariesData(state);
          final filterKeys = summariesData
              .map((summary) => summary.filterKey)
              .toSet();
          if (_activeFilterKey != null &&
              !filterKeys.contains(_activeFilterKey)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _activeFilterKey = null;
                _showList = false;
              });
            });
          }

          final hasActiveSearch =
              state.searchQuery != null && state.searchQuery!.trim().isNotEmpty;
          if (hasActiveSearch && !_showList) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _showList = true);
            });
          }
          if (hasActiveSearch && _activeFilterKey != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _activeFilterKey = null;
              });
            });
          }

          if (!_showList) {
            final bool isDarkMode = isMac
                ? MacosTheme.of(context).brightness == Brightness.dark
                : Theme.of(context).brightness == Brightness.dark;

            return LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.of(context).size.width;
                const EdgeInsets padding = EdgeInsets.all(24);
                const double spacing = 24;
                const double preferredTileWidth = 540;
                final double contentWidth = math.max(
                  0,
                  maxWidth - padding.horizontal,
                );
                final int columnCount = contentWidth > 0
                    ? math.max(
                        1,
                        math.min(
                          3,
                          ((contentWidth + spacing) /
                                  (preferredTileWidth + spacing))
                              .floor(),
                        ),
                      )
                    : 1;
                final double rawTileWidth = columnCount == 1
                    ? contentWidth
                    : (contentWidth - (columnCount - 1) * spacing) /
                          columnCount;
                final double tileWidth = columnCount == 1
                    ? math.min(preferredTileWidth, contentWidth)
                    : math.min(preferredTileWidth, rawTileWidth);

                return AdaptiveScrollbar(
                  isDarkMode: isDarkMode,
                  margin: const EdgeInsets.only(right: 6, top: 16, bottom: 16),
                  builder: (controller) {
                    return SingleChildScrollView(
                      controller: controller,
                      padding: padding,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: math.max(0, contentWidth),
                        ),
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final summary in summariesData)
                              SizedBox(
                                width: columnCount == 1
                                    ? (contentWidth <= 0
                                          ? preferredTileWidth
                                          : math.min(
                                              preferredTileWidth,
                                              contentWidth,
                                            ))
                                    : (tileWidth <= 0
                                          ? preferredTileWidth
                                          : tileWidth),
                                child: _LibrarySummaryView(
                                  filterKey: summary.filterKey,
                                  displayName: summary.displayName,
                                  directoryPath: summary.directoryPath,
                                  webDavSource: summary.webDavSource,
                                  previewTrack: summary.previewTrack,
                                  totalTracks: summary.totalTracks,
                                  hasArtwork: summary.hasArtwork,
                                  onTap: () {
                                    setState(() {
                                      _showList = true;
                                      _activeFilterKey = summary.isAll
                                          ? null
                                          : summary.filterKey;
                                    });
                                  },
                                  onRemove: summary.isAll
                                      ? null
                                      : () => _confirmRemoveSummary(summary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }

          final filteredTracks = _activeFilterKey == null
              ? state.tracks
              : state.tracks.where((track) {
                  final key = _activeFilterKey!;
                  if (_DirectorySummaryData.isAllKey(key)) {
                    return true;
                  }
                  if (key.startsWith('webdav://')) {
                    final sourceId = key.substring('webdav://'.length);
                    return track.sourceType == TrackSourceType.webdav &&
                        track.sourceId == sourceId;
                  }
                  return _isTrackInDirectory(track, key);
                }).toList();

          final listWidget = isMac
              ? MacOSMusicLibraryView(
                  tracks: filteredTracks,
                  artists: state.artists,
                  albums: state.albums,
                  searchQuery: state.searchQuery,
                )
              : MaterialMusicLibraryView(
                  tracks: filteredTracks,
                  artists: state.artists,
                  albums: state.albums,
                  searchQuery: state.searchQuery,
                );

          if (_activeFilterKey != null) {
            return Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.escape):
                    const _ExitLibraryOverviewIntent(),
              },
              child: Actions(
                actions: {
                  _ExitLibraryOverviewIntent:
                      CallbackAction<_ExitLibraryOverviewIntent>(
                        onInvoke: (intent) {
                          setState(() {
                            _showList = false;
                            _activeFilterKey = null;
                          });
                          return null;
                        },
                      ),
                },
                child: Focus(autofocus: true, child: listWidget),
              ),
            );
          }

          return listWidget;
        }

        return _PlaylistMessage(
          icon: CupertinoIcons.music_albums,
          message: '音乐库为空',
        );
      },
    );
  }
}

class _LibrarySummaryView extends StatelessWidget {
  const _LibrarySummaryView({
    required this.filterKey,
    required this.displayName,
    required this.directoryPath,
    required this.webDavSource,
    required this.previewTrack,
    required this.totalTracks,
    required this.hasArtwork,
    required this.onTap,
    this.onRemove,
  });

  final String filterKey;
  final String displayName;
  final String? directoryPath;
  final WebDavSource? webDavSource;
  final Track? previewTrack;
  final int totalTracks;
  final bool hasArtwork;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  bool get _isRemote => webDavSource != null;

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final isDark = isMac
        ? MacosTheme.of(context).brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.72)
        : Colors.black.withOpacity(0.64);

    final subtitle = _isRemote
        ? '${webDavSource!.baseUrl}${webDavSource!.rootPath}'
        : (directoryPath == null || directoryPath!.isEmpty
            ? '所有目录'
            : p.normalize(directoryPath!));

    final iconData = _isRemote
        ? CupertinoIcons.cloud
        : CupertinoIcons.folder_solid;

    final card = HoverGlowOverlay(
      isDarkMode: isDark,
      borderRadius: BorderRadius.circular(20),
      cursor: SystemMouseCursors.click,
      glowRadius: 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.6),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.42)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: hasArtwork &&
                  previewTrack?.artworkPath != null &&
                  File(previewTrack!.artworkPath!).existsSync()
              ? Image.file(
                  File(previewTrack!.artworkPath!),
                  fit: BoxFit.cover,
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF3C3C3E), const Color(0xFF1C1C1E)]
                          : [const Color(0xFFE9F1FF), const Color(0xFFFDFEFF)],
                    ),
                  ),
                  child: Icon(
                    iconData,
                    size: 60,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
        ),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onSecondaryTapDown: onRemove == null
            ? null
            : (details) => _showContextMenu(context, details.globalPosition),
        onLongPressStart: onRemove == null
            ? null
            : (details) => _showContextMenu(context, details.globalPosition),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            card,
            const SizedBox(width: 22),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalTracks 首歌曲 · 点击查看全部',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    if (onRemove == null) {
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'remove',
          child: Text('移除音乐库'),
        ),
      ],
    );
    if (result == 'remove') {
      onRemove?.call();
    }
  }
}

class _ExitLibraryOverviewIntent extends Intent {
  const _ExitLibraryOverviewIntent();
}

class _DirectorySummaryData {
  const _DirectorySummaryData({
    required this.filterKey,
    required this.displayName,
    required this.previewTrack,
    required this.totalTracks,
    required this.hasArtwork,
    this.directoryPath,
    this.webDavSource,
  });

  final String filterKey;
  final String displayName;
  final Track? previewTrack;
  final int totalTracks;
  final bool hasArtwork;
  final String? directoryPath;
  final WebDavSource? webDavSource;

  bool get isRemote => webDavSource != null;
  bool get isAll => filterKey == allKey;

  static const String allKey = '__all__';
  static bool isAllKey(String key) => key == allKey;
}

// 其他视图占位符
class PlaylistView extends StatelessWidget {
  const PlaylistView({super.key, required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = searchQuery.trim();

    return BlocBuilder<PlaybackHistoryCubit, PlaybackHistoryState>(
      builder: (context, state) {
        switch (state.status) {
          case PlaybackHistoryStatus.loading:
            return const Center(child: ProgressCircle());
          case PlaybackHistoryStatus.error:
            return _PlaylistMessage(
              icon: CupertinoIcons.exclamationmark_triangle,
              message: state.errorMessage ?? '播放列表加载失败',
            );
          case PlaybackHistoryStatus.empty:
            return _PlaylistMessage(
              icon: CupertinoIcons.music_note_list,
              message: '暂无播放列表',
            );
          case PlaybackHistoryStatus.loaded:
            return _PlaylistHistoryList(
              entries: state.entries,
              searchQuery: trimmedQuery,
            );
        }
      },
    );
  }
}

class _PlaylistHistoryList extends StatelessWidget {
  const _PlaylistHistoryList({
    required this.entries,
    required this.searchQuery,
  });

  final List<PlaybackHistoryEntry> entries;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final dividerColor = isMac
        ? MacosTheme.of(context).dividerColor
        : Theme.of(context).dividerColor;
    final artworkBackground = isMac
        ? MacosColors.controlBackgroundColor
        : Theme.of(context).colorScheme.surfaceVariant;
    final artworkPlaceholder = isMac
        ? const MacosIcon(
            CupertinoIcons.music_note,
            color: MacosColors.systemGrayColor,
            size: 20,
          )
        : Icon(
            Icons.music_note,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

    final normalizedQuery = searchQuery.isEmpty
        ? null
        : searchQuery.toLowerCase();
    final filteredEntries = normalizedQuery == null
        ? entries
        : entries.where((entry) {
            final track = entry.track;
            final title = track.title.toLowerCase();
            final artist = track.artist.toLowerCase();
            final album = track.album.toLowerCase();
            return title.contains(normalizedQuery) ||
                artist.contains(normalizedQuery) ||
                album.contains(normalizedQuery);
          }).toList();

    if (filteredEntries.isEmpty) {
      return _PlaylistMessage(
        icon: CupertinoIcons.search,
        message: '未找到匹配的播放记录',
      );
    }

    final isScrollbarDark = isMac
        ? MacosTheme.of(context).brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;

    return AdaptiveScrollbar(
      isDarkMode: isScrollbarDark,
      builder: (controller) {
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredEntries.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor,
            indent: isMac ? 88 : 80,
          ),
          itemBuilder: (context, index) {
            final entry = filteredEntries[index];
            final track = entry.track;
            final playCount = entry.playCount;
            return TrackListTile(
              index: index + 1,
              leading: ArtworkThumbnail(
                artworkPath: track.artworkPath,
                size: 48,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: artworkBackground,
                borderColor: dividerColor,
                placeholder: artworkPlaceholder,
              ),
              title: track.title,
              artistAlbum: '${track.artist} • ${track.album}',
              duration: _formatDuration(track.duration),
              meta: '${_formatPlayedAt(entry.playedAt)} | ${playCount} 次播放',
              onTap: () =>
                  _playTrack(context, track, fingerprint: entry.fingerprint),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPlayedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inMinutes < 60) return '${difference.inMinutes} 分钟前';
    if (difference.inHours < 24) return '${difference.inHours} 小时前';

    final twoDigits = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:$twoDigits';
  }

  void _playTrack(BuildContext context, Track track, {String? fingerprint}) {
    context.read<PlayerBloc>().add(
      PlayerPlayTrack(track, fingerprint: fingerprint),
    );
  }
}

class _PlaylistMessage extends StatelessWidget {
  const _PlaylistMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final isDark = isMac
        ? MacosTheme.of(context).brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text(
            message,
            style:
                (isMac
                        ? MacosTheme.of(context).typography.title1
                        : Theme.of(context).textTheme.headlineSmall)
                    ?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
