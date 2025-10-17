import 'dart:math' as math;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../blocs/player/player_bloc.dart';
import 'macos_progress_bar.dart';
import 'macos_volume_control.dart';

class MacOSPlayerControlBar extends StatefulWidget {
  const MacOSPlayerControlBar({super.key});

  @override
  State<MacOSPlayerControlBar> createState() => _MacOSPlayerControlBarState();
}

class _MacOSPlayerControlBarState extends State<MacOSPlayerControlBar> {
  double _leftControlsWidth = 0;
  double _rightControlsWidth = 0;

  void _updateLeftWidth(Size size) => _updateIfNeeded(size.width, isLeft: true);

  void _updateRightWidth(Size size) =>
      _updateIfNeeded(size.width, isLeft: false);

  void _updateIfNeeded(double newWidth, {required bool isLeft}) {
    final currentWidth = isLeft ? _leftControlsWidth : _rightControlsWidth;
    if ((newWidth - currentWidth).abs() < 0.5) {
      return;
    }

    setState(() {
      if (isLeft) {
        _leftControlsWidth = newWidth;
      } else {
        _rightControlsWidth = newWidth;
      }
    });
  }

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
        double volume = 1.0;

        if (state is PlayerPlaying || state is PlayerPaused) {
          final playingState = state as dynamic;
          trackTitle = playingState.track.title;
          trackArtist =
              '${playingState.track.artist} — ${playingState.track.album}';
          position = playingState.position;
          duration = playingState.duration;
          volume = playingState.volume;
          if (duration.inMilliseconds > 0) {
            progress = position.inMilliseconds / duration.inMilliseconds;
          }
        }

        final theme = MacosTheme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        final iconColor = isDarkMode ? Colors.white : MacosColors.labelColor;
        final secondaryIconColor = isDarkMode
            ? Colors.white70
            : MacosColors.secondaryLabelColor;

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final measuredLeft = _leftControlsWidth;
            final measuredRight = _rightControlsWidth;
            final baseGap = 16.0;

            double leftPaddingAdjustment = 0;
            double rightPaddingAdjustment = 0;

            if (measuredLeft > 0 && measuredRight > 0) {
              final diff = measuredRight - measuredLeft;
              if (diff > 0) {
                leftPaddingAdjustment = diff / 2;
              } else if (diff < 0) {
                rightPaddingAdjustment = -diff / 2;
              }

              if (availableWidth.isFinite) {
                final occupiedWidth = measuredLeft + measuredRight;
                final remainingWidth = math.max(
                  0.0,
                  availableWidth - occupiedWidth - (baseGap * 2),
                );
                final maxAdjustment = remainingWidth / 2;
                leftPaddingAdjustment = math.min(
                  leftPaddingAdjustment,
                  maxAdjustment,
                );
                rightPaddingAdjustment = math.min(
                  rightPaddingAdjustment,
                  maxAdjustment,
                );
              }
            }

            double leftPadding = baseGap + leftPaddingAdjustment;
            double rightPadding = baseGap + rightPaddingAdjustment;

            if (availableWidth.isFinite && measuredLeft > 0 && measuredRight > 0) {
              final leftover = math.max(
                0.0,
                availableWidth - measuredLeft - measuredRight,
              );
              final totalPadding = leftPadding + rightPadding;
              if (totalPadding > leftover && totalPadding > 0) {
                final scale = leftover / totalPadding;
                leftPadding *= scale;
                rightPadding *= scale;
              }
            }

            return Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: theme.canvasColor,
                border: Border(
                  top: BorderSide(color: theme.dividerColor, width: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _MeasureSize(
                    onChange: _updateLeftWidth,
                    child: _buildPlaybackControls(
                      context: context,
                      isPlaying: isPlaying,
                      isPaused: isPaused,
                      isLoading: isLoading,
                      iconColor: iconColor,
                      secondaryIconColor: secondaryIconColor,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: leftPadding,
                        right: rightPadding,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _TrackInfoRow(
                            title: trackTitle,
                            subtitle: trackArtist,
                            titleColor: iconColor,
                            subtitleColor: secondaryIconColor,
                          ),
                          const SizedBox(height: 4),
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
                  ),
                  _MeasureSize(
                    onChange: _updateRightWidth,
                    child: _buildAuxiliaryControls(
                      context: context,
                      secondaryIconColor: secondaryIconColor,
                      volume: volume,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaybackControls({
    required BuildContext context,
    required bool isPlaying,
    required bool isPaused,
    required bool isLoading,
    required Color iconColor,
    required Color secondaryIconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        MacosIconButton(
          icon: MacosIcon(
            CupertinoIcons.backward_fill,
            color: (isPlaying || isPaused) ? iconColor : secondaryIconColor,
            size: 20,
          ),
          onPressed: (isPlaying || isPaused)
              ? () {
                  context.read<PlayerBloc>().add(const PlayerSkipPrevious());
                }
              : null,
        ),
        const SizedBox(width: 8),
        if (isLoading)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(child: ProgressCircle(radius: 8)),
          )
        else
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: MacosIconButton(
              icon: MacosIcon(
                isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
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
        MacosIconButton(
          icon: MacosIcon(
            CupertinoIcons.forward_fill,
            color: (isPlaying || isPaused) ? iconColor : secondaryIconColor,
            size: 20,
          ),
          onPressed: (isPlaying || isPaused)
              ? () {
                  context.read<PlayerBloc>().add(const PlayerSkipNext());
                }
              : null,
        ),
        const SizedBox(width: 12),
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
    );
  }

  Widget _buildAuxiliaryControls({
    required BuildContext context,
    required Color secondaryIconColor,
    required double volume,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
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
        MacOSVolumeControl(volume: volume, iconColor: secondaryIconColor),
      ],
    );
  }
}

class _TrackInfoRow extends StatelessWidget {
  const _TrackInfoRow({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MacosColors.controlBackgroundColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: theme.dividerColor, width: 0.5),
          ),
          child: const Center(
            child: MacosIcon(
              CupertinoIcons.music_note,
              color: MacosColors.systemGrayColor,
              size: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.typography.body.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: titleColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                subtitle,
                style: theme.typography.caption1.copyWith(
                  fontSize: 10,
                  color: subtitleColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureSize(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_oldSize == newSize) {
      return;
    }
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) {
        onChange(newSize);
      }
    });
  }
}
