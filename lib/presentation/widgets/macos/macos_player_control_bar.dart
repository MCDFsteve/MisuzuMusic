import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../blocs/player/player_bloc.dart';
import 'macos_volume_control.dart';
import 'macos_progress_bar.dart';

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
          height: 80, // 减少高度以适应内容
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // 减少垂直padding
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
                        width: 32, // 减小按钮尺寸
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: ProgressCircle(
                            radius: 8,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 32, // 减小按钮尺寸
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: MacosIconButton(
                          icon: MacosIcon(
                            isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                            color: iconColor,
                            size: 16,
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
                  mainAxisSize: MainAxisSize.min, // 添加这个属性
                  children: [
                    // 歌曲信息行
                    Row(
                      children: [
                        // 专辑封面
                        Container(
                          width: 40, // 减小封面尺寸
                          height: 40,
                          decoration: BoxDecoration(
                            color: MacosColors.controlBackgroundColor,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: MacosTheme.of(context).dividerColor,
                              width: 0.5,
                            ),
                          ),
                          child: Center(
                            child: MacosIcon(
                              CupertinoIcons.music_note,
                              color: MacosColors.systemGrayColor,
                              size: 16,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // 歌曲标题和艺术家
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min, // 添加这个属性
                            children: [
                              Text(
                                trackTitle,
                                style: MacosTheme.of(context).typography.body.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12, // 减小字体
                                  color: iconColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                trackArtist,
                                style: MacosTheme.of(context).typography.caption1.copyWith(
                                  fontSize: 10, // 减小字体
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

                    const SizedBox(height: 6), // 减小间距

                    // 进度条区域 - Apple Music风格
                    MacOSProgressBar(
                      progress: progress,
                      position: position,
                      duration: duration,
                      primaryColor: iconColor,
                      secondaryColor: secondaryIconColor,
                    ),
                  ],
                ),
              ),

              // 右侧功能区（固定宽度）
              SizedBox(
                width: 350, // 增加宽度以容纳所有控件
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

                    const SizedBox(width: 8),

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

                    const SizedBox(width: 8),

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

                    const SizedBox(width: 8),

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

                    const SizedBox(width: 12),

                    // 音量控制 - 模块化组件
                    MacOSVolumeControl(
                      volume: (state is PlayerPlaying || state is PlayerPaused)
                          ? (state as dynamic).volume
                          : 1.0,
                      iconColor: secondaryIconColor,
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