import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/dependency_injection.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/usecases/music_usecases.dart';
import '../../domain/usecases/player_usecases.dart';
import '../blocs/music_library/music_library_bloc.dart';
import '../blocs/player/player_bloc.dart';
import '../widgets/macos/macos_player_control_bar.dart';
import '../widgets/macos/macos_music_library_view.dart';
import '../widgets/material/material_player_control_bar.dart';
import '../widgets/material/material_music_library_view.dart';

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
        final theme = MacosTheme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        final artworkPath = _currentArtworkPath(playerState);

        return MacosWindow(
          titleBar: _buildMacOSTitleBar(
            context: context,
            isDarkMode: isDarkMode,
            artworkPath: artworkPath,
          ),
          sidebar: Sidebar(
            minWidth: 200,
            maxWidth: 300,
            builder: (context, scrollController) {
              return SidebarItems(
                currentIndex: _selectedIndex,
                onChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                scrollController: scrollController,
                itemSize: SidebarItemSize.large,
                items: const [
                  SidebarItem(
                    leading: MacosIcon(CupertinoIcons.music_albums_fill),
                    label: Text('音乐库'),
                  ),
                  SidebarItem(
                    leading: MacosIcon(CupertinoIcons.music_note_list),
                    label: Text('播放列表'),
                  ),
                  SidebarItem(
                    leading: MacosIcon(CupertinoIcons.search),
                    label: Text('搜索'),
                  ),
                  SidebarItem(
                    leading: MacosIcon(CupertinoIcons.settings),
                    label: Text('设置'),
                  ),
                ],
              );
            },
          ),
          child: MacosScaffold(
            toolBar: null,
            children: [
              ContentArea(
                builder: (context, scrollController) {
                  return Stack(
                    fit: StackFit.expand,
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
                                  isDarkMode: isDarkMode,
                                )
                              : Container(
                                  key: const ValueKey<String>('default_background'),
                                  color: theme.canvasColor,
                                ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildMainContent()),
                          const MacOSPlayerControlBar(),
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

  TitleBar _buildMacOSTitleBar({
    required BuildContext context,
    required bool isDarkMode,
    String? artworkPath,
  }) {
    final theme = MacosTheme.of(context);
    final borderColor = theme.dividerColor.withOpacity(0.3);

    final file = artworkPath != null && artworkPath.isNotEmpty
        ? File(artworkPath)
        : null;
    final bool hasArtwork = file != null && file.existsSync();
    final Color titleColor = hasArtwork
        ? Colors.white
        : (isDarkMode ? Colors.white : MacosColors.labelColor);

    final BoxDecoration decoration;
    if (hasArtwork) {
      decoration = BoxDecoration(
        image: DecorationImage(
          image: FileImage(file!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(isDarkMode ? 0.55 : 0.45),
            BlendMode.darken,
          ),
        ),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      );
    } else {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.45),
                ]
              : [
                  theme.canvasColor.withOpacity(0.7),
                  theme.canvasColor.withOpacity(0.45),
                ],
        ),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      );
    }

    return TitleBar(
      height: 56,
      centerTitle: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: decoration,
      title: Row(
        children: [
          Text(
            'Misuzu Music',
            style: theme.typography.title2.copyWith(
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _currentSectionLabel(_selectedIndex),
              style: theme.typography.caption1.copyWith(
                color: titleColor.withOpacity(0.65),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MacosTooltip(
            message: '选择音乐文件夹',
            child: MacosIconButton(
              backgroundColor: Colors.transparent,
              hoverColor: MacosColors.controlAccentColor.withOpacity(0.18),
              mouseCursor: SystemMouseCursors.click,
              onPressed: () {
                _selectMusicFolder();
              },
              icon: MacosIcon(
                CupertinoIcons.folder,
                size: 18,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
    );
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

    final overlayStrong = Colors.black.withOpacity(isDarkMode ? 0.65 : 0.45);
    final overlayMid = Colors.black.withOpacity(isDarkMode ? 0.4 : 0.25);
    final overlayWeak = Colors.black.withOpacity(isDarkMode ? 0.55 : 0.35);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(isDarkMode ? 0.25 : 0.2),
                BlendMode.darken,
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
class MusicLibraryView extends StatelessWidget {
  const MusicLibraryView({super.key});

  @override
  Widget build(BuildContext context) {
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
        } else if (state is MusicLibraryLoaded) {
          if (state.tracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MacosIcon(
                    CupertinoIcons.music_albums,
                    size: 64,
                    color: MacosColors.systemGrayColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '音乐库为空',
                    style: MacosTheme.of(context).typography.title1.copyWith(
                      color: MacosColors.systemGrayColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击工具栏的文件夹图标选择音乐文件夹',
                    style: MacosTheme.of(context).typography.body.copyWith(
                      color: MacosColors.systemGrayColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return defaultTargetPlatform == TargetPlatform.macOS
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
        } else if (state is MusicLibraryError) {
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

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MacosIcon(
                CupertinoIcons.music_albums,
                size: 64,
                color: MacosColors.systemGrayColor,
              ),
              const SizedBox(height: 16),
              Text(
                '音乐库为空',
                style: MacosTheme.of(context).typography.title1.copyWith(
                  color: MacosColors.systemGrayColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击工具栏的文件夹图标选择音乐文件夹',
                style: MacosTheme.of(context).typography.body.copyWith(
                  color: MacosColors.systemGrayColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 其他视图占位符
class PlaylistView extends StatelessWidget {
  const PlaylistView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MacosIcon(
            CupertinoIcons.music_note_list,
            size: 64,
            color: MacosColors.systemGrayColor,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放列表',
            style: MacosTheme.of(context).typography.title1.copyWith(
              color: MacosColors.systemGrayColor,
            ),
          ),
        ],
      ),
    );
  }
}

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          MacosSearchField(
            placeholder: '搜索歌曲、艺术家或专辑...',
            results: const [],
            onResultSelected: (result) {
              // TODO: 实现搜索结果选择
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Text(
                '输入关键词开始搜索',
                style: MacosTheme.of(context).typography.body.copyWith(
                  color: MacosColors.systemGrayColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设置',
            style: MacosTheme.of(context).typography.largeTitle,
          ),
          const SizedBox(height: 20),
          Text(
            '音乐播放',
            style: MacosTheme.of(context).typography.title2,
          ),
          const SizedBox(height: 12),
          MacosListTile(
            leading: const MacosIcon(CupertinoIcons.speaker_2),
            title: Text(
              '音量',
              style: MacosTheme.of(context).typography.body,
            ),
            subtitle: Text(
              '调整播放音量',
              style: MacosTheme.of(context).typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '日语歌词',
            style: MacosTheme.of(context).typography.title2,
          ),
          const SizedBox(height: 12),
          MacosListTile(
            leading: const MacosIcon(CupertinoIcons.textformat),
            title: Text(
              '假名注音',
              style: MacosTheme.of(context).typography.body,
            ),
            subtitle: Text(
              '为汉字和片假名显示平假名注音',
              style: MacosTheme.of(context).typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
