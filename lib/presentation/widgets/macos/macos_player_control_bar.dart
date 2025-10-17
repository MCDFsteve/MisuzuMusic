import 'dart:math' as math;
import 'dart:ui' as ui;

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
        final showPauseVisual = !(state is PlayerPaused || state is PlayerStopped || state is PlayerError || state is PlayerInitial);
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

        final frostedColor = theme.canvasColor.withOpacity(isDarkMode ? 0.35 : 0.7);

        return ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: frostedColor,
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 0.5),
                  bottom: BorderSide(color: theme.dividerColor.withOpacity(0.15), width: 0.5),
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
                  showPauseVisual: showPauseVisual,
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
                      iconColor: iconColor,
                      secondaryIconColor: secondaryIconColor,
                      volume: volume,
                    ),
                  ),
                ],
              ),
            ),
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
    required bool showPauseVisual,
    required Color iconColor,
    required Color secondaryIconColor,
  }) {
    final canControl = isPlaying || isPaused || showLoadingIndicator;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 48,
          child: _MacHoverIconButton(
            key: const ValueKey('mac_prev_button'),
            tooltip: '上一首',
            enabled: canControl,
            baseColor: secondaryIconColor,
            hoverColor: iconColor,
            iconBuilder: (color) => MacosIcon(
              CupertinoIcons.backward_fill,
              color: color,
              size: 22,
            ),
            onPressed: canControl
                ? () {
                    context.read<PlayerBloc>().add(const PlayerSkipPrevious());
                  }
                : null,
          ),
        ),
        const SizedBox(width: 2),
        if (showLoadingIndicator)
          SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: ProgressCircle(radius: 8)),
              ),
            ),
          )
        else
          SizedBox(
            width: 46,
            height: 46,
            child: _MacHoverIconButton(
              key: const ValueKey('mac_play_button'),
              tooltip: isPlaying ? '暂停' : '播放',
              enabled: true,
              baseColor: iconColor.withOpacity(0.85),
              hoverColor: iconColor,
              iconBuilder: (color) => Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: MacosIcon(
                    showPauseVisual
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    key: ValueKey(showPauseVisual),
                    color: color,
                    size: 34,
                  ),
                ),
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
        const SizedBox(width: 2),
        SizedBox(
          width: 32,
          height: 48,
          child: _MacHoverIconButton(
            key: const ValueKey('mac_next_button'),
            tooltip: '下一首',
            enabled: canControl,
            baseColor: secondaryIconColor,
            hoverColor: iconColor,
            iconBuilder: (color) => MacosIcon(
              CupertinoIcons.forward_fill,
              color: color,
              size: 22,
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
          width: 36,
          height: 36,
          child: _MacHoverIconButton(
            tooltip: _playModeTooltip(context),
            enabled: true,
            baseColor: secondaryIconColor,
            hoverColor: iconColor,
            iconBuilder: (color) => MacosIcon(
              _playModeIcon(context),
              color: color,
              size: 22,
            ),
            onPressed: () => _cyclePlayMode(context),
          ),
        ),
      ],
    );
  }

  Widget _buildAuxiliaryControls({
    required BuildContext context,
    required Color iconColor,
    required Color secondaryIconColor,
    required double volume,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          height: 36,
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
              size: 20,
            ),
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _MacVolumeSlider(
            volume: volume,
            color: iconColor,
          ),
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
    case PlayMode.repeatAll:
      return CupertinoIcons.repeat;
    case PlayMode.repeatOne:
      return CupertinoIcons.repeat_1;
    case PlayMode.shuffle:
      return CupertinoIcons.shuffle;
  }
  return CupertinoIcons.repeat;
}

String _playModeTooltip(BuildContext context) {
  switch (_currentPlayMode(context)) {
    case PlayMode.repeatAll:
      return '列表循环';
    case PlayMode.repeatOne:
      return '单曲循环';
    case PlayMode.shuffle:
      return '随机播放';
  }
  return '列表循环';
}

void _cyclePlayMode(BuildContext context) {
  final bloc = context.read<PlayerBloc>();
  final current = _currentPlayMode(context);
  final next = _playModeNext(current);
  bloc.add(PlayerSetPlayMode(next));
}

PlayMode _playModeNext(PlayMode current) {
  switch (current) {
    case PlayMode.repeatAll:
      return PlayMode.repeatOne;
    case PlayMode.repeatOne:
      return PlayMode.shuffle;
    case PlayMode.shuffle:
      return PlayMode.repeatAll;
  }
  return PlayMode.repeatAll;
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
  return PlayMode.repeatAll;
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
      onExit: (_) => setState(() {
        _hovering = false;
        _dragging = false;
      }),
      child: SizedBox(
        width: 140,
        height: 36,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            if (trackWidth <= 0) {
              return const SizedBox.shrink();
            }

            final clampedVolume = _currentVolume.clamp(0.0, 1.0);
            final fillWidth = trackWidth * clampedVolume;
            const trackHeight = 2.0;
            const knobDiameter = 10.0;
            final knobRadius = knobDiameter / 2;
            final knobCenter = fillWidth;
            final knobLeft = math.max(
              0.0,
              math.min(knobCenter - knobRadius, trackWidth - knobDiameter),
            );
            final knobTop = (constraints.maxHeight - knobDiameter) / 2;
            final isDarkMode = MacosTheme.of(context).brightness == Brightness.dark;
            final showKnob = _hovering || _dragging;

            void handlePosition(Offset localPosition) {
              final relative = (localPosition.dx / trackWidth).clamp(0.0, 1.0);
              _updateVolume(context, relative);
            }

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) => handlePosition(details.localPosition),
              onHorizontalDragStart: (details) {
                setState(() => _dragging = true);
                handlePosition(details.localPosition);
              },
              onHorizontalDragUpdate: (details) => handlePosition(details.localPosition),
              onHorizontalDragEnd: (_) => setState(() => _dragging = false),
              onHorizontalDragCancel: () => setState(() => _dragging = false),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: SizedBox(
                      height: trackHeight,
                      width: trackWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: sliderColor.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: fillWidth,
                        height: trackHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: sliderColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: knobLeft,
                    top: knobTop,
                    child: IgnorePointer(
                      ignoring: true,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: showKnob ? 1.0 : 0.0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 150),
                          scale: showKnob ? 1.0 : 0.85,
                          child: Container(
                            width: knobDiameter,
                            height: knobDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sliderColor,
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode
                                      ? Colors.black.withOpacity(0.4)
                                      : Colors.black26,
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                              border: Border.all(
                                color: isDarkMode
                                    ? MacosColors.controlBackgroundColor
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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
    super.key,
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

    const hoverScale = 1.05;
    const pressScale = 0.95;
    final scale = !enabled
        ? 1.0
        : _pressing
            ? pressScale
            : (_hovering ? hoverScale : 1.0);

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
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          child: Center(child: child),
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
