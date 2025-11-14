import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/mystery_library_constants.dart';
import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../../utils/track_display_utils.dart';
import '../common/artwork_thumbnail.dart';

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
    final backgroundColor = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.65 : 0.9,
    );
    final borderColor = isLyricsActive
        ? theme.colorScheme.primary.withValues(alpha: 0.6)
        : Colors.transparent;

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
              _ControlButton(
                icon: CupertinoIcons.backward_fill,
                onPressed: data.canSkipPrevious
                    ? () => _skipPrevious(context)
                    : null,
              ),
              const SizedBox(width: 4),
              _PlayPauseButton(
                isPlaying: data.isPlaying,
                isLoading: data.isLoading,
                enabled: data.canControl,
                onPressed: data.canControl
                    ? () => _togglePlayPause(context, data.isPlaying)
                    : null,
              ),
              const SizedBox(width: 4),
              _ControlButton(
                icon: CupertinoIcons.forward_fill,
                onPressed: data.canSkipNext ? () => _skipNext(context) : null,
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
    bool isLoading = false;
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
      isLoading = true;
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
      isLoading: isLoading,
      canControl: track != null,
      canSkipNext: queue.length > 1 && currentIndex < queue.length - 1,
      canSkipPrevious: queue.length > 1 && currentIndex > 0,
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
    required this.isLoading,
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
  final bool isLoading;
  final bool canControl;
  final bool canSkipNext;
  final bool canSkipPrevious;
  final double progress;
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.enabled,
    this.onPressed,
  });

  final bool isPlaying;
  final bool isLoading;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (isLoading && !isPlaying) {
      return SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return _ControlButton(
      icon: isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
      highlighted: true,
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlighted
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface.withValues(
            alpha: onPressed == null ? 0.35 : 0.8,
          );
    final background = highlighted
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Material(
      color: background,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }
}
