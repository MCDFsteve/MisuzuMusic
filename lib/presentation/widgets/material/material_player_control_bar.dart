import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player_bloc.dart';
import '../common/artwork_thumbnail.dart';
import '../../../core/constants/mystery_library_constants.dart';
import '../../../domain/entities/music_entities.dart';

class MaterialPlayerControlBar extends StatelessWidget {
  const MaterialPlayerControlBar({
    super.key,
    this.onArtworkTap,
    this.isLyricsActive = false,
  });

  final VoidCallback? onArtworkTap;
  final bool isLyricsActive;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerBlocState>(
      builder: (context, state) {
        final isPlaying = state is PlayerPlaying;
        final isPaused = state is PlayerPaused;
        final loadingState = state is PlayerLoading
            ? state as PlayerLoading
            : null;
        final bool showPauseVisual =
            !(state is PlayerPaused ||
                state is PlayerStopped ||
                state is PlayerError ||
                state is PlayerInitial);
        final showLoadingIndicator =
            loadingState != null && loadingState.track == null;
        final canControl =
            isPlaying ||
            isPaused ||
            (loadingState != null && loadingState.track != null);

        String trackTitle = '暂无播放';
        String trackArtist = '选择音乐开始播放';
        Duration position = Duration.zero;
        Duration duration = Duration.zero;
        double progress = 0.0;
        String? artworkPath;
        String? remoteArtworkUrl;
        Track? currentTrack;

        if (canControl) {
          final playingState = state as dynamic;
          trackTitle = playingState.track.title;
          trackArtist =
              '${playingState.track.artist} • ${playingState.track.album}';
          position = playingState.position;
          duration = playingState.duration;
          final track = playingState.track as Track;
          artworkPath = track.artworkPath;
          if (track.sourceType == TrackSourceType.netease) {
            remoteArtworkUrl = track.httpHeaders?['x-netease-cover'];
          } else {
            remoteArtworkUrl = MysteryLibraryConstants.buildArtworkUrl(
              track.httpHeaders,
              thumbnail: true,
            );
          }
          currentTrack = playingState.track as Track;
          if (duration.inMilliseconds > 0) {
            progress = position.inMilliseconds / duration.inMilliseconds;
          }
        }

        final theme = Theme.of(context);
        final bool isDarkMode = theme.brightness == Brightness.dark;
        final Color frostedColor = theme.colorScheme.surface.withOpacity(
          isDarkMode ? 0.25 : 0.6,
        );

        final rowChildren = <Widget>[
          // 当前播放歌曲信息
          _LyricsArtworkButton(
            artworkPath: artworkPath,
            remoteArtworkUrl: remoteArtworkUrl,
            onTap: currentTrack != null && onArtworkTap != null
                ? onArtworkTap
                : null,
            isLyricsActive: isLyricsActive,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  trackTitle,
                  locale: Locale("zh-Hans", "zh"),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trackArtist,
                  locale: Locale("zh-Hans", "zh"),
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
              SizedBox(
                width: 32,
                height: 48,
                child: _MaterialHoverIconButton(
                  key: const ValueKey('material_prev_button'),
                  tooltip: '上一首',
                  enabled: canControl,
                  baseColor: theme.colorScheme.onSurfaceVariant,
                  hoverColor: theme.colorScheme.onSurface,
                  dimWhenDisabled: false,
                  iconBuilder: (color) =>
                      Icon(Icons.skip_previous, color: color, size: 28),
                  onPressed: canControl
                      ? () {
                          context.read<PlayerBloc>().add(
                            const PlayerSkipPrevious(),
                          );
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 2),
              if (showLoadingIndicator)
                const SizedBox(
                  width: 46,
                  height: 46,
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 46,
                  height: 46,
                  child: _MaterialHoverIconButton(
                    key: const ValueKey('material_play_button'),
                    tooltip: isPlaying ? '暂停' : '播放',
                    enabled: true,
                    baseColor: theme.colorScheme.onSurface.withOpacity(0.85),
                    hoverColor: theme.colorScheme.onSurface,
                    iconBuilder: (color) => Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          showPauseVisual ? Icons.pause : Icons.play_arrow,
                          key: ValueKey(showPauseVisual),
                          color: color,
                          size: 42,
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
                child: _MaterialHoverIconButton(
                  key: const ValueKey('material_next_button'),
                  tooltip: '下一首',
                  enabled: canControl,
                  baseColor: theme.colorScheme.onSurfaceVariant,
                  hoverColor: theme.colorScheme.onSurface,
                  dimWhenDisabled: false,
                  iconBuilder: (color) =>
                      Icon(Icons.skip_next, color: color, size: 28),
                  onPressed: canControl
                      ? () {
                          context.read<PlayerBloc>().add(
                            const PlayerSkipNext(),
                          );
                        }
                      : null,
                ),
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
                    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
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
                          milliseconds: (durationInMs * tappedProgress).round(),
                        );
                        context.read<PlayerBloc>().add(
                          PlayerSeekTo(newPosition),
                        );
                      },
                      child: SizedBox(
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: filledWidth,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
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
                      locale: Locale("zh-Hans", "zh"),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      _formatDuration(duration),
                      locale: Locale("zh-Hans", "zh"),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 音量控制
          const SizedBox(width: 16),
          Icon(
            Icons.volume_up,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                trackShape: const RectangularSliderTrackShape(),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                  disabledThumbRadius: 7,
                ),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.onSurfaceVariant
                    .withOpacity(0.2),
                thumbColor: theme.colorScheme.primary,
              ),
              child: Slider(
                value: (state is PlayerPlaying || state is PlayerPaused)
                    ? (state as dynamic).volume.clamp(0.0, 1.0)
                    : 1.0,
                onChanged: (value) {
                  context.read<PlayerBloc>().add(PlayerSetVolume(value));
                },
                min: 0.0,
                max: 1.0,
              ),
            ),
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: frostedColor,
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(children: rowChildren),
                ),
              ),
            ),
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

class _MaterialHoverIconButton extends StatefulWidget {
  const _MaterialHoverIconButton({
    super.key,
    required this.iconBuilder,
    required this.onPressed,
    required this.enabled,
    required this.baseColor,
    required this.hoverColor,
    this.dimWhenDisabled = true,
    this.tooltip,
  });

  final Widget Function(Color color) iconBuilder;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color baseColor;
  final Color hoverColor;
  final bool dimWhenDisabled;
  final String? tooltip;

  @override
  State<_MaterialHoverIconButton> createState() =>
      _MaterialHoverIconButtonState();
}

class _LyricsArtworkButton extends StatelessWidget {
  const _LyricsArtworkButton({
    required this.artworkPath,
    required this.remoteArtworkUrl,
    required this.onTap,
    required this.isLyricsActive,
  });

  final String? artworkPath;
  final String? remoteArtworkUrl;
  final VoidCallback? onTap;
  final bool isLyricsActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artwork = ArtworkThumbnail(
      artworkPath: artworkPath,
      remoteImageUrl: remoteArtworkUrl,
      size: 48,
      borderRadius: BorderRadius.circular(4),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      borderColor: theme.dividerColor,
      placeholder: Icon(
        Icons.music_note,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (onTap == null) {
      return artwork;
    }

    return Tooltip(
      message: isLyricsActive ? '收起歌词' : '查看歌词',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: artwork,
        ),
      ),
    );
  }
}

class _MaterialHoverIconButtonState extends State<_MaterialHoverIconButton> {
  bool _hovering = false;
  bool _pressing = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  void _setHovering(bool value) {
    if (!_enabled) return;
    setState(() => _hovering = value);
  }

  void _setPressing(bool value) {
    if (!_enabled) return;
    setState(() => _pressing = value);
  }

  @override
  Widget build(BuildContext context) {
    final Color targetColor;
    if (!_enabled) {
      targetColor = widget.dimWhenDisabled
          ? widget.baseColor.withOpacity(0.45)
          : widget.baseColor;
    } else if (_hovering) {
      targetColor = widget.hoverColor;
    } else {
      targetColor = widget.baseColor;
    }

    const hoverScale = 1.05;
    const pressScale = 0.95;
    final scale = !_enabled
        ? 1.0
        : _pressing
        ? pressScale
        : (_hovering ? hoverScale : 1.0);

    final icon = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 140),
      curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
      child: widget.iconBuilder(targetColor),
    );

    final interactive = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHovering(true),
      onExit: (_) {
        _setHovering(false);
        _setPressing(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _enabled ? widget.onPressed : null,
        onTapDown: _enabled ? (_) => _setPressing(true) : null,
        onTapUp: _enabled ? (_) => _setPressing(false) : null,
        onTapCancel: _enabled ? () => _setPressing(false) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          child: Center(child: icon),
        ),
      ),
    );

    if (widget.tooltip == null || widget.tooltip!.isEmpty) {
      return interactive;
    }

    return Tooltip(message: widget.tooltip!, child: interactive);
  }
}
