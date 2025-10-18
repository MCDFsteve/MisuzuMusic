import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../core/di/dependency_injection.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/usecases/music_usecases.dart';
import '../../domain/usecases/player_usecases.dart';
import '../../domain/repositories/playback_history_repository.dart';
import '../blocs/music_library/music_library_bloc.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/playback_history/playback_history_cubit.dart';
import '../blocs/playback_history/playback_history_state.dart';
import '../widgets/macos/macos_player_control_bar.dart';
import '../widgets/macos/macos_music_library_view.dart';
import '../widgets/material/material_player_control_bar.dart';
import '../widgets/material/material_music_library_view.dart';
import '../widgets/common/artwork_thumbnail.dart';
import '../../domain/entities/music_entities.dart';
import 'settings/settings_view.dart';

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
          create: (context) => PlaybackHistoryCubit(sl<PlaybackHistoryRepository>()),
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<MusicLibraryBloc, MusicLibraryState>(
      listener: (context, state) {
        if (state is MusicLibraryScanComplete) {
          _showScanCompleteDialog(context, state.tracksAdded);
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
    return BlocBuilder<PlayerBloc, PlayerBlocState>(
      builder: (context, playerState) {
        final artworkPath = _currentArtworkPath(playerState);
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
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: artworkPath != null
                              ? _BlurredArtworkBackground(
                                  key: ValueKey<String>(artworkPath),
                                  artworkPath: artworkPath,
                                  isDarkMode:
                                      MacosTheme.of(context).brightness == Brightness.dark,
                                )
                              : Container(
                                  key: const ValueKey<String>('default_background'),
                                  color: MacosTheme.of(context).canvasColor,
                                ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      _MacOSNavigationPane(
                        width: _navigationWidth,
                        collapsed: _navigationWidth <= 112,
                        selectedIndex: _selectedIndex,
                        onSelect: (index) {
                          if (_selectedIndex != index) {
                            setState(() => _selectedIndex = index);
                          }
                        },
                        onResize: (width) {
                          setState(() {
                            _navigationWidth = width.clamp(_navMinWidth, _navMaxWidth);
                          });
                        },
                      ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _MacOSGlassHeader(
                                  height: headerHeight,
                                  sectionLabel: sectionLabel,
                                  statsLabel: statsLabel,
                                  onSelectMusicFolder: _selectMusicFolder,
                                ),
                                Expanded(
                                  child: _buildMainContent(),
                                ),
                                const MacOSPlayerControlBar(),
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
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
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
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: Text('搜索'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                _buildMaterialToolbar(),
                Expanded(child: _buildMainContent()),
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
        child: const MaterialPlayerControlBar(),
      ),
    );
  }

  Widget _buildMaterialToolbar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
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
        return const MusicLibraryView();
      case 1:
        return const PlaylistView();
      case 2:
        return const SearchView();
      case 3:
        return const SettingsView();
      default:
        return const MusicLibraryView();
    }
  }

  String _currentSectionLabel(int index) {
    switch (index) {
      case 0:
        return '音乐库';
      case 1:
        return '播放列表';
      case 2:
        return '搜索';
      case 3:
        return '设置';
      default:
        return '音乐库';
    }
  }

  String? _currentArtworkPath(PlayerBlocState state) {
    String? path;
    if (state is PlayerPlaying) {
      path = state.track.artworkPath;
    } else if (state is PlayerPaused) {
      path = state.track.artworkPath;
    } else if (state is PlayerLoading && state.track != null) {
      path = state.track!.artworkPath;
    }

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

  Future<void> _selectMusicFolder() async {
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
                    Expanded(
                      child: Text('正在扫描文件夹: ${result.split('/').last}'),
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

  void _showScanCompleteDialog(BuildContext context, int tracksAdded) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      showMacosAlertDialog(
        context: context,
        builder: (_) => MacosAlertDialog(
          appIcon: const MacosIcon(CupertinoIcons.check_mark_circled_solid,
                                   color: CupertinoColors.systemGreen, size: 64),
          title: Text(
            '扫描完成',
            style: MacosTheme.of(context).typography.headline,
          ),
          message: Text(
            '添加了 $tracksAdded 首新歌曲',
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
          content: Text('✅ 扫描完成！添加了 $tracksAdded 首新歌曲'),
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
          appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle_fill,
                                   color: CupertinoColors.systemRed, size: 64),
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
    required this.onSelectMusicFolder,
  });

  final double height;
  final String sectionLabel;
  final String? statsLabel;
  final VoidCallback onSelectMusicFolder;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : MacosColors.labelColor;

    final frostedColor = theme.canvasColor.withOpacity(isDarkMode ? 0.35 : 0.36);

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
              MacosTooltip(
                message: '选择音乐文件夹',
                child: MacosIconButton(
                  backgroundColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: onSelectMusicFolder,
                  icon: _HeaderIconButton(color: textColor),
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
  const _HeaderIconButton({required this.color});

  final Color color;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color;
    final isLightBase = baseColor.computeLuminance() > 0.5;
    final hoverTarget = isLightBase
        ? baseColor.withOpacity(0.9)
        : Color.lerp(baseColor, MacosColors.controlAccentColor, 0.35)!;

    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 + (_controller.value * 0.08);
          final color = Color.lerp(baseColor, hoverTarget, _controller.value);
          return Transform.scale(
            scale: scale,
            child: MacosIcon(
              CupertinoIcons.folder,
              size: 18,
              color: color,
            ),
          );
        },
      ),
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
  });

  final double width;
  final bool collapsed;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<double> onResize;

  static const _items = <_NavigationItem>[
    _NavigationItem(
      icon: CupertinoIcons.music_albums_fill,
      label: '音乐库',
    ),
    _NavigationItem(
      icon: CupertinoIcons.music_note_list,
      label: '播放列表',
    ),
    _NavigationItem(
      icon: CupertinoIcons.search,
      label: '搜索',
    ),
    _NavigationItem(
      icon: CupertinoIcons.settings,
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : MacosColors.labelColor;
    final frostedColor = theme.canvasColor.withOpacity(isDarkMode ? 0.35 : 0.32);

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
            onHorizontalDragUpdate: (details) => onResize(width + details.delta.dx),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
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
  });

  final _NavigationItem item;
  final bool active;
  final bool collapsed;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    const activeBackground = Color(0xFF1b66ff);
    final Color inactiveColor = textColor.withOpacity(0.72);

    return GestureDetector(
      onTap: onTap,
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
                  color: active ? Colors.white : inactiveColor,
                ),
              )
            : Row(
                children: [
                  MacosIcon(
                    item.icon,
                    size: 18,
                    color: active ? Colors.white : inactiveColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: theme.typography.body.copyWith(
                        color: active ? Colors.white : textColor.withOpacity(0.82),
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
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
              child: Image.file(
                file,
                fit: BoxFit.cover,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  overlayStrong,
                  overlayMid,
                  overlayWeak,
                ],
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
  final Random _random = Random();
  Track? _summaryTrack;
  bool _summaryHasArtwork = false;

  void _selectSummaryTrack(List<Track> tracks) {
    if (tracks.isEmpty) {
      _summaryTrack = null;
      _summaryHasArtwork = false;
      return;
    }

    final withArtwork = tracks.where((track) {
      final artworkPath = track.artworkPath;
      if (artworkPath == null || artworkPath.isEmpty) {
        return false;
      }
      try {
        return File(artworkPath).existsSync();
      } catch (_) {
        return false;
      }
    }).toList();

    Track chosen;
    bool hasArtwork;

    if (withArtwork.isNotEmpty) {
      chosen = withArtwork[_random.nextInt(withArtwork.length)];
      hasArtwork = true;
    } else {
      chosen = tracks[_random.nextInt(tracks.length)];
      hasArtwork = false;
    }

    _summaryTrack = chosen;
    _summaryHasArtwork = hasArtwork;
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
                Text(
                  '加载失败',
                  style: MacosTheme.of(context).typography.title1,
                ),
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

          _selectSummaryTrack(state.tracks);

          final hasActiveSearch =
              state.searchQuery != null && state.searchQuery!.trim().isNotEmpty;
          if (hasActiveSearch && !_showList) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _showList = true);
            });
          }

          if (!_showList) {
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _LibrarySummaryView(
                  track: _summaryTrack!,
                  totalTracks: state.tracks.length,
                  hasArtwork: _summaryHasArtwork,
                  onTap: () => setState(() => _showList = true),
                ),
              ),
            );
          }

          final listWidget = isMac
              ? MacOSMusicLibraryView(
                  tracks: state.tracks,
                  artists: state.artists,
                  albums: state.albums,
                  searchQuery: state.searchQuery,
                )
              : MaterialMusicLibraryView(
                  tracks: state.tracks,
                  artists: state.artists,
                  albums: state.albums,
                  searchQuery: state.searchQuery,
                );

          final backButtonColor = isMac
              ? (MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black)
              : Theme.of(context).colorScheme.onSurface;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: isMac
                    ? PushButton(
                        controlSize: ControlSize.regular,
                        onPressed: () => setState(() => _showList = false),
                        secondary: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            MacosIcon(CupertinoIcons.chevron_back, size: 14),
                            SizedBox(width: 6),
                            Text('返回音乐库'),
                          ],
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () => setState(() => _showList = false),
                        icon: const Icon(CupertinoIcons.chevron_back),
                        label: const Text('返回音乐库'),
                        style: TextButton.styleFrom(foregroundColor: backButtonColor),
                      ),
              ),
              const SizedBox(height: 12),
              Expanded(child: listWidget),
            ],
          );
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
    required this.track,
    required this.totalTracks,
    required this.hasArtwork,
    required this.onTap,
  });

  final Track track;
  final int totalTracks;
  final bool hasArtwork;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final isDark = isMac
        ? MacosTheme.of(context).brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;

    final background = isDark
        ? const Color(0xFF1C1C1E).withOpacity(0.38)
        : Colors.white.withOpacity(0.75);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.1);
    final textColor = hasArtwork
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    final subtitleColor = hasArtwork
        ? Colors.white.withOpacity(0.8)
        : (isDark ? Colors.white.withOpacity(0.75) : Colors.black54);

    final directory = File(track.filePath).parent.path;
    final folderName = p.basename(directory);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.45)
                  : Colors.black.withOpacity(0.12),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasArtwork && track.artworkPath != null && File(track.artworkPath!).existsSync())
                ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.55),
                    ],
                  ).createShader(rect),
                  blendMode: BlendMode.darken,
                  child: Image.file(
                    File(track.artworkPath!),
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
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
                    CupertinoIcons.music_albums,
                    size: 80,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(color: borderColor, width: 0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '音乐库',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      folderName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      directory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$totalTracks 首歌曲 · 点击查看全部',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 其他视图占位符
class PlaylistView extends StatelessWidget {
  const PlaylistView({super.key});

  @override
  Widget build(BuildContext context) {
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
            return _PlaylistHistoryList(entries: state.entries);
        }
      },
    );
  }
}

class _PlaylistHistoryList extends StatelessWidget {
  const _PlaylistHistoryList({required this.entries});

  final List<PlaybackHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final isDark = isMac
        ? MacosTheme.of(context).brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: isMac
                ? MacosTooltip(
                    message: '清空播放记录',
                    child: MacosIconButton(
                      shape: BoxShape.circle,
                      onPressed: () => context.read<PlaybackHistoryCubit>().clearHistory(),
                      icon: MacosIcon(
                        CupertinoIcons.trash,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      boxConstraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      CupertinoIcons.trash,
                      size: 18,
                      color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                    ),
                    tooltip: '清空播放记录',
                    onPressed: () => context.read<PlaybackHistoryCubit>().clearHistory(),
                  ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _PlaybackHistoryTile(entry: entry, isMac: isMac, isDark: isDark);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackHistoryTile extends StatelessWidget {
  const _PlaybackHistoryTile({required this.entry, required this.isMac, required this.isDark});

  final PlaybackHistoryEntry entry;
  final bool isMac;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final titleStyle = isMac
        ? MacosTheme.of(context).typography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            )
        : Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            );

    final subtitleColor = isDark ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.65);
    final subtitleStyle = isMac
        ? MacosTheme.of(context).typography.caption1.copyWith(color: subtitleColor)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: subtitleColor);

    final timeStyle = (isMac
            ? MacosTheme.of(context).typography.caption1
            : Theme.of(context).textTheme.bodySmall)
        ?.copyWith(color: subtitleColor);

    if (isMac) {
      return MacosListTile(
        mouseCursor: SystemMouseCursors.click,
        leading: ArtworkThumbnail(
          artworkPath: entry.track.artworkPath,
          size: 48,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: MacosColors.controlBackgroundColor,
          borderColor: MacosTheme.of(context).dividerColor,
          placeholder: const MacosIcon(
            CupertinoIcons.music_note,
            color: MacosColors.systemGrayColor,
            size: 20,
          ),
        ),
        title: Text(
          entry.track.title,
          style: titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.track.artist} • ${entry.track.album}',
                style: subtitleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatPlayedAt(entry.playedAt),
                style: timeStyle,
              ),
            ],
          ),
        ),
        onClick: () => _playTrack(context, entry.track),
      );
    }

    return Material(
      color: Colors.transparent,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: ArtworkThumbnail(
          artworkPath: entry.track.artworkPath,
          size: 48,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          borderColor: Theme.of(context).dividerColor,
          placeholder: Icon(
            Icons.music_note,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(entry.track.title, style: titleStyle),
        subtitle: Text(
          '${entry.track.artist} • ${entry.track.album}',
          style: subtitleStyle,
        ),
        trailing: Text(_formatPlayedAt(entry.playedAt), style: timeStyle),
        onTap: () => _playTrack(context, entry.track),
      ),
    );
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

  void _playTrack(BuildContext context, Track track) {
    context.read<PlayerBloc>().add(PlayerPlayTrack(track));
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
            style: (isMac
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

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = value.trim();
      if (!mounted) return;
      if (query.isEmpty) {
        context.read<MusicLibraryBloc>().add(const LoadAllTracks());
      } else {
        context.read<MusicLibraryBloc>().add(SearchTracksEvent(query));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final isDark = isMac
        ? MacosTheme.of(context).brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final placeholderColor = textColor.withOpacity(0.4);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          if (isMac)
            MacosSearchField(
              controller: _controller,
              placeholder: '搜索歌曲、艺术家或专辑...',
              placeholderStyle: MacosTheme.of(context).typography.body.copyWith(
                    color: placeholderColor,
                  ),
              style: MacosTheme.of(context).typography.body.copyWith(
                    color: textColor,
                  ),
              onChanged: _onQueryChanged,
              decoration: const BoxDecoration(),
            )
          else
            TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: '搜索歌曲、艺术家或专辑...',
                hintStyle: TextStyle(color: placeholderColor),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: BlocBuilder<MusicLibraryBloc, MusicLibraryState>(
              builder: (context, state) {
                if (state is MusicLibraryLoading || state is MusicLibraryScanning) {
                  return const Center(child: ProgressCircle());
                }

                if (state is MusicLibraryError) {
                  return Center(
                    child: Text(
                      state.message,
                      style: TextStyle(color: textColor),
                    ),
                  );
                }

                if (state is MusicLibraryLoaded) {
                  final query = _controller.text.trim();
                  if (query.isEmpty) {
                    return _SearchPlaceholder(isDark: isDark);
                  }

                  if (state.tracks.isEmpty) {
                    return Center(
                      child: Text(
                        '未找到匹配的歌曲',
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                    );
                  }

                  return isMac
                      ? MacOSMusicLibraryView(
                          tracks: state.tracks,
                          artists: state.artists,
                          albums: state.albums,
                          searchQuery: state.searchQuery,
                        )
                      : MaterialMusicLibraryView(
                          tracks: state.tracks,
                          artists: state.artists,
                          albums: state.albums,
                          searchQuery: state.searchQuery,
                        );
                }

                return _SearchPlaceholder(isDark: isDark);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : Colors.black;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 60,
            color: color.withOpacity(0.55),
          ),
          const SizedBox(height: 16),
          Text(
            '输入关键词开始搜索',
            style: TextStyle(color: color, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
