import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/jellyfin_library_constants.dart';
import '../../../core/constants/mystery_library_constants.dart';
import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../../blocs/music_library/music_library_bloc.dart';
import '../common/adaptive_scrollbar.dart';
import '../common/artwork_thumbnail.dart';
import '../common/track_list_tile.dart';
import '../common/lazy_list_view.dart';
import '../../utils/track_display_utils.dart';

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
                locale: Locale("zh-Hans", "zh"),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const Spacer(),
              if (searchQuery?.isNotEmpty == true)
                Chip(
                  label: Text(
                    '搜索: $searchQuery',
                    locale: Locale("zh-Hans", "zh"),
                  ),
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
              return LazyListView<Track>(
                controller: controller,
                items: tracks,
                pageSize: 120,
                preloadOffset: 800,
                padding: const EdgeInsets.symmetric(vertical: 8),
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Theme.of(context).dividerColor,
                  indent: 88,
                ),
                itemBuilder: (context, track, index) {
                  final displayInfo = deriveTrackDisplayInfo(track);
                  final normalizedTrack = applyDisplayInfo(track, displayInfo);
                  String? remoteArtworkUrl;
                  if (track.sourceType == TrackSourceType.netease) {
                    remoteArtworkUrl = track.httpHeaders?['x-netease-cover'];
                  } else if (track.isJellyfinTrack) {
                    remoteArtworkUrl =
                        JellyfinLibraryConstants.buildArtworkUrl(
                          track.httpHeaders,
                        );
                  } else {
                    remoteArtworkUrl =
                        MysteryLibraryConstants.buildArtworkUrl(
                          track.httpHeaders,
                          thumbnail: true,
                        );
                  }
                  return TrackListTile(
                    index: index + 1,
                    leading: ArtworkThumbnail(
                      artworkPath: track.artworkPath,
                      remoteImageUrl: remoteArtworkUrl,
                      size: 48,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderColor: Theme.of(context).dividerColor,
                      placeholder: Icon(
                        Icons.music_note,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: displayInfo.title,
                    artistAlbum: '${displayInfo.artist} • ${displayInfo.album}',
                    duration: track.sourceType == TrackSourceType.webdav
                        ? ''
                        : _formatDuration(track.duration),
                    onTap: () {
                      print('🎵 Material点击歌曲: ${displayInfo.title}');
                      print('🎵 文件路径: ${track.filePath}');
                      print('🎵 添加队列 ${tracks.length} 首歌曲，从索引 $index 开始播放');
                      final isRemoteTrack =
                          track.sourceType == TrackSourceType.webdav ||
                          track.filePath.startsWith('webdav://') ||
                          track.sourceType == TrackSourceType.jellyfin ||
                          track.filePath.startsWith('jellyfin://') ||
                          track.sourceType == TrackSourceType.mystery ||
                          track.filePath.startsWith('mystery://') ||
                          track.sourceType == TrackSourceType.netease ||
                          track.filePath.startsWith('netease://');

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

                      List<Track> playbackQueue = tracks;
                      int queueIndex = index;

                      if (searchQuery?.isNotEmpty == true) {
                        final blocState = context
                            .read<MusicLibraryBloc>()
                            .state;
                        if (blocState is MusicLibraryLoaded &&
                            blocState.allTracks.isNotEmpty) {
                          final fullIndex = blocState.allTracks.indexWhere(
                            (element) => element.id == track.id,
                          );
                          if (fullIndex != -1) {
                            playbackQueue = blocState.allTracks;
                            queueIndex = fullIndex;
                          }
                        }
                      }

                      final normalizedQueue = playbackQueue
                          .map(
                            (t) => t.id == track.id
                                ? normalizedTrack
                                : applyDisplayInfo(
                                    t,
                                    deriveTrackDisplayInfo(t),
                                  ),
                          )
                          .toList();

                      context.read<PlayerBloc>().add(
                        PlayerSetQueue(normalizedQueue, startIndex: queueIndex),
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
