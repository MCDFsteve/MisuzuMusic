part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _PlaylistSelectionSheet extends StatefulWidget {
  const _PlaylistSelectionSheet({required this.track});

  final Track track;

  static const String createSignal = '__create_playlist__';

  @override
  State<_PlaylistSelectionSheet> createState() =>
      _PlaylistSelectionSheetState();
}

class _PlaylistSelectionSheetState extends State<_PlaylistSelectionSheet> {
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

    if (_selectedPlaylistId != null &&
        playlists.every((element) => element.id != _selectedPlaylistId)) {
      _selectedPlaylistId = playlists.isNotEmpty ? playlists.first.id : null;
    }

    return MacosSheet(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '添加到歌单',
                style: MacosTheme.of(
                  context,
                ).typography.title3.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('当前没有歌单，可立即创建一个新的歌单。'),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PushButton(
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(context).pop(),
                          controlSize: ControlSize.regular,
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 12),
                        PushButton(
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pop(_PlaylistSelectionSheet.createSignal),
                          controlSize: ControlSize.regular,
                          color: MacosTheme.of(context).primaryColor,
                          child: const Text('新建歌单'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 260,
                      child: MacosScrollbar(
                        controller: _scrollController,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: playlists.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            final bool active =
                                playlist.id == _selectedPlaylistId;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPlaylistId = playlist.id;
                                  _localError = null;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? MacosTheme.of(
                                          context,
                                        ).primaryColor.withOpacity(
                                          MacosTheme.of(context).brightness ==
                                                  Brightness.dark
                                              ? 0.28
                                              : 0.16,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: _PlaylistCoverPreview(
                                        coverPath: playlist.coverPath,
                                        size: 48,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playlist.name,
                                            style: MacosTheme.of(context)
                                                .typography
                                                .headline
                                                .copyWith(fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${playlist.trackIds.length} 首歌曲',
                                            style: MacosTheme.of(context)
                                                .typography
                                                .caption1
                                                .copyWith(
                                                  color:
                                                      MacosTheme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.white70
                                                      : MacosColors
                                                            .secondaryLabelColor,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    MacosRadioButton<String>(
                                      value: playlist.id,
                                      groupValue: _selectedPlaylistId,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedPlaylistId = value;
                                          _localError = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _localError!,
                        style: MacosTheme.of(context).typography.caption1
                            .copyWith(color: MacosColors.systemRedColor),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PushButton(
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(context).pop(),
                          controlSize: ControlSize.regular,
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 12),
                        PushButton(
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pop(_PlaylistSelectionSheet.createSignal),
                          controlSize: ControlSize.regular,
                          color: MacosTheme.of(context).primaryColor,
                          child: const Text('新建歌单'),
                        ),
                        const SizedBox(width: 12),
                        PushButton(
                          color: MacosTheme.of(context).primaryColor,
                          controlSize: ControlSize.regular,
                          onPressed:
                              state.isProcessing || _selectedPlaylistId == null
                              ? null
                              : () async {
                                  final playlistId = _selectedPlaylistId;
                                  if (playlistId == null) {
                                    return;
                                  }
                                  final added = await context
                                      .read<PlaylistsCubit>()
                                      .addTrackToPlaylist(
                                        playlistId,
                                        widget.track,
                                      );
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
                          child: state.isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: ProgressCircle(radius: 6),
                                )
                              : const Text('添加'),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
