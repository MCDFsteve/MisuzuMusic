import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player_bloc.dart';
import '../common/artwork_thumbnail.dart';

class MaterialPlayerControlBar extends StatelessWidget {
  const MaterialPlayerControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerBlocState>(
      builder: (context, state) {
        final isPlaying = state is PlayerPlaying;
        final isPaused = state is PlayerPaused;
        final isLoading = state is PlayerLoading;

        String trackTitle = '暂无播放';
        String trackArtist = '选择音乐开始播放';
        Duration position = Duration.zero;
        Duration duration = Duration.zero;
        double progress = 0.0;
        String? artworkPath;

        if (state is PlayerPlaying || state is PlayerPaused) {
          final playingState = state as dynamic;
          trackTitle = playingState.track.title;
          trackArtist =
              '${playingState.track.artist} • ${playingState.track.album}';
          position = playingState.position;
          duration = playingState.duration;
          artworkPath = playingState.track.artworkPath;
          if (duration.inMilliseconds > 0) {
            progress = position.inMilliseconds / duration.inMilliseconds;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // 当前播放歌曲信息
              ArtworkThumbnail(
                artworkPath: artworkPath,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      trackTitle,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      trackArtist,
                      style: const TextStyle(fontSize: 12),
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
                    onPressed: (isPlaying || isPaused)
                        ? () {
                            context.read<PlayerBloc>().add(
                              const PlayerSkipPrevious(),
                            );
                          }
                        : null,
                    tooltip: '上一首',
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          context.read<PlayerBloc>().add(const PlayerPause());
                        } else if (isPaused) {
                          context.read<PlayerBloc>().add(const PlayerResume());
                        }
                      },
                      tooltip: isPlaying ? '暂停' : '播放',
                    ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: (isPlaying || isPaused)
                        ? () {
                            context.read<PlayerBloc>().add(
                              const PlayerSkipNext(),
                            );
                          }
                        : null,
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final clampedProgress = progress
                            .clamp(0.0, 1.0)
                            .toDouble();
                        final trackWidth = constraints.maxWidth;
                        final filledWidth = trackWidth.isFinite
                            ? trackWidth * clampedProgress
                            : 0.0;

                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (details) {
                            final durationInMs = duration.inMilliseconds;
                            if (durationInMs <= 0 ||
                                !trackWidth.isFinite ||
                                trackWidth == 0) {
                              return;
                            }

                            final tappedProgress =
                                (details.localPosition.dx / trackWidth)
                                    .clamp(0.0, 1.0)
                                    .toDouble();
                            final newPosition = Duration(
                              milliseconds: (durationInMs * tappedProgress)
                                  .round(),
                            );
                            context.read<PlayerBloc>().add(
                              PlayerSeekTo(newPosition),
                            );
                          },
                          child: SizedBox(
                            height: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: filledWidth,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(fontSize: 12),
                        ),
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
                  value: (state is PlayerPlaying || state is PlayerPaused)
                      ? (state as dynamic).volume
                      : 1.0,
                  onChanged: (value) {
                    context.read<PlayerBloc>().add(PlayerSetVolume(value));
                  },
                  min: 0.0,
                  max: 1.0,
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
