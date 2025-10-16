import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/dependency_injection.dart';
import '../../domain/usecases/music_usecases.dart';
import '../blocs/music_library/music_library_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MusicLibraryBloc(
        getAllTracks: sl<GetAllTracks>(),
        searchTracks: sl<SearchTracks>(),
        scanMusicDirectory: sl<ScanMusicDirectory>(),
        getAllArtists: sl<GetAllArtists>(),
        getAllAlbums: sl<GetAllAlbums>(),
      )..add(const LoadAllTracks()),
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
          if (defaultTargetPlatform == TargetPlatform.macOS) {
            showMacosAlertDialog(
              context: context,
              builder: (_) => MacosAlertDialog(
                appIcon: const MacosIcon(Icons.check_circle, color: Colors.green),
                title: const Text('扫描完成'),
                message: SizedBox(
                  height: 100,
                  child: SingleChildScrollView(
                    child: Text('添加了 ${state.tracksAdded} 首新歌曲'),
                  ),
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
                content: Text('✅ 扫描完成！添加了 ${state.tracksAdded} 首新歌曲'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else if (state is MusicLibraryError) {
          if (defaultTargetPlatform == TargetPlatform.macOS) {
            showMacosAlertDialog(
              context: context,
              builder: (_) => MacosAlertDialog(
                appIcon: const MacosIcon(Icons.error, color: Colors.red),
                title: const Text('发生错误'),
                message: SizedBox(
                  height: 100,
                  child: SingleChildScrollView(
                    child: Text(state.message),
                  ),
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
                content: Text('❌ ${state.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      },
      child: defaultTargetPlatform == TargetPlatform.macOS
          ? _buildMacOSLayout()
          : _buildMaterialLayout(),
    );
  }

  Widget _buildMacOSLayout() {
    return MacosWindow(
      sidebar: Sidebar(
        minWidth: 200,
        builder: (context, scrollController) {
          return SidebarItems(
            currentIndex: _selectedIndex,
            onChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: const [
              SidebarItem(
                leading: MacosIcon(Icons.library_music),
                label: Text('资料库'),
              ),
              SidebarItem(
                leading: MacosIcon(Icons.playlist_play),
                label: Text('播放列表'),
              ),
              SidebarItem(
                leading: MacosIcon(Icons.search),
                label: Text('搜索'),
              ),
              SidebarItem(
                leading: MacosIcon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          );
        },
      ),
      child: Column(
        children: [
          // macOS风格的顶部工具栏
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: MacosTheme.of(context).canvasColor,
              border: Border(
                bottom: BorderSide(
                  color: MacosTheme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Misuzu Music',
                  style: MacosTheme.of(context).typography.headline,
                ),
                const Spacer(),
                MacosIconButton(
                  icon: const MacosIcon(Icons.folder_open),
                  onPressed: _selectMusicFolder,
                ),
              ],
            ),
          ),

          // 主要内容区域
          Expanded(
            child: _buildMainContent(),
          ),

          // 底部播放控制栏
          const MacOSPlayerControlBar(),
        ],
      ),
    );
  }

  Widget _buildMaterialLayout() {
    return Scaffold(
      body: Row(
        children: [
          // 侧边栏导航
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: Text('资料库'),
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

          // 主内容区域
          Expanded(
            child: Column(
              children: [
                // 顶部应用栏
                Container(
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
                ),

                // 主要内容
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),

      // 底部播放控制栏
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
        child: const PlayerControlBar(),
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

  Future<void> _selectMusicFolder() async {
    try {
      print('🎵 开始选择音乐文件夹...');

      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择音乐文件夹',
      );

      if (result != null) {
        print('🎵 选择的文件夹: $result');

        if (mounted) {
          // 触发音乐库扫描
          print('🎵 开始扫描音乐文件夹...');
          context.read<MusicLibraryBloc>().add(ScanDirectoryEvent(result));

          // 根据平台显示提示
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
        if (defaultTargetPlatform == TargetPlatform.macOS) {
          showMacosAlertDialog(
            context: context,
            builder: (_) => MacosAlertDialog(
              appIcon: const MacosIcon(Icons.error),
              title: const Text('选择文件夹失败'),
              message: SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  child: Text(e.toString()),
                ),
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
              content: Text('选择文件夹失败: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }
}

// macOS风格的播放控制栏
class MacOSPlayerControlBar extends StatelessWidget {
  const MacOSPlayerControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        border: Border(
          top: BorderSide(
            color: MacosTheme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 当前播放歌曲信息
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: MacosTheme.of(context).dividerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const MacosIcon(Icons.music_note),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '暂无播放',
                  style: TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '选择音乐开始播放',
                  style: TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 播放控制按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MacosIconButton(
                icon: const MacosIcon(Icons.skip_previous),
                onPressed: null,
              ),
              MacosIconButton(
                icon: const MacosIcon(Icons.play_arrow, size: 28),
                onPressed: null,
              ),
              MacosIconButton(
                icon: const MacosIcon(Icons.skip_next),
                onPressed: null,
              ),
            ],
          ),

          const SizedBox(width: 16),

          // 进度条
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: MacosTheme.of(context).dividerColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: MacosTheme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('00:00', style: TextStyle(fontSize: 11)),
                    Text('00:00', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 音量控制
          const MacosIcon(Icons.volume_up, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: MacosSlider(
              value: 1.0,
              onChanged: (value) {},
              min: 0.0,
              max: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// Material风格的播放控制栏（保持原有实现）
class PlayerControlBar extends StatelessWidget {
  const PlayerControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // 当前播放歌曲信息
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.music_note),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '暂无播放',
                  style: TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '选择音乐开始播放',
                  style: TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 播放控制按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: null,
                tooltip: '上一首',
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow, size: 32),
                onPressed: null,
                tooltip: '播放',
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: null,
                tooltip: '下一首',
              ),
            ],
          ),

          // 进度条
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LinearProgressIndicator(
                  value: 0.0,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('00:00', style: TextStyle(fontSize: 12)),
                    Text('00:00', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          // 音量控制
          const SizedBox(width: 16),
          const Icon(Icons.volume_up, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Slider(
              value: 1.0,
              onChanged: null,
              min: 0.0,
              max: 1.0,
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
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在加载音乐库...'),
              ],
            ),
          );
        } else if (state is MusicLibraryLoaded) {
          if (state.tracks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '音乐库为空',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '点击上方的文件夹图标选择音乐文件夹',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 统计信息
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '${state.tracks.length} 首歌曲, ${state.artists.length} 位艺术家, ${state.albums.length} 张专辑',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    if (state.searchQuery?.isNotEmpty == true)
                      Chip(
                        label: Text('搜索: ${state.searchQuery}'),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          context.read<MusicLibraryBloc>().add(const LoadAllTracks());
                        },
                      ),
                  ],
                ),
              ),

              // 音乐列表
              Expanded(
                child: ListView.builder(
                  itemCount: state.tracks.length,
                  itemBuilder: (context, index) {
                    final track = state.tracks[index];
                    return Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.music_note),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${track.artist} • ${track.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _formatDuration(track.duration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () {
                          print('🎵 点击播放: ${track.title} - ${track.artist}');
                          // TODO: 播放音乐
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        } else if (state is MusicLibraryError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  '加载失败',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<MusicLibraryBloc>().add(const LoadAllTracks());
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_music,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                '音乐库为空',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '点击上方的文件夹图标选择音乐文件夹',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

// 播放列表视图
class PlaylistView extends StatelessWidget {
  const PlaylistView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_play,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '暂无播放列表',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// 搜索视图
class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: '搜索歌曲、艺术家或专辑...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              print('🔍 搜索内容: $value');
            },
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: Center(
              child: Text(
                '输入关键词开始搜索',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 设置视图
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设置',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: const Text('歌词注音'),
                  subtitle: const Text('为日语歌词显示平假名注音'),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      print('🎌 歌词注音设置: $value');
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('注音字体大小'),
                  subtitle: const Text('调整注音文字的大小'),
                  trailing: const Text('14px'),
                  onTap: () {
                    print('🔤 打开字体大小设置');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('关于 Misuzu Music'),
                  subtitle: const Text('版本 1.0.0'),
                  onTap: () {
                    print('ℹ️ 显示关于信息');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
