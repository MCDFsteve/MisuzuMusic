import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../blocs/player/player_bloc.dart';
import 'macos_progress_bar.dart';
import 'macos_volume_control.dart';
import '../common/artwork_thumbnail.dart';

class MacOSPlayerControlBar extends StatelessWidget {
  const MacOSPlayerControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerBlocState>(
      builder: (context, state) {
        final isPlaying = state is PlayerPlaying;
        final isPaused = state is PlayerPaused;
        final loadingState = state is PlayerLoading ? state as PlayerLoading : null;
        final showLoadingIndicator = loadingState != null && loadingState.track == null;
        final canControl =
            isPlaying || isPaused || (loadingState != null && loadingState.track != null);

        String trackTitle = '暂无播放';
        String trackArtist = '选择音乐开始播放';
        Duration position = Duration.zero;
        Duration duration = Duration.zero;
        double progress = 0.0;
        double volume = 1.0;
        String? artworkPath;

        if (canControl) {
          final playingState = state as dynamic;
          trackTitle = playingState.track.title;
          trackArtist =
              '${playingState.track.artist} — ${playingState.track.album}';
          position = playingState.position;
          duration = playingState.duration;
          volume = playingState.volume;
          artworkPath = playingState.track.artworkPath;
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
              Flexible(
                flex: 0,
                child: _buildPlaybackControls(
                  context: context,
                  isPlaying: isPlaying,
                  isPaused: isPaused,
                  showLoadingIndicator: showLoadingIndicator,
                  iconColor: iconColor,
                  secondaryIconColor: secondaryIconColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _TrackInfoRow(
                      title: trackTitle,
                      subtitle: trackArtist,
                      artworkPath: artworkPath,
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
              const SizedBox(width: 16),
              Flexible(
                flex: 0,
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
  }

  Widget _buildPlaybackControls({
    required BuildContext context,
    required bool isPlaying,
    required bool isPaused,
    required bool showLoadingIndicator,
    required Color iconColor,
    required Color secondaryIconColor,
  }) {
    final canControl = isPlaying || isPaused || showLoadingIndicator;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: _MacHoverIconButton(
            tooltip: '随机播放',
            enabled: true,
            baseColor: secondaryIconColor,
            hoverColor: iconColor,
            iconBuilder: (color) => MacosIcon(
              CupertinoIcons.shuffle,
              color: color,
              size: 18,
            ),
            onPressed: () {
              // TODO: 实现随机播放切换
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 32,
          height: 32,
          child: _MacHoverIconButton(
            tooltip: '上一首',
            enabled: canControl,
            baseColor: secondaryIconColor,
            hoverColor: iconColor,
            iconBuilder: (color) => MacosIcon(
              CupertinoIcons.backward_fill,
              color: color,
              size: 20,
            ),
            onPressed: canControl
                ? () {
                    context.read<PlayerBloc>().add(const PlayerSkipPrevious());
                  }
                : null,
          ),
        ),
        const SizedBox(width: 8),
        if (showLoadingIndicator)
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
          SizedBox(
            width: 36,
            height: 36,
            child: _MacHoverIconButton(
              tooltip: isPlaying ? '暂停' : '播放',
              enabled: true,
              baseColor: iconColor.withOpacity(0.8),
              hoverColor: iconColor,
              iconBuilder: (color) => MacosIcon(
                isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                color: color,
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
        SizedBox(
          width: 32,
          height: 32,
          child: _MacHoverIconButton(
            tooltip: '下一首',
            enabled: canControl,
            baseColor: secondaryIconColor,
            hoverColor: iconColor,
            iconBuilder: (color) => MacosIcon(
              CupertinoIcons.forward_fill,
              color: color,
              size: 20,
            ),
            onPressed: canControl
                ? () {
                    context.read<PlayerBloc>().add(const PlayerSkipNext());
                  }
                : null,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 32,
          height: 32,
          child: _MacHoverIconButton(
            tooltip: '循环模式',
            enabled: true,
            baseColor: secondaryIconColor,
            hoverColor: iconColor,
            iconBuilder: (color) => MacosIcon(
              CupertinoIcons.repeat,
              color: color,
              size: 18,
            ),
            onPressed: () {
              // TODO: 实现循环模式切换
            },
          ),
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
    required this.artworkPath,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String title;
  final String subtitle;
  final String? artworkPath;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        ArtworkThumbnail(
          artworkPath: artworkPath,
          size: 34,
          borderRadius: BorderRadius.circular(5),
          backgroundColor: MacosColors.controlBackgroundColor,
          borderColor: theme.dividerColor,
          placeholder: const MacosIcon(
            CupertinoIcons.music_note,
            color: MacosColors.systemGrayColor,
            size: 14,
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

class _MacHoverIconButton extends StatefulWidget {
  const _MacHoverIconButton({
    required this.iconBuilder,
    required this.onPressed,
    required this.enabled,
    required this.baseColor,
    required this.hoverColor,
    this.tooltip,
  });

  final Widget Function(Color color) iconBuilder;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color baseColor;
  final Color hoverColor;
  final String? tooltip;

  @override
  State<_MacHoverIconButton> createState() => _MacHoverIconButtonState();
}

class _MacHoverIconButtonState extends State<_MacHoverIconButton> {
  bool _hovering = false;
  bool _pressing = false;

  void _setHovering(bool value) {
    if (!_mountedEnabled) return;
    setState(() => _hovering = value);
  }

  void _setPressing(bool value) {
    if (!_mountedEnabled) return;
    setState(() => _pressing = value);
  }

  bool get _mountedEnabled => widget.enabled && mounted;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onPressed != null;
    final Color targetColor;
    if (!enabled) {
      targetColor = widget.baseColor.withOpacity(0.45);
    } else if (_hovering) {
      targetColor = widget.hoverColor;
    } else {
      targetColor = widget.baseColor;
    }

    final scale = !enabled
        ? 1.0
        : _pressing
            ? 0.95
            : (_hovering ? 1.12 : 1.0);

    final child = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 140),
      curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
      child: widget.iconBuilder(targetColor),
    );

    final interactiveChild = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) _setHovering(true);
      },
      onExit: (_) {
        if (enabled) {
          _setHovering(false);
          _setPressing(false);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: enabled ? widget.onPressed : null,
        onTapDown: enabled ? (_) => _setPressing(true) : null,
        onTapUp: enabled ? (_) => _setPressing(false) : null,
        onTapCancel: enabled ? () => _setPressing(false) : null,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: child,
        ),
      ),
    );

    if (widget.tooltip == null || widget.tooltip!.isEmpty) {
      return interactiveChild;
    }

    return MacosTooltip(
      message: widget.tooltip!,
      child: interactiveChild,
    );
  }
}
