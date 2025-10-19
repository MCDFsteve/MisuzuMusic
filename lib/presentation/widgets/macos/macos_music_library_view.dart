import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../common/adaptive_scrollbar.dart';
import '../common/artwork_thumbnail.dart';
import '../common/track_list_tile.dart';

class MacOSMusicLibraryView extends StatelessWidget {
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final String? searchQuery;

  const MacOSMusicLibraryView({
    super.key,
    required this.tracks,
    required this.artists,
    required this.albums,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return AdaptiveScrollbar(
      isDarkMode: isDarkMode,
      builder: (controller) {
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tracks.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: MacosTheme.of(context).dividerColor,
            indent: 88,
          ),
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackListTile(
              index: index + 1,
              leading: ArtworkThumbnail(
                artworkPath: track.artworkPath,
                size: 48,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: MacosColors.controlBackgroundColor,
                borderColor: MacosTheme.of(context).dividerColor,
                placeholder: const MacosIcon(
                  CupertinoIcons.music_note,
                  color: MacosColors.systemGrayColor,
                  size: 20,
                ),
              ),
              title: track.title,
              artistAlbum: '${track.artist} • ${track.album}',
              duration: _formatDuration(track.duration),
              onTap: () {
                print('🎵 macOS点击歌曲: ${track.title}');
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
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
