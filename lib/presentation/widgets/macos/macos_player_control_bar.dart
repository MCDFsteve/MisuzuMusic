import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../blocs/player/player_bloc.dart';
import 'macos_progress_bar.dart';
import '../common/artwork_thumbnail.dart';
import '../../../core/constants/app_constants.dart';

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
              _playModeIcon(context),
              color: color,
              size: 18,
            ),
            onPressed: () => _cyclePlayMode(context),
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
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: _MacHoverIconButton(
            tooltip: '音量',
            enabled: true,
            baseColor: secondaryIconColor,
            hoverColor: MacosTheme.of(context).brightness == Brightness.dark
                ? Colors.white
                : MacosColors.labelColor,
            iconBuilder: (color) => MacosIcon(
              CupertinoIcons.volume_up,
              color: color,
              size: 16,
            ),
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 8),
        _MacVolumeSlider(
          volume: volume,
          color: secondaryIconColor,
        ),
      ],
    );
  }
}

class _MacVolumeSlider extends StatefulWidget {
  const _MacVolumeSlider({
    required this.volume,
    required this.color,
  });

  final double volume;
  final Color color;

  @override
  State<_MacVolumeSlider> createState() => _MacVolumeSliderState();
}

IconData _playModeIcon(BuildContext context) {
  switch (_currentPlayMode(context)) {
    case PlayMode.sequence:
      return CupertinoIcons.arrow_right;
    case PlayMode.shuffle:
      return CupertinoIcons.shuffle;
    case PlayMode.repeatOne:
      return CupertinoIcons.repeat_1;
    case PlayMode.repeatAll:
      return CupertinoIcons.repeat;
  }
  return CupertinoIcons.arrow_right;
}

String _playModeTooltip(BuildContext context) {
  switch (_currentPlayMode(context)) {
    case PlayMode.sequence:
      return '顺序播放';
    case PlayMode.shuffle:
      return '随机播放';
    case PlayMode.repeatOne:
      return '单曲循环';
    case PlayMode.repeatAll:
      return '全部循环';
  }
  return '顺序播放';
}

void _cyclePlayMode(BuildContext context) {
  final bloc = context.read<PlayerBloc>();
  final current = _currentPlayMode(context);
  final next = _playModeNext(current);
  bloc.add(PlayerSetPlayMode(next));
}

PlayMode _playModeNext(PlayMode current) {
  switch (current) {
    case PlayMode.sequence:
      return PlayMode.shuffle;
    case PlayMode.shuffle:
      return PlayMode.repeatAll;
    case PlayMode.repeatAll:
      return PlayMode.repeatOne;
    case PlayMode.repeatOne:
      return PlayMode.sequence;
  }
  return PlayMode.sequence;
}

PlayMode _currentPlayMode(BuildContext context) {
  final bloc = context.read<PlayerBloc>();
  final state = bloc.state;
  if (state is PlayerPlaying) {
    return state.playMode;
  }
  if (state is PlayerPaused) {
    return state.playMode;
  }
  if (state is PlayerLoading) {
    return state.playMode;
  }
  if (state is PlayerStopped) {
    return state.playMode;
  }
  return PlayMode.sequence;
}

class _MacVolumeSliderState extends State<_MacVolumeSlider> {
  bool _hovering = false;
  late double _currentVolume;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.volume;
  }

  @override
  void didUpdateWidget(covariant _MacVolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && widget.volume != _currentVolume) {
      _currentVolume = widget.volume.clamp(0.0, 1.0);
    }
  }

  bool _dragging = false;

  void _updateVolume(BuildContext context, double value) {
    setState(() => _currentVolume = value);
    context.read<PlayerBloc>().add(PlayerSetVolume(value));
  }

  @override
  Widget build(BuildContext context) {
    final sliderColor = widget.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) {
        setState(() => _hovering = false);
        _dragging = false;
      },
      child: SizedBox(
        width: 140,
        height: 32,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final fillWidth = trackWidth * _currentVolume.clamp(0.0, 1.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: sliderColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  width: fillWidth,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: sliderColor,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _hovering || _dragging ? 1.0 : 0.0,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        inactiveTrackColor: sliderColor.withOpacity(0.2),
                        activeTrackColor: sliderColor,
                        thumbShape: _VolumeThumbShape(sliderColor),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Slider(
                          value: _currentVolume.clamp(0.0, 1.0),
                          onChangeStart: (_) => _dragging = true,
                          onChangeEnd: (_) => _dragging = false,
                          onChanged: (value) => _updateVolume(context, value),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VolumeThumbShape extends SliderComponentShape {
  const _VolumeThumbShape(this.color);

  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(12, 12);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    context.canvas.drawCircle(center, 6, paint);
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
