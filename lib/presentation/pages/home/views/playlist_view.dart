part of 'package:misuzu_music/presentation/pages/home_page.dart';

class PlaylistView extends StatelessWidget {
  const PlaylistView({
    super.key,
    required this.searchQuery,
    this.onAddToPlaylist,
    this.onViewArtist,
    this.onViewAlbum,
  });

  final String searchQuery;
  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<Track>? onViewArtist;
  final ValueChanged<Track>? onViewAlbum;

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
              onViewArtist: onViewArtist,
              onViewAlbum: onViewAlbum,
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
    this.onViewArtist,
    this.onViewAlbum,
  });

  final List<PlaybackHistoryEntry> entries;
  final String searchQuery;
  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<Track>? onViewArtist;
  final ValueChanged<Track>? onViewAlbum;

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
            final display = deriveTrackDisplayInfo(entry.track);
            return display.title.toLowerCase().contains(normalizedQuery) ||
                display.artist.toLowerCase().contains(normalizedQuery) ||
                display.album.toLowerCase().contains(normalizedQuery);
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
        return LazyListView<PlaybackHistoryEntry>(
          controller: controller,
          items: filteredEntries,
          pageSize: 100,
          preloadOffset: 600,
          padding: const EdgeInsets.symmetric(vertical: 8),
          cacheExtent: 0,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor,
            indent: 88,
          ),
          itemBuilder: (context, entry, index) {
            final track = entry.track;
            final displayInfo = deriveTrackDisplayInfo(track);
            final normalizedTrack = applyDisplayInfo(track, displayInfo);
            final playCount = entry.playCount;
            String? remoteArtworkUrl;
            if (track.isNeteaseTrack) {
              remoteArtworkUrl = track.httpHeaders?['x-netease-cover'];
            } else {
              remoteArtworkUrl = MysteryLibraryConstants.buildArtworkUrl(
                track.httpHeaders,
                thumbnail: true,
              );
            }
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
              title: displayInfo.title,
              artistAlbum: '${displayInfo.artist} • ${displayInfo.album}',
              duration: _formatDuration(track.duration),
              meta: '${_formatPlayedAt(entry.playedAt)} | ${playCount} 次播放',
              onTap: () =>
                  _playTrack(context, track, fingerprint: entry.fingerprint),
              onSecondaryTap: (position) =>
                  _handleSecondaryTap(
                    context,
                    position,
                    track,
                    normalizedTrack,
                    displayInfo,
                  ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSecondaryTap(
    BuildContext context,
    Offset globalPosition,
    Track originalTrack,
    Track normalizedTrack,
    TrackDisplayInfo displayInfo,
  ) async {
    final l10n = context.l10n;
    final actions = <MacosContextMenuAction>[];
    final artistName = displayInfo.artist.trim();
    final albumName = displayInfo.album.trim();
    final canViewArtist =
        onViewArtist != null && artistName.isNotEmpty;
    final canViewAlbum = onViewAlbum != null && albumName.isNotEmpty;

    if (canViewArtist) {
      actions.add(
        MacosContextMenuAction(
          label: l10n.contextMenuViewArtist,
          icon: CupertinoIcons.person_crop_circle,
          onSelected: () => onViewArtist?.call(normalizedTrack),
        ),
      );
    }
    if (canViewAlbum) {
      actions.add(
        MacosContextMenuAction(
          label: l10n.contextMenuViewAlbum,
          icon: CupertinoIcons.music_albums,
          onSelected: () => onViewAlbum?.call(normalizedTrack),
        ),
      );
    }

    if (originalTrack.isNeteaseTrack) {
      actions.add(
        MacosContextMenuAction(
          label: l10n.contextMenuAddToOnlinePlaylist,
          icon: CupertinoIcons.cloud_upload,
          onSelected: () => unawaited(
            _addTrackToNeteasePlaylist(context, originalTrack),
          ),
        ),
      );
    } else if (onAddToPlaylist != null) {
      actions.add(
        MacosContextMenuAction(
          label: l10n.contextMenuAddToPlaylist,
          icon: CupertinoIcons.add_circled,
          onSelected: () => onAddToPlaylist?.call(originalTrack),
        ),
      );
    }

    if (actions.isEmpty) {
      return;
    }

    await MacosContextMenu.show(
      context: context,
      globalPosition: globalPosition,
      actions: actions,
    );
  }

  Future<void> _addTrackToNeteasePlaylist(
    BuildContext context,
    Track track,
  ) async {
    final neteaseCubit = context.read<NeteaseCubit>();

    if (neteaseCubit.state.session == null) {
      await _showInfoDialog(
        context,
        title: '未登录网络歌曲',
        message: '请先登录网络歌曲账号后再尝试添加。',
      );
      return;
    }

    var playlists = neteaseCubit.state.playlists;
    if (playlists.isEmpty) {
      await neteaseCubit.refreshPlaylists();
      playlists = neteaseCubit.state.playlists;
    }

    if (playlists.isEmpty) {
      await _showInfoDialog(
        context,
        title: '暂无可用歌单',
        message: '无法获取网络歌曲歌单，请稍后再试。',
      );
      return;
    }

    final selectedId = await _showNeteasePlaylistSelectionSheet(
      context,
      playlists: playlists,
      initialId: playlists.first.id,
    );
    if (selectedId == null) {
      return;
    }

    final error = await neteaseCubit.addTrackToPlaylist(selectedId, track);
    if (error == null) {
      await _showInfoDialog(
        context,
        title: '添加成功',
        message: '已添加到网络歌曲歌单。',
      );
    } else {
      await _showInfoDialog(
        context,
        title: '添加失败',
        message: error,
      );
    }
  }

  Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showPlaylistModalDialog<void>(
      context: context,
      builder: (_) => _PlaylistModalScaffold(
        title: title,
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            message,
            locale: const Locale('zh-Hans', 'zh'),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          _SheetActionButton.primary(
            label: '好的',
            onPressed: Navigator.of(context).pop,
          ),
        ],
        maxWidth: 360,
        contentSpacing: 14,
        actionsSpacing: 14,
      ),
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
