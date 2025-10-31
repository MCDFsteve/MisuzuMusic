part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _PlaylistSelectionDialog extends StatefulWidget {
  _PlaylistSelectionDialog({required List<Track> initialTracks})
      : assert(initialTracks.isNotEmpty, '至少需要一首歌曲'),
        tracks = List<Track>.unmodifiable(initialTracks);

  final List<Track> tracks;

  static const String createSignal = '__create_playlist__';

  bool get isBulk => tracks.length > 1;

  @override
  State<_PlaylistSelectionDialog> createState() =>
      _PlaylistSelectionDialogState();
}

class _PlaylistSelectionDialogState extends State<_PlaylistSelectionDialog> {
  String? _selectedPlaylistId;
  String? _localError;
  final ScrollController _scrollController = ScrollController();

  String? _latestCreatedPlaylistId(List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return null;
    }
    var latest = playlists.first;
    for (final playlist in playlists.skip(1)) {
      if (playlist.createdAt.isAfter(latest.createdAt)) {
        latest = playlist;
      }
    }
    return latest.id;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PlaylistsCubit>();
    final state = cubit.state;
    final playlists = state.playlists;
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;

    if (_selectedPlaylistId != null &&
        playlists.every((element) => element.id != _selectedPlaylistId)) {
      _selectedPlaylistId = _latestCreatedPlaylistId(playlists);
    }

    if (_selectedPlaylistId == null && playlists.isNotEmpty) {
      _selectedPlaylistId = _latestCreatedPlaylistId(playlists);
    }

    final body = playlists.isEmpty
        ? _buildEmptyStateBody(context)
        : _buildPlaylistBody(context, playlists, isDark);

    final actions = playlists.isEmpty
        ? <Widget>[
            _SheetActionButton.secondary(
              label: '取消',
              onPressed: state.isProcessing
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
            _SheetActionButton.primary(
              label: '新建歌单',
              onPressed: state.isProcessing
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(_PlaylistSelectionDialog.createSignal),
            ),
          ]
        : <Widget>[
            _SheetActionButton.secondary(
              label: '取消',
              onPressed: state.isProcessing
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
            _SheetActionButton.secondary(
              label: '新建歌单',
              onPressed: state.isProcessing
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(_PlaylistSelectionDialog.createSignal),
            ),
            _SheetActionButton.primary(
              label: widget.isBulk ? '全部添加' : '添加',
              onPressed: state.isProcessing || _selectedPlaylistId == null
                  ? null
                  : () async {
                      final playlistId = _selectedPlaylistId;
                      if (playlistId == null) {
                        return;
                      }
                      setState(() {
                        _localError = null;
                      });
                      final playlistsCubit = context.read<PlaylistsCubit>();
                      if (!widget.isBulk) {
                        final added = await playlistsCubit.addTrackToPlaylist(
                          playlistId,
                          widget.tracks.first,
                        );
                        if (!added) {
                          if (mounted) {
                            setState(() {
                              _localError = '歌曲已在该歌单中';
                            });
                          }
                          return;
                        }
                        if (mounted) {
                          Navigator.of(context).pop(
                            _PlaylistSelectionResult(
                              playlistId: playlistId,
                              addedCount: 1,
                              skippedCount: 0,
                            ),
                          );
                        }
                        return;
                      }

                      final bulkResult = await playlistsCubit.addTracksToPlaylist(
                        playlistId,
                        widget.tracks,
                      );
                      if (bulkResult.hasError) {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _localError =
                              bulkResult.errorMessage ?? '添加失败，请稍后重试';
                        });
                        return;
                      }
                      if (bulkResult.addedCount == 0) {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _localError = '所选歌曲已在该歌单中';
                        });
                        return;
                      }
                      if (mounted) {
                        Navigator.of(context).pop(
                          _PlaylistSelectionResult(
                            playlistId: playlistId,
                            addedCount: bulkResult.addedCount,
                            skippedCount: bulkResult.skippedCount,
                          ),
                        );
                      }
                    },
              isBusy: state.isProcessing,
            ),
          ];

    return _PlaylistModalScaffold(
      title: '添加到歌单',
      body: body,
      actions: actions,
      maxWidth: 340,
      contentSpacing: playlists.isEmpty ? 12 : 10,
      actionsSpacing: playlists.isEmpty ? 20 : 14,
    );
  }

  Widget _buildEmptyStateBody(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? Colors.white.withOpacity(0.86)
        : Colors.black.withOpacity(0.82);
    final secondaryColor = isDark
        ? Colors.white.withOpacity(0.62)
        : Colors.black.withOpacity(0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '当前没有歌单，可立即创建一个新的歌单。',
          locale: Locale("zh-Hans", "zh"),
          style: macTheme.typography.body.copyWith(
            fontSize: 12,
            height: 1.4,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.isBulk
              ? '新建歌单后可以将这些歌曲添加进去。'
              : '新建歌单后可以将这首歌添加进去。',
          locale: Locale("zh-Hans", "zh"),
          style: macTheme.typography.caption1.copyWith(
            fontSize: 11,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistBody(
    BuildContext context,
    List<Playlist> playlists,
    bool isDark,
  ) {
    final macTheme = MacosTheme.of(context);
    final trackCount = widget.tracks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.isBulk
              ? '将添加 $trackCount 首歌曲到所选歌单。'
              : '将添加 1 首歌曲到所选歌单。',
          locale: Locale("zh-Hans", "zh"),
          style: macTheme.typography.caption1.copyWith(
            fontSize: 11,
            color: MacosColors.secondaryLabelColor,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: MacosScrollbar(
            controller: _scrollController,
            child: LazyListView<Playlist>(
              controller: _scrollController,
              shrinkWrap: true,
              primary: false,
              items: playlists,
              pageSize: 40,
              preloadOffset: 120,
              cacheExtent: 0,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, playlist, index) {
                return _PlaylistEntryTile(
                  playlist: playlist,
                  isDark: isDark,
                  selectedId: _selectedPlaylistId,
                  onSelected: () {
                    setState(() {
                      _selectedPlaylistId = playlist.id;
                      _localError = null;
                    });
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedPlaylistId = value;
                      _localError = null;
                    });
                  },
                );
              },
            ),
          ),
        ),
        if (_localError != null) ...[
          const SizedBox(height: 8),
          Text(
            _localError!,
            locale: Locale("zh-Hans", "zh"),
            style: macTheme.typography.caption1.copyWith(
              color: MacosColors.systemRedColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaylistSelectionResult {
  const _PlaylistSelectionResult({
    required this.playlistId,
    required this.addedCount,
    required this.skippedCount,
  });

  final String playlistId;
  final int addedCount;
  final int skippedCount;
}

class _PlaylistEntryTile extends StatelessWidget {
  const _PlaylistEntryTile({
    required this.playlist,
    required this.isDark,
    required this.selectedId,
    required this.onSelected,
    required this.onChanged,
  });

  final Playlist playlist;
  final bool isDark;
  final String? selectedId;
  final VoidCallback onSelected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final bool active = playlist.id == selectedId;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? macTheme.primaryColor.withOpacity(isDark ? 0.24 : 0.16)
              : (isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? macTheme.primaryColor.withOpacity(isDark ? 0.48 : 0.32)
                : (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.06)),
            width: 0.8,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: macTheme.primaryColor.withOpacity(
                      isDark ? 0.2 : 0.16,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _PlaylistCoverPreview(
                coverPath: playlist.coverPath,
                size: 40,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    locale: Locale("zh-Hans", "zh"),
                    style: macTheme.typography.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white
                          : Colors.black.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.trackIds.length} 首歌曲',
                    locale: Locale("zh-Hans", "zh"),
                    style: macTheme.typography.caption1.copyWith(
                      fontSize: 10,
                      color: isDark
                          ? Colors.white70
                          : MacosColors.secondaryLabelColor,
                    ),
                  ),
                ],
              ),
            ),
            MacosRadioButton<String>(
              value: playlist.id,
              groupValue: selectedId,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
