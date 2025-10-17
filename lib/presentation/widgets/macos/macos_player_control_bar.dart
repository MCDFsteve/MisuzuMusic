import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../blocs/player/player_bloc.dart';

class MacOSPlayerControlBar extends StatelessWidget {
  const MacOSPlayerControlBar({super.key});

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

        if (state is PlayerPlaying || state is PlayerPaused) {
          final playingState = state as dynamic;
          trackTitle = playingState.track.title;
          trackArtist = '${playingState.track.artist} — ${playingState.track.album}';
          position = playingState.position;
          duration = playingState.duration;
          if (duration.inMilliseconds > 0) {
            progress = position.inMilliseconds / duration.inMilliseconds;
          }
        }

        final isDarkMode = MacosTheme.of(context).brightness == Brightness.dark;
        final iconColor = isDarkMode ? Colors.white : MacosColors.labelColor;
        final secondaryIconColor = isDarkMode ? Colors.white70 : MacosColors.secondaryLabelColor;

        return Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧 - 播放控制区（固定宽度）
              SizedBox(
                width: 200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 随机播放
                    MacosIconButton(
                      icon: MacosIcon(
                        CupertinoIcons.shuffle,
                        color: secondaryIconColor,
                        size: 18,
                      ),
                      onPressed: () {
                        // TODO: 实现随机播放切换
                      },
                    ),

                    const SizedBox(width: 12),

                    // 上一首
                    MacosIconButton(
                      icon: MacosIcon(
                        CupertinoIcons.backward_fill,
                        color: (isPlaying || isPaused) ? iconColor : secondaryIconColor,
                        size: 20,
                      ),
                      onPressed: (isPlaying || isPaused) ? () {
                        context.read<PlayerBloc>().add(const PlayerSkipPrevious());
                      } : null,
                    ),

                    const SizedBox(width: 8),

                    // 播放/暂停按钮
                    if (isLoading)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: ProgressCircle(
                            radius: 10,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: MacosIconButton(
                          icon: MacosIcon(
                            isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                            color: iconColor,
                            size: 18,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              context.read<PlayerBloc>().add(const PlayerPause());
                            } else if (isPaused) {
                              context.read<PlayerBloc>().add(const PlayerResume());
                            }
                          },
                        ),
                      ),

                    const SizedBox(width: 8),

                    // 下一首
                    MacosIconButton(
                      icon: MacosIcon(
                        CupertinoIcons.forward_fill,
                        color: (isPlaying || isPaused) ? iconColor : secondaryIconColor,
                        size: 20,
                      ),
                      onPressed: (isPlaying || isPaused) ? () {
                        context.read<PlayerBloc>().add(const PlayerSkipNext());
                      } : null,
                    ),

                    const SizedBox(width: 12),

                    // 循环播放
                    MacosIconButton(
                      icon: MacosIcon(
                        CupertinoIcons.repeat,
                        color: secondaryIconColor,
                        size: 18,
                      ),
                      onPressed: () {
                        // TODO: 实现循环模式切换
                      },
                    ),
                  ],
                ),
              ),

              // 中间区域 - 歌曲信息和进度条（扩展占用剩余空间）
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 歌曲信息行
                    Row(
                      children: [
                        // 专辑封面
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: MacosColors.controlBackgroundColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: MacosTheme.of(context).dividerColor,
                              width: 0.5,
                            ),
                          ),
                          child: Center(
                            child: MacosIcon(
                              CupertinoIcons.music_note,
                              color: MacosColors.systemGrayColor,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // 歌曲标题和艺术家
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                trackTitle,
                                style: MacosTheme.of(context).typography.body.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: iconColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                trackArtist,
                                style: MacosTheme.of(context).typography.caption1.copyWith(
                                  fontSize: 11,
                                  color: secondaryIconColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 进度条区域
                    Row(
                      children: [
                        // 当前时间
                        SizedBox(
                          width: 40,
                          child: Text(
                            _formatDuration(position),
                            style: MacosTheme.of(context).typography.caption2.copyWith(
                              fontSize: 10,
                              color: secondaryIconColor,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // 进度条
                        Expanded(
                          child: MacosSlider(
                            value: progress.clamp(0.0, 1.0),
                            onChanged: (value) {
                              if (duration.inMilliseconds > 0) {
                                final newPosition = Duration(
                                  milliseconds: (duration.inMilliseconds * value).round(),
                                );
                                context.read<PlayerBloc>().add(PlayerSeekTo(newPosition));
                              }
                            },
                            min: 0.0,
                            max: 1.0,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // 总时长
                        SizedBox(
                          width: 40,
                          child: Text(
                            _formatDuration(duration),
                            style: MacosTheme.of(context).typography.caption2.copyWith(
                              fontSize: 10,
                              color: secondaryIconColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 右侧功能区（固定宽度）
              SizedBox(
                width: 200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 更多选项
                    MacosIconButton(
                      icon: MacosIcon(
                        CupertinoIcons.ellipsis,
                        color: secondaryIconColor,
                        size: 16,
                      ),
                      onPressed: () {
                        // TODO: 显示更多选项菜单
                      },
                    ),

                    const SizedBox(width: 12),

                    // 歌词/评论
                    MacosIconButton(
                      icon: MacosIcon(
                        CupertinoIcons.quote_bubble,
                        color: secondaryIconColor,
                        size: 16,
                      ),
                      onPressed: () {
                        // TODO: 显示歌词面板
                      },
                    ),

                    const SizedBox(width: 12),

                    // 播放列表
                    MacosIconButton(
                      icon: MacosIcon(
                        CupertinoIcons.list_bullet,
                        color: secondaryIconColor,
                        size: 16,
                      ),
                      onPressed: () {
                        // TODO: 显示播放列表
                      },
                    ),

                    const SizedBox(width: 12),

                    // 输出设备
                    MacosIconButton(
                      icon: MacosIcon(
                        CupertinoIcons.hifispeaker,
                        color: secondaryIconColor,
                        size: 16,
                      ),
                      onPressed: () {
                        // TODO: 选择输出设备
                      },
                    ),

                    const SizedBox(width: 8),

                    // 音量控制
                    MacosIcon(
                      CupertinoIcons.speaker_1_fill,
                      size: 14,
                      color: secondaryIconColor,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 60, maxWidth: 60),
                      child: MacosSlider(
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