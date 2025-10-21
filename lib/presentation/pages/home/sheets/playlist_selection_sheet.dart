part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _PlaylistSelectionDialog extends StatefulWidget {
  const _PlaylistSelectionDialog({required this.track});

  final Track track;

  static const String createSignal = '__create_playlist__';

  @override
  State<_PlaylistSelectionDialog> createState() =>
      _PlaylistSelectionDialogState();
}

class _PlaylistSelectionDialogState extends State<_PlaylistSelectionDialog> {
  String? _selectedPlaylistId;
  String? _localError;
  final ScrollController _scrollController = ScrollController();

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
      _selectedPlaylistId = playlists.isNotEmpty ? playlists.first.id : null;
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
              label: '添加',
              onPressed: state.isProcessing || _selectedPlaylistId == null
                  ? null
                  : () async {
                      final playlistId = _selectedPlaylistId;
                      if (playlistId == null) {
                        return;
                      }
                      final added = await context
                          .read<PlaylistsCubit>()
                          .addTrackToPlaylist(playlistId, widget.track);
                      if (!added) {
                        setState(() {
                          _localError = '歌曲已在该歌单中';
                        });
                        return;
                      }
                      if (mounted) {
                        Navigator.of(context).pop(playlistId);
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
          style: macTheme.typography.body.copyWith(
            fontSize: 12,
            height: 1.4,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '新建歌单后可以将这首歌添加进去。',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: MacosScrollbar(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              shrinkWrap: true,
              primary: false,
              itemCount: playlists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final playlist = playlists[index];
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
            style: macTheme.typography.caption1.copyWith(
              color: MacosColors.systemRedColor,
            ),
          ),
        ],
      ],
    );
  }
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
