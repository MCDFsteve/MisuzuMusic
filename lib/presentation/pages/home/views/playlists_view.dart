part of 'package:misuzu_music/presentation/pages/home_page.dart';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key, this.onAddToPlaylist});

  final ValueChanged<Track>? onAddToPlaylist;

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  bool _showList = false;
  String? _activePlaylistId;

  Future<void> _editPlaylist(Playlist playlist) async {
    final result = await showPlaylistEditDialog(context, playlist: playlist);
    if (!mounted) {
      return;
    }
    if (result == _PlaylistCreationDialog.deleteSignal &&
        _activePlaylistId == playlist.id) {
      _returnOverview();
    }
  }

  void openPlaylistById(String id) {
    if (!mounted) return;
    setState(() {
      _showList = true;
      _activePlaylistId = id;
    });
    context.read<PlaylistsCubit>().ensurePlaylistTracks(id, force: true);
  }

  void _openPlaylist(Playlist playlist) {
    openPlaylistById(playlist.id);
  }

  void _returnOverview() {
    setState(() {
      _showList = false;
      _activePlaylistId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaylistsCubit, PlaylistsState>(
      builder: (context, state) {
        final playlists = state.playlists;

        if (_activePlaylistId != null &&
            playlists.every((playlist) => playlist.id != _activePlaylistId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _returnOverview();
          });
        }

        if (playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                MacosIcon(
                  CupertinoIcons.square_stack_3d_up,
                  size: 72,
                  color: MacosColors.systemGrayColor,
                ),
                SizedBox(height: 12),
                Text('暂无歌单'),
              ],
            ),
          );
        }

        if (!_showList) {
          return CollectionOverviewGrid(
            itemCount: playlists.length,
            itemBuilder: (context, tileWidth, index) {
              final playlist = playlists[index];
              final subtitle = playlist.description?.trim().isNotEmpty == true
                  ? playlist.description!.trim()
                  : '歌单';

              final loadedTracks = state.playlistTracks[playlist.id];
              if (loadedTracks == null) {
                context.read<PlaylistsCubit>().ensurePlaylistTracks(
                  playlist.id,
                );
              }

              String? artworkPath;
              bool hasArtwork = false;

              if (loadedTracks != null && loadedTracks.isNotEmpty) {
                final preview = loadedTracks.firstWhere(
                  (track) => _trackArtworkExists(track.artworkPath),
                  orElse: () => loadedTracks.first,
                );
                if (_trackArtworkExists(preview.artworkPath)) {
                  artworkPath = preview.artworkPath;
                  hasArtwork = true;
                }
              }

              if (!hasArtwork && _coverExists(playlist.coverPath)) {
                artworkPath = playlist.coverPath;
                hasArtwork = true;
              }

              return CollectionSummaryCard(
                title: playlist.name,
                subtitle: subtitle,
                detailText: '${playlist.trackIds.length} 首歌曲',
                artworkPath: artworkPath,
                hasArtwork: hasArtwork,
                fallbackIcon: CupertinoIcons.square_stack_3d_up,
                onTap: () => _openPlaylist(playlist),
                onSecondaryTap: () => _editPlaylist(playlist),
              );
            },
          );
        }

        final playlist = playlists.firstWhere(
          (p) => p.id == _activePlaylistId,
          orElse: () => playlists.first,
        );
        final tracks = state.playlistTracks[playlist.id];
        final isLoading = tracks == null;

        if (isLoading) {
          context.read<PlaylistsCubit>().ensurePlaylistTracks(playlist.id);
        }

        final content = isLoading
            ? const Center(child: ProgressCircle())
            : MacOSTrackListView(
                tracks: tracks ?? const [],
                onAddToPlaylist: widget.onAddToPlaylist,
              );

        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.escape):
                const _ExitLibraryOverviewIntent(),
          },
          child: Actions(
            actions: {
              _ExitLibraryOverviewIntent: CallbackAction(
                onInvoke: (_) {
                  _returnOverview();
                  return null;
                },
              ),
            },
            child: Focus(autofocus: true, child: content),
          ),
        );
      },
    );
  }

  bool _coverExists(String? path) {
    if (path == null || path.trim().isEmpty) {
      return false;
    }
    if (kIsWeb) {
      return false;
    }
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  bool _trackArtworkExists(String? path) {
    if (path == null || path.trim().isEmpty || kIsWeb) {
      return false;
    }
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}

class _PlaylistCoverPreview extends StatelessWidget {
  const _PlaylistCoverPreview({required this.coverPath, required this.size});

  final String? coverPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MacosColors.controlBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MacosTheme.of(context).dividerColor.withOpacity(0.7),
          width: 1,
        ),
      ),
      child: const Center(
        child: MacosIcon(
          CupertinoIcons.square_stack_3d_up,
          size: 20,
          color: MacosColors.systemGrayColor,
        ),
      ),
    );

    if (coverPath == null || coverPath!.isEmpty) {
      return placeholder;
    }

    try {
      final file = File(coverPath!);
      if (!file.existsSync()) {
        return placeholder;
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
      );
    } catch (_) {
      return placeholder;
    }
  }
}
