import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart' show PlayMode;
import '../../../core/constants/mystery_library_constants.dart';
import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../../utils/track_display_utils.dart';
import '../common/artwork_thumbnail.dart';
import '../common/player_transport_button.dart';
import '../../../l10n/l10n.dart';

const Duration _kMobileControlsAnimationDuration = Duration(milliseconds: 320);
const Curve _kMobileControlsAnimationCurve = Curves.easeInOutCubic;

class MobileNowPlayingBar extends StatelessWidget {
  const MobileNowPlayingBar({
    super.key,
    required this.playerState,
    this.onArtworkTap,
    this.isLyricsActive = false,
    this.onQueueTap,
    this.queueEnabled = true,
  });

  final PlayerBlocState playerState;
  final VoidCallback? onArtworkTap;
  final bool isLyricsActive;
  final VoidCallback? onQueueTap;
  final bool queueEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = _resolvePlayerData(playerState);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loadingState = playerState is PlayerLoading
        ? playerState as PlayerLoading
        : null;
    final bool showPauseVisual =
        !(playerState is PlayerPaused ||
            playerState is PlayerStopped ||
            playerState is PlayerError ||
            playerState is PlayerInitial);
    final bool showLoadingIndicator =
        loadingState != null && loadingState.track == null;
    final Color iconColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.95);
    final Color secondaryIconColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final borderRadius = BorderRadius.circular(20);
    final Color cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isLyricsActive ? cardColor : Colors.transparent;

    final bool showTrackInfo = !isLyricsActive;
    final double transportButtonSize = isLyricsActive ? 48 : 32;
    final double transportIconSize = isLyricsActive ? 26 : 22;
    final double playModeIconSize = isLyricsActive ? 26 : 20;
    final double playPauseSize = isLyricsActive ? 60 : 46;
    final double playPauseIconSize = isLyricsActive ? 40 : 34;

    Widget animatedTransportButton({
      required Key buttonKey,
      required String tooltip,
      required bool enabled,
      required Color baseColor,
      required Color hoverColor,
      required Widget Function(Color color) iconBuilder,
      required VoidCallback? onPressed,
    }) {
      return AnimatedContainer(
        duration: _kMobileControlsAnimationDuration,
        curve: _kMobileControlsAnimationCurve,
        width: transportButtonSize,
        height: transportButtonSize,
        child: PlayerTransportButton(
          key: buttonKey,
          tooltip: tooltip,
          enabled: enabled,
          baseColor: baseColor,
          hoverColor: hoverColor,
          dimWhenDisabled: false,
          iconBuilder: (color) => AnimatedSwitcher(
            duration: _kMobileControlsAnimationDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: iconBuilder(color),
          ),
          onPressed: onPressed,
        ),
      );
    }

    final Widget prevButton = animatedTransportButton(
      buttonKey: const ValueKey('mobile_prev_button'),
      tooltip: '上一首',
      enabled: data.canSkipPrevious,
      baseColor: secondaryIconColor,
      hoverColor: iconColor,
      iconBuilder: (color) => Icon(
        CupertinoIcons.backward_fill,
        key: ValueKey<String>(
          'prev_${isLyricsActive ? 'expanded' : 'compact'}',
        ),
        color: color,
        size: transportIconSize,
      ),
      onPressed: data.canSkipPrevious ? () => _skipPrevious(context) : null,
    );

    final Widget nextButton = animatedTransportButton(
      buttonKey: const ValueKey('mobile_next_button'),
      tooltip: '下一首',
      enabled: data.canSkipNext,
      baseColor: secondaryIconColor,
      hoverColor: iconColor,
      iconBuilder: (color) => Icon(
        CupertinoIcons.forward_fill,
        key: ValueKey<String>(
          'next_${isLyricsActive ? 'expanded' : 'compact'}',
        ),
        color: color,
        size: transportIconSize,
      ),
      onPressed: data.canSkipNext ? () => _skipNext(context) : null,
    );

    final Widget playModeButton = animatedTransportButton(
      buttonKey: const ValueKey('mobile_play_mode_button'),
      tooltip: _playModeTooltip(data.playMode),
      enabled: true,
      baseColor: secondaryIconColor,
      hoverColor: iconColor,
      iconBuilder: (color) => Icon(
        _playModeIcon(data.playMode),
        key: ValueKey<String>(
          'play_mode_${data.playMode.index}_${isLyricsActive ? 'expanded' : 'compact'}',
        ),
        color: color,
        size: playModeIconSize,
      ),
      onPressed: () => _cyclePlayMode(context),
    );

    final Widget queueButton = animatedTransportButton(
      buttonKey: const ValueKey('mobile_queue_button'),
      tooltip: l10n.homeQueueLabel,
      enabled: queueEnabled && onQueueTap != null,
      baseColor: queueEnabled
          ? secondaryIconColor
          : secondaryIconColor.withOpacity(0.45),
      hoverColor: iconColor,
      iconBuilder: (color) => Icon(
        CupertinoIcons.list_bullet,
        key: ValueKey<String>(
          'queue_${isLyricsActive ? 'expanded' : 'compact'}',
        ),
        color: color,
        size: playModeIconSize,
      ),
      onPressed: queueEnabled && onQueueTap != null ? onQueueTap : null,
    );

    final Widget playPauseButton = AnimatedContainer(
      duration: _kMobileControlsAnimationDuration,
      curve: _kMobileControlsAnimationCurve,
      width: playPauseSize,
      height: playPauseSize,
      child: _PlayPauseButton(
        showPauseVisual: showPauseVisual,
        showLoadingIndicator: showLoadingIndicator,
        enabled: data.canControl,
        baseColor: iconColor.withOpacity(0.85),
        hoverColor: iconColor,
        onPressed: data.canControl
            ? () => _togglePlayPause(context, data.isPlaying)
            : null,
        dimension: playPauseSize,
        iconSize: playPauseIconSize,
      ),
    );

    Widget buttonGap(double width) {
      return AnimatedContainer(
        duration: _kMobileControlsAnimationDuration,
        curve: _kMobileControlsAnimationCurve,
        width: width,
      );
    }

    final Widget controlsRowContent = isLyricsActive
        ? Row(
            key: const ValueKey('lyrics_controls_expanded'),
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              prevButton,
              playPauseButton,
              nextButton,
              playModeButton,
              queueButton,
            ],
          )
        : Row(
            key: const ValueKey('lyrics_controls_compact'),
            mainAxisSize: MainAxisSize.min,
            children: [
              prevButton,
              buttonGap(2),
              playPauseButton,
              buttonGap(2),
              nextButton,
              buttonGap(4),
              playModeButton,
              buttonGap(4),
              queueButton,
            ],
          );

    final Widget controlsRow = AnimatedSwitcher(
      duration: _kMobileControlsAnimationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: _kMobileControlsAnimationCurve,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: controlsRowContent,
    );

    final Widget trackInfoColumn = Column(
      key: const ValueKey('lyrics_track_info_column'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color == null
                ? null
                : theme.textTheme.bodySmall!.color!.withValues(alpha: 0.7),
          ),
        ),
      ],
    );

    Widget buildControlsHost(Alignment alignment, Key key) {
      return AnimatedAlign(
        key: key,
        duration: _kMobileControlsAnimationDuration,
        curve: _kMobileControlsAnimationCurve,
        alignment: alignment,
        child: controlsRow,
      );
    }

    final Widget infoAndControls = Row(
      key: const ValueKey('lyrics_info_controls_row'),
      children: [
        Expanded(child: trackInfoColumn),
        const SizedBox(width: 8),
        buildControlsHost(
          Alignment.centerRight,
          const ValueKey('lyrics_controls_host_trailing'),
        ),
      ],
    );

    final Widget controlsOnly = buildControlsHost(
      Alignment.center,
      const ValueKey('lyrics_controls_only'),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: data.track != null ? onArtworkTap : null,
                child: ArtworkThumbnail(
                  artworkPath: data.artworkPath,
                  remoteImageUrl: data.remoteArtworkUrl,
                  size: 48,
                  borderRadius: BorderRadius.circular(14),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  borderColor: theme.dividerColor.withValues(alpha: 0.4),
                  placeholder: Icon(
                    CupertinoIcons.music_note,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSize(
                  duration: _kMobileControlsAnimationDuration,
                  curve: _kMobileControlsAnimationCurve,
                  child: AnimatedSwitcher(
                    duration: _kMobileControlsAnimationDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: SizeTransition(
                          axis: Axis.horizontal,
                          axisAlignment: -1,
                          sizeFactor: curved,
                          child: child,
                        ),
                      );
                    },
                    child: showTrackInfo ? infoAndControls : controlsOnly,
                  ),
                ),
              ),
            ],
          ),
          if (data.track != null) ...[
            const SizedBox(height: 10),
            _MobileProgressObserver(
              fallbackPosition: data.position,
              fallbackDuration: data.duration,
              activeColor: iconColor,
              enabled: data.canControl,
            ),
          ],
        ],
      ),
    );
  }

  void _togglePlayPause(BuildContext context, bool isPlaying) {
    final bloc = context.read<PlayerBloc>();
    if (isPlaying) {
      bloc.add(const PlayerPause());
    } else {
      bloc.add(const PlayerResume());
    }
  }

  void _skipNext(BuildContext context) {
    context.read<PlayerBloc>().add(const PlayerSkipNext());
  }

  void _skipPrevious(BuildContext context) {
    context.read<PlayerBloc>().add(const PlayerSkipPrevious());
  }

  void _cyclePlayMode(BuildContext context) {
    final bloc = context.read<PlayerBloc>();
    final current = _currentPlayMode(bloc.state);
    final next = _playModeNext(current);
    bloc.add(PlayerSetPlayMode(next));
  }

  PlayMode _currentPlayMode(PlayerBlocState state) {
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

  PlayMode _playModeNext(PlayMode current) {
    switch (current) {
      case PlayMode.repeatAll:
        return PlayMode.repeatOne;
      case PlayMode.repeatOne:
        return PlayMode.shuffle;
      case PlayMode.shuffle:
        return PlayMode.repeatAll;
    }
  }

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.repeatAll:
        return CupertinoIcons.repeat;
      case PlayMode.repeatOne:
        return CupertinoIcons.repeat_1;
      case PlayMode.shuffle:
        return CupertinoIcons.shuffle;
    }
  }

  String _playModeTooltip(PlayMode mode) {
    switch (mode) {
      case PlayMode.repeatAll:
        return '列表循环';
      case PlayMode.repeatOne:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机播放';
    }
  }

  _PlayerBarData _resolvePlayerData(PlayerBlocState state) {
    Track? track;
    Duration position = Duration.zero;
    Duration duration = Duration.zero;
    bool isPlaying = false;
    List<Track> queue = const [];
    int currentIndex = 0;
    PlayMode playMode = PlayMode.repeatAll;

    if (state is PlayerPlaying) {
      track = state.track;
      position = state.position;
      duration = state.duration;
      isPlaying = true;
      queue = state.queue;
      currentIndex = state.currentIndex;
      playMode = state.playMode;
    } else if (state is PlayerPaused) {
      track = state.track;
      position = state.position;
      duration = state.duration;
      queue = state.queue;
      currentIndex = state.currentIndex;
      playMode = state.playMode;
    } else if (state is PlayerLoading) {
      track = state.track;
      position = state.position;
      duration = state.duration;
      queue = state.queue;
      currentIndex = state.currentIndex;
      playMode = state.playMode;
    } else if (state is PlayerStopped) {
      queue = state.queue;
      currentIndex = 0;
      playMode = state.playMode;
    }

    final displayInfo = track != null ? deriveTrackDisplayInfo(track) : null;
    String? remoteArtworkUrl;
    if (track != null) {
      if (track.sourceType == TrackSourceType.netease) {
        remoteArtworkUrl = track.httpHeaders?['x-netease-cover'];
      } else {
        remoteArtworkUrl = MysteryLibraryConstants.buildArtworkUrl(
          track.httpHeaders,
          thumbnail: true,
        );
      }
    }

    final bool canSkipNext =
        queue.length > 1 && currentIndex < queue.length - 1;
    final bool canSkipPrevious = queue.length > 1 && currentIndex > 0;

    return _PlayerBarData(
      track: track,
      title: displayInfo?.title ?? '暂无播放',
      subtitle: track == null
          ? '选择歌曲开始播放'
          : '${displayInfo?.artist ?? track.artist} — '
                '${displayInfo?.album ?? track.album}',
      artworkPath: track?.artworkPath,
      remoteArtworkUrl: remoteArtworkUrl,
      isPlaying: isPlaying,
      canControl: track != null,
      canSkipNext: canSkipNext,
      canSkipPrevious: canSkipPrevious,
      position: position,
      duration: duration,
      playMode: playMode,
    );
  }
}

class _PlayerBarData {
  const _PlayerBarData({
    required this.track,
    required this.title,
    required this.subtitle,
    required this.artworkPath,
    required this.remoteArtworkUrl,
    required this.isPlaying,
    required this.canControl,
    required this.canSkipNext,
    required this.canSkipPrevious,
    required this.position,
    required this.duration,
    required this.playMode,
  });

  final Track? track;
  final String title;
  final String subtitle;
  final String? artworkPath;
  final String? remoteArtworkUrl;
  final bool isPlaying;
  final bool canControl;
  final bool canSkipNext;
  final bool canSkipPrevious;
  final Duration position;
  final Duration duration;
  final PlayMode playMode;
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.showPauseVisual,
    required this.showLoadingIndicator,
    required this.enabled,
    required this.baseColor,
    required this.hoverColor,
    this.onPressed,
    required this.dimension,
    required this.iconSize,
  });

  final bool showPauseVisual;
  final bool showLoadingIndicator;
  final bool enabled;
  final Color baseColor;
  final Color hoverColor;
  final VoidCallback? onPressed;
  final double dimension;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (showLoadingIndicator) {
      return SizedBox.expand(
        child: Center(
          child: Container(
            width: math.max(32, dimension - 14),
            height: math.max(32, dimension - 14),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: math.max(18, dimension - 30),
                height: math.max(18, dimension - 30),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: PlayerTransportButton(
        key: const ValueKey('mobile_play_button'),
        tooltip: showPauseVisual ? '暂停' : '播放',
        enabled: enabled,
        baseColor: baseColor,
        hoverColor: hoverColor,
        iconBuilder: (color) => Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              showPauseVisual
                  ? CupertinoIcons.pause_fill
                  : CupertinoIcons.play_fill,
              key: ValueKey<bool>(showPauseVisual),
              color: color,
              size: iconSize,
            ),
          ),
        ),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _ProgressSnapshot {
  const _ProgressSnapshot({
    required this.position,
    required this.duration,
    required this.canInteract,
  });

  final Duration position;
  final Duration duration;
  final bool canInteract;
}

class _MobileProgressObserver extends StatelessWidget {
  const _MobileProgressObserver({
    required this.fallbackPosition,
    required this.fallbackDuration,
    required this.activeColor,
    required this.enabled,
  });

  final Duration fallbackPosition;
  final Duration fallbackDuration;
  final Color activeColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerBlocState, _ProgressSnapshot>(
      selector: (state) {
        if (state is PlayerPlaying) {
          return _ProgressSnapshot(
            position: state.position,
            duration: state.duration,
            canInteract: enabled && state.duration.inMilliseconds > 0,
          );
        }
        if (state is PlayerPaused) {
          return _ProgressSnapshot(
            position: state.position,
            duration: state.duration,
            canInteract: enabled && state.duration.inMilliseconds > 0,
          );
        }
        if (state is PlayerLoading && state.track != null) {
          return _ProgressSnapshot(
            position: state.position,
            duration: state.duration,
            canInteract: false,
          );
        }
        return _ProgressSnapshot(
          position: fallbackPosition,
          duration: fallbackDuration,
          canInteract: enabled && fallbackDuration.inMilliseconds > 0,
        );
      },
      builder: (context, snapshot) {
        return _MobileProgressSlider(
          position: snapshot.position,
          duration: snapshot.duration,
          activeColor: activeColor,
          enabled: snapshot.canInteract,
        );
      },
    );
  }
}

class _MobileProgressSlider extends StatefulWidget {
  const _MobileProgressSlider({
    required this.position,
    required this.duration,
    required this.activeColor,
    required this.enabled,
  });

  final Duration position;
  final Duration duration;
  final Color activeColor;
  final bool enabled;

  @override
  State<_MobileProgressSlider> createState() => _MobileProgressSliderState();
}

class _MobileProgressSliderState extends State<_MobileProgressSlider> {
  double? _dragValue;

  bool get _canSeek => widget.enabled && widget.duration.inMilliseconds > 0;

  double get _maxPosition =>
      math.max(1.0, widget.duration.inMilliseconds.toDouble());

  @override
  void didUpdateWidget(covariant _MobileProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldReset =
        widget.duration != oldWidget.duration ||
        (widget.position == Duration.zero &&
            oldWidget.position != Duration.zero) ||
        !widget.enabled;
    if (shouldReset && _dragValue != null) {
      setState(() => _dragValue = null);
    }
  }

  void _updateDragValue(double? value) {
    setState(() => _dragValue = value);
  }

  void _handleChangeStart(double value) {
    if (_canSeek) {
      _updateDragValue(value);
    }
  }

  void _handleChanged(double value) {
    if (_canSeek) {
      _updateDragValue(value);
    }
  }

  void _handleChangeEnd(double value) {
    if (!_canSeek) {
      _updateDragValue(null);
      return;
    }

    final clamped = value.clamp(0.0, _maxPosition).toDouble();
    final newPosition = Duration(milliseconds: clamped.round());
    context.read<PlayerBloc>().add(PlayerSeekTo(newPosition));
    _updateDragValue(null);
  }

  @override
  Widget build(BuildContext context) {
    final sliderValue =
        (_dragValue ?? widget.position.inMilliseconds.toDouble()).clamp(
          0.0,
          _maxPosition,
        );

    final canInteract = _canSeek;
    final bool useLegacyCupertinoSlider =
        PlatformInfo.isAndroid ||
        (PlatformInfo.isIOS && !PlatformInfo.isIOS26OrHigher());
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 4,
      activeTrackColor: widget.activeColor,
      inactiveTrackColor: widget.activeColor.withOpacity(0.25),
      thumbColor: widget.activeColor,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    );

    final sliderWidget = useLegacyCupertinoSlider
        ? _LegacyIOSProgressSlider(
            value: sliderValue,
            min: 0.0,
            max: _maxPosition,
            activeColor: widget.activeColor,
            inactiveColor: widget.activeColor.withOpacity(0.25),
            thumbColor: widget.activeColor,
            enabled: canInteract,
            onChangeStart: canInteract ? _handleChangeStart : null,
            onChanged: canInteract ? _handleChanged : null,
            onChangeEnd: canInteract ? _handleChangeEnd : null,
          )
        : SliderTheme(
            data: sliderTheme,
            child: AdaptiveSlider(
              value: sliderValue,
              min: 0.0,
              max: _maxPosition,
              activeColor: widget.activeColor,
              thumbColor: widget.activeColor,
              onChangeStart: canInteract ? _handleChangeStart : null,
              onChanged: canInteract ? _handleChanged : null,
              onChangeEnd: canInteract ? _handleChangeEnd : null,
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(height: 32, width: double.infinity, child: sliderWidget),
    );
  }
}

class _LegacyIOSProgressSlider extends StatefulWidget {
  const _LegacyIOSProgressSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.enabled,
    this.onChangeStart,
    this.onChanged,
    this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final bool enabled;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<_LegacyIOSProgressSlider> createState() =>
      _LegacyIOSProgressSliderState();
}

class _LegacyIOSProgressSliderState extends State<_LegacyIOSProgressSlider> {
  double? _dragValue;
  bool _isInteracting = false;

  bool get _isInteractive => widget.enabled && widget.onChanged != null;

  double get _range => (widget.max - widget.min);

  double get _visualValue {
    final raw = _dragValue ?? widget.value;
    if (_range == 0) {
      return widget.min;
    }
    return raw.clamp(widget.min, widget.max);
  }

  void _startInteraction(double width, double dx) {
    if (!_isInteractive || width <= 0) return;
    final startValue = _visualValue;
    if (!_isInteracting) {
      _isInteracting = true;
      widget.onChangeStart?.call(startValue);
    }
    _updateValue(width, dx);
  }

  void _updateValue(double width, double dx) {
    if (!_isInteractive || width <= 0) return;
    final newValue = _valueFromDx(dx, width);
    if (_dragValue == newValue) {
      return;
    }
    setState(() => _dragValue = newValue);
    widget.onChanged?.call(newValue);
  }

  void _endInteraction() {
    if (!_isInteractive || !_isInteracting) {
      return;
    }
    final value = _dragValue ?? widget.value;
    widget.onChangeEnd?.call(value.clamp(widget.min, widget.max));
    setState(() {
      _dragValue = null;
      _isInteracting = false;
    });
  }

  void _cancelInteraction() {
    if (!_isInteractive || !_isInteracting) {
      return;
    }
    widget.onChangeEnd?.call(
      (_dragValue ?? widget.value).clamp(widget.min, widget.max),
    );
    setState(() {
      _dragValue = null;
      _isInteracting = false;
    });
  }

  double _valueFromDx(double dx, double width) {
    if (width <= 0) return widget.min;
    final clampedDx = dx.clamp(0.0, width);
    final ratio = (clampedDx / width).clamp(0.0, 1.0);
    final value = widget.min + (_range <= 0 ? 0 : ratio * _range);
    return value.clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (context.size?.width ?? 0.0);
        final trackWidth = width <= 0 ? 1.0 : width;
        final range = _range;
        final progress = range <= 0
            ? 0.0
            : ((_visualValue - widget.min) / range).clamp(0.0, 1.0);
        final sliderBody = SizedBox.expand(
          child: CustomPaint(
            painter: _LegacyIOSSliderPainter(
              progress: progress,
              activeColor: widget.activeColor,
              inactiveColor: widget.inactiveColor,
              thumbColor: widget.thumbColor,
              isEnabled: widget.enabled,
            ),
          ),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _isInteractive
              ? (details) =>
                    _startInteraction(trackWidth, details.localPosition.dx)
              : null,
          onTapUp: _isInteractive ? (_) => _endInteraction() : null,
          onTapCancel: _isInteractive ? _cancelInteraction : null,
          onHorizontalDragStart: _isInteractive
              ? (details) =>
                    _startInteraction(trackWidth, details.localPosition.dx)
              : null,
          onHorizontalDragUpdate: _isInteractive
              ? (details) => _updateValue(trackWidth, details.localPosition.dx)
              : null,
          onHorizontalDragEnd: _isInteractive ? (_) => _endInteraction() : null,
          onHorizontalDragCancel: _isInteractive ? _cancelInteraction : null,
          child: sliderBody,
        );
      },
    );
  }
}

class _LegacyIOSSliderPainter extends CustomPainter {
  const _LegacyIOSSliderPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.isEnabled,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final bool isEnabled;

  static const double _trackHeight = 4.0;
  static const double _thumbWidth = 24.0;

  Color _dimmed(Color color, double factor) =>
      color.withOpacity((color.opacity * factor).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final centerY = size.height / 2;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, centerY - _trackHeight / 2, size.width, _trackHeight),
      const Radius.circular(_trackHeight / 2),
    );

    final backgroundPaint = Paint()
      ..color = isEnabled ? inactiveColor : _dimmed(inactiveColor, 0.5);
    canvas.drawRRect(trackRect, backgroundPaint);

    final activeWidth = size.width * progress.clamp(0.0, 1.0);
    if (activeWidth > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, activeWidth, size.height));
      final activePaint = Paint()
        ..color = isEnabled ? activeColor : _dimmed(activeColor, 0.5);
      canvas.drawRRect(trackRect, activePaint);
      canvas.restore();
    }

    final thumbWidth = math.min(_thumbWidth, math.max(size.width * 0.1, 14.0));
    final thumbHeight = thumbWidth / 2;
    final thumbCenterX = progress.clamp(0.0, 1.0) * size.width;
    final thumbRect = Rect.fromCenter(
      center: Offset(thumbCenterX, centerY),
      width: thumbWidth,
      height: thumbHeight,
    );
    final thumbRRect = RRect.fromRectAndRadius(
      thumbRect,
      Radius.circular(thumbHeight / 2),
    );
    final thumbPath = Path()..addRRect(thumbRRect);
    canvas.drawShadow(
      thumbPath,
      Colors.black.withOpacity(isEnabled ? 0.25 : 0.12),
      3,
      true,
    );

    final thumbPaint = Paint()
      ..color = isEnabled ? thumbColor : _dimmed(thumbColor, 0.55);
    canvas.drawRRect(thumbRRect, thumbPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(isEnabled ? 0.65 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    canvas.drawRRect(thumbRRect, borderPaint);
  }

  @override
  bool shouldRepaint(_LegacyIOSSliderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.thumbColor != thumbColor ||
        oldDelegate.isEnabled != isEnabled;
  }
}
