part of 'package:misuzu_music/presentation/pages/home_page.dart';

class ArtistDetailPage extends StatelessWidget {
  const ArtistDetailPage({
    super.key,
    required this.artist,
    required this.tracks,
    this.onAddToPlaylist,
  });

  final Artist artist;
  final List<Track> tracks;
  final Future<void> Function(Track track)? onAddToPlaylist;

  Duration get _totalDuration => tracks.fold<Duration>(
        Duration.zero,
        (prev, track) => prev + track.duration,
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
        title: Text('歌手：${artist.name}'),
      ),
      body: ArtistDetailView(
        artist: artist,
        tracks: tracks,
        onAddToPlaylist: onAddToPlaylist,
      ),
    );
  }
}

class ArtistDetailView extends StatelessWidget {
  const ArtistDetailView({
    super.key,
    required this.artist,
    required this.tracks,
    this.onAddToPlaylist,
  });

  final Artist artist;
  final List<Track> tracks;
  final Future<void> Function(Track track)? onAddToPlaylist;

  Duration get _totalDuration => tracks.fold<Duration>(
        Duration.zero,
        (prev, track) => prev + track.duration,
      );

  Track? get _previewTrack => tracks.isEmpty
      ? null
      : tracks.firstWhere(
          (track) => track.artworkPath != null && track.artworkPath!.isNotEmpty,
          orElse: () => tracks.first,
        );

  @override
  Widget build(BuildContext context) {
    final duration = _totalDuration;
    final totalMinutes = duration.inMinutes;
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    final preview = _previewTrack;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: _ArtistOverviewCard(
            artist: artist,
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

class _ArtistOverviewCard extends StatelessWidget {
  const _ArtistOverviewCard({
    required this.artist,
    required this.trackCount,
    required this.description,
    this.previewTrack,
  });

  final Artist artist;
  final int trackCount;
  final String description;
  final Track? previewTrack;

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
        placeholder: const Icon(CupertinoIcons.person_crop_square, size: 36),
      );
    } else if (remoteArtworkUrl != null && remoteArtworkUrl.isNotEmpty) {
      artwork = ArtworkThumbnail(
        artworkPath: null,
        remoteImageUrl: remoteArtworkUrl,
        size: 96,
        borderRadius: BorderRadius.circular(16),
        backgroundColor: macTheme.primaryColor.withOpacity(0.12),
        placeholder: const Icon(CupertinoIcons.person_crop_square, size: 36),
      );
    } else {
      final placeholderText =
          artist.name.isNotEmpty ? artist.name.characters.first : '歌';
      artwork = Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: macTheme.primaryColor.withOpacity(0.12),
        ),
        child: Center(
          child: Text(
            placeholderText,
            locale: const Locale('zh-Hans', 'zh'),
            style: macTheme.typography.title2.copyWith(
              color: baseColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
                artist.name,
                locale: const Locale('zh-Hans', 'zh'),
                style: macTheme.typography.title2.copyWith(
                  color: baseColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '共 $trackCount 首歌曲',
                locale: const Locale('zh-Hans', 'zh'),
                style: macTheme.typography.headline.copyWith(
                  color: secondaryColor,
                  fontSize: 13,
                ),
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
