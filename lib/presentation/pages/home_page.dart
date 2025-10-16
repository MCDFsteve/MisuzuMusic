import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
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
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择音乐文件夹',
      );

      if (result != null) {
        // TODO: 扫描音乐文件夹
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('正在扫描文件夹: $result'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件夹失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

// 播放控制栏
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
              color: Theme.of(context).colorScheme.surfaceVariant,
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
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
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
              // TODO: 实现搜索功能
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
                      // TODO: 实现设置保存
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
                    // TODO: 打开字体大小调节对话框
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
                    // TODO: 显示关于对话框
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