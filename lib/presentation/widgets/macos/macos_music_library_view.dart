import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../common/artwork_thumbnail.dart';

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
    final overlayColor = theme.canvasColor.withOpacity(isDarkMode ? 0.32 : 0.58);
    final borderColor = theme.dividerColor.withOpacity(0.35);

    return Column(
      children: [
        // 统计信息和搜索标签 (毛玻璃)
        ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: overlayColor,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  MacosIcon(
                    CupertinoIcons.music_albums_fill,
                    color: MacosColors.systemGrayColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${tracks.length} 首歌曲 • ${artists.length} 位艺术家 • ${albums.length} 张专辑',
                    style: theme.typography.caption1.copyWith(
                      color: MacosColors.systemGrayColor.withOpacity(0.95),
                    ),
                  ),
                  const Spacer(),
                  if (searchQuery?.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: MacosColors.controlAccentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MacosColors.controlAccentColor.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '搜索: $searchQuery',
                            style: theme.typography.caption1
                                .copyWith(color: MacosColors.controlAccentColor),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              // Clear search - implement in parent
                            },
                            child: MacosIcon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 14,
                              color: MacosColors.controlAccentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 音乐列表
        Expanded(
          child: ListView.separated(
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
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: MacosListTile(
                  mouseCursor: SystemMouseCursors.click,
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
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.title,
                          style: MacosTheme.of(context).typography.body
                              .copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _formatDuration(track.duration),
                        style: MacosTheme.of(context).typography.caption1
                            .copyWith(color: MacosColors.systemGrayColor),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${track.artist} • ${track.album}',
                      style: MacosTheme.of(context).typography.caption1
                          .copyWith(color: MacosColors.systemGrayColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onClick: () {
                    print('🎵 macOS点击歌曲: ${track.title}');
                    print('🎵 文件路径: ${track.filePath}');
                    print('🎵 添加队列 ${tracks.length} 首歌曲，从索引 $index 开始播放');

                    // 先检查文件是否存在
                    final file = File(track.filePath);
                    print('🎵 文件是否存在: ${file.existsSync()}');

                    if (file.existsSync()) {
                      context.read<PlayerBloc>().add(
                        PlayerSetQueue(tracks, startIndex: index),
                      );
                    } else {
                      print('❌ 文件不存在: ${track.filePath}');
                    }
                  },
                ),
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
