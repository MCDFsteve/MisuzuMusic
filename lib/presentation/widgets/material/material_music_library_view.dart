import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../common/adaptive_scrollbar.dart';
import '../common/artwork_thumbnail.dart';
import '../common/track_list_tile.dart';

class MaterialMusicLibraryView extends StatelessWidget {
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final String? searchQuery;

  const MaterialMusicLibraryView({
    super.key,
    required this.tracks,
    required this.artists,
    required this.albums,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 统计信息
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '${tracks.length} 首歌曲, ${artists.length} 位艺术家, ${albums.length} 张专辑',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const Spacer(),
              if (searchQuery?.isNotEmpty == true)
                Chip(
                  label: Text('搜索: $searchQuery'),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    // Clear search
                  },
                ),
            ],
          ),
        ),

        // 音乐列表
        Expanded(
          child: AdaptiveScrollbar(
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            builder: (controller) {
              return ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: tracks.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Theme.of(context).dividerColor,
                  indent: 88,
                ),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return TrackListTile(
                    index: index + 1,
                    leading: ArtworkThumbnail(
                      artworkPath: track.artworkPath,
                      size: 48,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderColor: Theme.of(context).dividerColor,
                      placeholder: Icon(
                        Icons.music_note,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: track.title,
                    artistAlbum: '${track.artist} • ${track.album}',
                    duration: _formatDuration(track.duration),
                    onTap: () {
                      print('🎵 Material点击歌曲: ${track.title}');
                      print('🎵 文件路径: ${track.filePath}');
                      print('🎵 添加队列 ${tracks.length} 首歌曲，从索引 $index 开始播放');
                      final isRemoteTrack =
                          track.sourceType == TrackSourceType.webdav ||
                              track.filePath.startsWith('webdav://');

                      if (isRemoteTrack) {
                        print('🎵 WebDAV 音轨，直接尝试远程播放');
                      }

                      if (!isRemoteTrack) {
                        final file = File(track.filePath);
                        final exists = file.existsSync();
                        print('🎵 文件是否存在: $exists');

                        if (!exists) {
                          print('❌ 文件不存在: ${track.filePath}');
                          return;
                        }
                      }

                      context.read<PlayerBloc>().add(
                        PlayerSetQueue(tracks, startIndex: index),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
