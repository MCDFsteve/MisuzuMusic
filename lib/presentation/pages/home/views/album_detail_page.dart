part of 'package:misuzu_music/presentation/pages/home_page.dart';

class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({
    super.key,
    required this.album,
    required this.tracks,
    this.onAddToPlaylist,
    this.onAddAllToPlaylist,
    this.onViewArtist,
    this.onViewAlbum,
  });

  final Album album;
  final List<Track> tracks;
  final Future<void> Function(Track track)? onAddToPlaylist;
  final Future<void> Function(List<Track> tracks)? onAddAllToPlaylist;
  final ValueChanged<Track>? onViewArtist;
  final ValueChanged<Track>? onViewAlbum;

  Duration get _totalDuration => tracks.fold<Duration>(
        Duration.zero,
        (prev, track) => prev + track.duration,
      );

  Track? get _previewTrack => tracks.isEmpty ? null : tracks.firstWhere(
        (track) => track.artworkPath != null && track.artworkPath!.isNotEmpty,
        orElse: () => tracks.first,
      );

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: '专辑：${album.title}'),
      body: ColoredBox(
        color: theme.canvasColor,
        child: AlbumDetailView(
          album: album,
          tracks: tracks,
          onAddToPlaylist: onAddToPlaylist,
          onAddAllToPlaylist: onAddAllToPlaylist,
          onViewArtist: onViewArtist,
          onViewAlbum: onViewAlbum,
        ),
      ),
    );
  }
}

class AlbumDetailView extends StatelessWidget {
  const AlbumDetailView({
    super.key,
    required this.album,
    required this.tracks,
    this.onAddToPlaylist,
    this.onAddAllToPlaylist,
    this.onViewArtist,
    this.onViewAlbum,
  });

  final Album album;
  final List<Track> tracks;
  final Future<void> Function(Track track)? onAddToPlaylist;
  final Future<void> Function(List<Track> tracks)? onAddAllToPlaylist;
  final ValueChanged<Track>? onViewArtist;
  final ValueChanged<Track>? onViewAlbum;

  Duration get _totalDuration => tracks.fold<Duration>(
        Duration.zero,
        (prev, track) => prev + track.duration,
      );

  Track? get _previewTrack => tracks.isEmpty ? null : tracks.firstWhere(
        (track) => track.artworkPath != null && track.artworkPath!.isNotEmpty,
        orElse: () => tracks.first,
      );

  @override
  Widget build(BuildContext context) {
    final duration = _totalDuration;
    final minutes = duration.inMinutes;
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final preview = _previewTrack;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: _AlbumOverviewCard(
            album: album,
            trackCount: tracks.length,
            description: '总时长：${hour} 小时 ${minute} 分钟',
            previewTrack: preview,
            onAddAllToPlaylist: tracks.isEmpty || onAddAllToPlaylist == null
                ? null
                : () => onAddAllToPlaylist!(tracks),
          ),
        ),
        Expanded(
          child: MacOSTrackListView(
            tracks: tracks,
            onAddToPlaylist: onAddToPlaylist,
            onViewArtist: onViewArtist,
            onViewAlbum: onViewAlbum,
          ),
        ),
      ],
    );
  }
}

class _AlbumOverviewCard extends StatelessWidget {
  const _AlbumOverviewCard({
    required this.album,
    required this.trackCount,
    required this.description,
    this.previewTrack,
    this.onAddAllToPlaylist,
  });

  final Album album;
  final int trackCount;
  final String description;
  final Track? previewTrack;
  final VoidCallback? onAddAllToPlaylist;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final baseColor =
        macTheme.typography.body.color ?? (isDark ? Colors.white : Colors.black);
    final secondaryColor = baseColor.withOpacity(isDark ? 0.78 : 0.7);
    final subtleColor = baseColor.withOpacity(isDark ? 0.68 : 0.6);

    final remoteArtworkUrl = previewTrack == null
        ? null
        : (MysteryLibraryConstants.buildArtworkUrl(
              previewTrack!.httpHeaders,
              thumbnail: true,
            ) ??
            previewTrack!.httpHeaders?['x-netease-cover']);

    Widget artwork;
    if (previewTrack?.artworkPath != null &&
        previewTrack!.artworkPath!.isNotEmpty) {
      artwork = ArtworkThumbnail(
        artworkPath: previewTrack!.artworkPath,
        remoteImageUrl: remoteArtworkUrl,
        size: 96,
        borderRadius: BorderRadius.circular(16),
        backgroundColor: macTheme.primaryColor.withOpacity(0.12),
        placeholder: const Icon(CupertinoIcons.music_note, size: 38),
      );
    } else if (remoteArtworkUrl != null && remoteArtworkUrl.isNotEmpty) {
      artwork = ArtworkThumbnail(
        artworkPath: null,
        remoteImageUrl: remoteArtworkUrl,
        size: 96,
        borderRadius: BorderRadius.circular(16),
        backgroundColor: macTheme.primaryColor.withOpacity(0.12),
        placeholder: const Icon(CupertinoIcons.music_note, size: 38),
      );
    } else {
      artwork = Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: macTheme.primaryColor.withOpacity(0.12),
        ),
        child: const Icon(CupertinoIcons.square_stack_3d_up, size: 36),
      );
    }

    if (onAddAllToPlaylist != null) {
      artwork = _OverviewContextMenuTarget(
        child: artwork,
        onAddAllToPlaylist: onAddAllToPlaylist!,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        artwork,
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                album.title,
                locale: const Locale('zh-Hans', 'zh'),
                style: macTheme.typography.title2.copyWith(
                  color: baseColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                album.artist,
                locale: const Locale('zh-Hans', 'zh'),
                style: macTheme.typography.headline.copyWith(
                  color: secondaryColor,
                  fontSize: 13,
                ),
              ),
              Text(
                '共 $trackCount 首歌曲',
                locale: const Locale('zh-Hans', 'zh'),
                style: macTheme.typography.caption1.copyWith(color: subtleColor),
              ),
              Text(
                description,
                locale: const Locale('zh-Hans', 'zh'),
                style: macTheme.typography.caption1.copyWith(color: subtleColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewContextMenuTarget extends StatelessWidget {
  const _OverviewContextMenuTarget({
    required this.child,
    required this.onAddAllToPlaylist,
  });

  final Widget child;
  final VoidCallback onAddAllToPlaylist;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) {
        unawaited(
          MacosContextMenu.show(
            context: context,
            globalPosition: details.globalPosition,
            actions: [
              MacosContextMenuAction(
                label: '全部添加到歌单',
                icon: CupertinoIcons.music_note_list,
                onSelected: onAddAllToPlaylist,
              ),
            ],
          ),
        );
      },
      child: HoverGlowOverlay(
        isDarkMode: isDark,
        borderRadius: BorderRadius.circular(16),
        cursor: SystemMouseCursors.click,
        glowRadius: 1.05,
        child: child,
      ),
    );
  }
}
