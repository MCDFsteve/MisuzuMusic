import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/mystery_library_constants.dart';
import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../../utils/track_display_utils.dart';
import '../common/artwork_thumbnail.dart';
import '../common/player_transport_button.dart';

class MobileNowPlayingBar extends StatelessWidget {
  const MobileNowPlayingBar({
    super.key,
    required this.playerState,
    this.onArtworkTap,
    this.isLyricsActive = false,
  });

  final PlayerBlocState playerState;
  final VoidCallback? onArtworkTap;
  final bool isLyricsActive;

  @override
  Widget build(BuildContext context) {
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
    final backgroundColor = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.65 : 0.9,
    );
    final borderColor = isLyricsActive
        ? theme.colorScheme.primary.withValues(alpha: 0.6)
        : Colors.transparent;
    final Color iconColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.95);
    final Color secondaryIconColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
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
                child: Column(
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
                            : theme.textTheme.bodySmall!.color!.withValues(
                                alpha: 0.7,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                height: 48,
                child: PlayerTransportButton(
                  key: const ValueKey('mobile_prev_button'),
                  tooltip: '上一首',
                  enabled: data.canSkipPrevious,
                  baseColor: secondaryIconColor,
                  hoverColor: iconColor,
                  dimWhenDisabled: false,
                  iconBuilder: (color) => Icon(
                    CupertinoIcons.backward_fill,
                    color: color,
                    size: 22,
                  ),
                  onPressed: data.canSkipPrevious
                      ? () => _skipPrevious(context)
                      : null,
                ),
              ),
              const SizedBox(width: 2),
              _PlayPauseButton(
                showPauseVisual: showPauseVisual,
                showLoadingIndicator: showLoadingIndicator,
                enabled: data.canControl,
                baseColor: iconColor.withOpacity(0.85),
                hoverColor: iconColor,
                onPressed: data.canControl
                    ? () => _togglePlayPause(context, data.isPlaying)
                    : null,
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 32,
                height: 48,
                child: PlayerTransportButton(
                  key: const ValueKey('mobile_next_button'),
                  tooltip: '下一首',
                  enabled: data.canSkipNext,
                  baseColor: secondaryIconColor,
                  hoverColor: iconColor,
                  dimWhenDisabled: false,
                  iconBuilder: (color) =>
                      Icon(CupertinoIcons.forward_fill, color: color, size: 22),
                  onPressed: data.canSkipNext ? () => _skipNext(context) : null,
                ),
              ),
            ],
          ),
          if (data.track != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: data.progress.isNaN ? 0 : data.progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.15 : 0.08,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
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

  _PlayerBarData _resolvePlayerData(PlayerBlocState state) {
    Track? track;
    Duration position = Duration.zero;
    Duration duration = Duration.zero;
    bool isPlaying = false;
    List<Track> queue = const [];
    int currentIndex = 0;

    if (state is PlayerPlaying) {
      track = state.track;
      position = state.position;
      duration = state.duration;
      isPlaying = true;
      queue = state.queue;
      currentIndex = state.currentIndex;
    } else if (state is PlayerPaused) {
      track = state.track;
      position = state.position;
      duration = state.duration;
      queue = state.queue;
      currentIndex = state.currentIndex;
    } else if (state is PlayerLoading) {
      track = state.track;
      position = state.position;
      duration = state.duration;
      queue = state.queue;
      currentIndex = state.currentIndex;
    } else if (state is PlayerStopped) {
      queue = state.queue;
      currentIndex = 0;
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

    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

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
      progress: progress.isFinite ? progress : 0,
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
    required this.progress,
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
  final double progress;
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.showPauseVisual,
    required this.showLoadingIndicator,
    required this.enabled,
    required this.baseColor,
    required this.hoverColor,
    this.onPressed,
  });

  final bool showPauseVisual;
  final bool showLoadingIndicator;
  final bool enabled;
  final Color baseColor;
  final Color hoverColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (showLoadingIndicator) {
      return SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 46,
      height: 46,
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
              size: 34,
            ),
          ),
        ),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}
