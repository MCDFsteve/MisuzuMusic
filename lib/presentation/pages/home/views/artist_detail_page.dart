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
    final duration = _totalDuration;
    final totalMinutes = duration.inMinutes;
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    return Scaffold(
      backgroundColor: MacosTheme.of(context).canvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: MacosTheme.of(context).typography.body.color,
        title: Text('歌手：${artist.name}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: _ArtistOverviewCard(
              artist: artist,
              trackCount: tracks.length,
              description: '总时长：${hour} 小时 ${minute} 分钟',
            ),
          ),
          Expanded(
            child: MacOSTrackListView(
              tracks: tracks,
              onAddToPlaylist: onAddToPlaylist,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistOverviewCard extends StatelessWidget {
  const _ArtistOverviewCard({
    required this.artist,
    required this.trackCount,
    required this.description,
  });

  final Artist artist;
  final int trackCount;
  final String description;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? Colors.white.withOpacity(0.9)
        : Colors.black.withOpacity(0.88);
    final secondary = isDark
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            macTheme.primaryColor.withOpacity(isDark ? 0.32 : 0.18),
            macTheme.canvasColor.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: macTheme.primaryColor.withOpacity(0.25), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: macTheme.primaryColor.withOpacity(0.22),
            child: Text(
              artist.name.isNotEmpty ? artist.name.characters.first : '歌',
              style: macTheme.typography.title2.copyWith(color: primaryColor),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist.name,
                  locale: const Locale('zh-Hans', 'zh'),
                  style: macTheme.typography.title2.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '共 $trackCount 首歌曲',
                  locale: const Locale('zh-Hans', 'zh'),
                  style: macTheme.typography.headline.copyWith(color: secondary, fontSize: 13),
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
