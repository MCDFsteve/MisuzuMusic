part of 'package:misuzu_music/presentation/pages/home_page.dart';

class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({
    super.key,
    required this.album,
    required this.tracks,
    this.onAddToPlaylist,
  });

  final Album album;
  final List<Track> tracks;
  final Future<void> Function(Track track)? onAddToPlaylist;

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
    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.typography.body.color,
        title: Text('专辑：${album.title}'),
      ),
      body: AlbumDetailView(
        album: album,
        tracks: tracks,
        onAddToPlaylist: onAddToPlaylist,
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
  });

  final Album album;
  final List<Track> tracks;
  final Future<void> Function(Track track)? onAddToPlaylist;

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
          ),
        ),
        Expanded(
          child: MacOSTrackListView(
            tracks: tracks,
            onAddToPlaylist: onAddToPlaylist,
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
  });

  final Album album;
  final int trackCount;
  final String description;
  final Track? previewTrack;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? Colors.white.withOpacity(0.94)
        : Colors.black.withOpacity(0.9);
    final secondary = isDark
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.68);

    Widget artwork;
    if (previewTrack?.artworkPath != null && previewTrack!.artworkPath!.isNotEmpty) {
      artwork = ArtworkThumbnail(
        artworkPath: previewTrack!.artworkPath,
        remoteImageUrl: previewTrack!.httpHeaders?['x-netease-cover'],
        size: 96,
        borderRadius: BorderRadius.circular(16),
        backgroundColor: macTheme.primaryColor.withOpacity(0.18),
        placeholder: const Icon(CupertinoIcons.music_note, size: 38),
      );
    } else {
      artwork = Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: macTheme.primaryColor.withOpacity(0.18),
        ),
        child: const Icon(CupertinoIcons.square_stack_3d_up, size: 36),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            macTheme.primaryColor.withOpacity(isDark ? 0.32 : 0.16),
            macTheme.canvasColor.withOpacity(0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: macTheme.primaryColor.withOpacity(0.24), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.36 : 0.15),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  album.artist,
                  locale: const Locale('zh-Hans', 'zh'),
                  style: macTheme.typography.headline.copyWith(color: secondary, fontSize: 13),
                ),
                Text(
                  '共 $trackCount 首歌曲',
                  locale: const Locale('zh-Hans', 'zh'),
                  style: macTheme.typography.caption1.copyWith(color: secondary),
                ),
                Text(
                  description,
                  locale: const Locale('zh-Hans', 'zh'),
                  style: macTheme.typography.caption1.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
