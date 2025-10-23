part of 'package:misuzu_music/presentation/pages/home_page.dart';

class PlaylistView extends StatelessWidget {
  const PlaylistView({
    super.key,
    required this.searchQuery,
    this.onAddToPlaylist,
  });

  final String searchQuery;
  final ValueChanged<Track>? onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = searchQuery.trim();

    return BlocBuilder<PlaybackHistoryCubit, PlaybackHistoryState>(
      builder: (context, state) {
        switch (state.status) {
          case PlaybackHistoryStatus.loading:
            return const Center(child: ProgressCircle());
          case PlaybackHistoryStatus.error:
            return _PlaylistMessage(
              icon: CupertinoIcons.exclamationmark_triangle,
              message: state.errorMessage ?? '播放列表加载失败',
            );
          case PlaybackHistoryStatus.empty:
            return _PlaylistMessage(
              icon: CupertinoIcons.music_note_list,
              message: '暂无播放列表',
            );
          case PlaybackHistoryStatus.loaded:
            return _PlaylistHistoryList(
              entries: state.entries,
              searchQuery: trimmedQuery,
              onAddToPlaylist: onAddToPlaylist,
            );
        }
      },
    );
  }
}

class _PlaylistHistoryList extends StatelessWidget {
  const _PlaylistHistoryList({
    required this.entries,
    required this.searchQuery,
    this.onAddToPlaylist,
  });

  final List<PlaybackHistoryEntry> entries;
  final String searchQuery;
  final ValueChanged<Track>? onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final dividerColor = MacosTheme.of(context).dividerColor;
    const Widget artworkPlaceholder = MacosIcon(
      CupertinoIcons.music_note,
      color: MacosColors.systemGrayColor,
      size: 20,
    );
    final artworkBackground = MacosColors.controlBackgroundColor;

    final normalizedQuery = searchQuery.trim().isEmpty
        ? null
        : searchQuery.trim().toLowerCase();
    final filteredEntries = normalizedQuery == null
        ? entries
        : entries.where((entry) {
            final track = entry.track;
            return track.title.toLowerCase().contains(normalizedQuery) ||
                track.artist.toLowerCase().contains(normalizedQuery) ||
                track.album.toLowerCase().contains(normalizedQuery);
          }).toList();

    if (filteredEntries.isEmpty) {
      return const _PlaylistMessage(
        icon: CupertinoIcons.search,
        message: '未找到匹配的播放记录',
      );
    }

    return AdaptiveScrollbar(
      isDarkMode: MacosTheme.of(context).brightness == Brightness.dark,
      builder: (controller) {
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredEntries.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor,
            indent: 88,
          ),
          itemBuilder: (context, index) {
            final entry = filteredEntries[index];
            final track = entry.track;
            final playCount = entry.playCount;
            final remoteArtworkUrl =
                MysteryLibraryConstants.buildArtworkUrl(
              track.httpHeaders,
              thumbnail: true,
            );
            return TrackListTile(
              index: index + 1,
              leading: ArtworkThumbnail(
                artworkPath: track.artworkPath,
                remoteImageUrl: remoteArtworkUrl,
                size: 48,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: artworkBackground,
                borderColor: dividerColor,
                placeholder: artworkPlaceholder,
              ),
              title: track.title,
              artistAlbum: '${track.artist} • ${track.album}',
              duration: _formatDuration(track.duration),
              meta: '${_formatPlayedAt(entry.playedAt)} | ${playCount} 次播放',
              onTap: () =>
                  _playTrack(context, track, fingerprint: entry.fingerprint),
              onSecondaryTap: onAddToPlaylist == null
                  ? null
                  : (_) => onAddToPlaylist!(track),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPlayedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inMinutes < 60) return '${difference.inMinutes} 分钟前';
    if (difference.inHours < 24) return '${difference.inHours} 小时前';

    final twoDigits = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:$twoDigits';
  }

  void _playTrack(BuildContext context, Track track, {String? fingerprint}) {
    context.read<PlayerBloc>().add(
      PlayerPlayTrack(track, fingerprint: fingerprint),
    );
  }
}
