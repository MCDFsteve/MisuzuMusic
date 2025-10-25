part of 'package:misuzu_music/presentation/pages/home_page.dart';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({
    super.key,
    this.onAddToPlaylist,
    this.onDetailStateChanged,
  });

  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<bool>? onDetailStateChanged;

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  bool _showList = false;
  String? _activePlaylistId;

  bool get canNavigateBack => _showList;

  void exitToOverview() {
    if (!_showList) {
      return;
    }
    setState(() {
      _showList = false;
      _activePlaylistId = null;
    });
    _notifyDetailState();
  }

  void _notifyDetailState() {
    widget.onDetailStateChanged?.call(_showList);
  }

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
    _notifyDetailState();
  }

  void _openPlaylist(Playlist playlist) {
    openPlaylistById(playlist.id);
  }

  Future<void> _showPlaylistContextMenu(
    Playlist playlist,
    Offset position,
  ) async {
    final actions = <MacosContextMenuAction>[
      MacosContextMenuAction(
        label: '打开歌单',
        icon: CupertinoIcons.play_circle,
        onSelected: () => _openPlaylist(playlist),
      ),
      MacosContextMenuAction(
        label: '编辑歌单',
        icon: CupertinoIcons.pencil,
        onSelected: () => _editPlaylist(playlist),
      ),
      MacosContextMenuAction(
        label: '上传到云',
        icon: CupertinoIcons.cloud_upload,
        onSelected: () => _handleUploadToCloud(playlist),
      ),
    ];

    await MacosContextMenu.show(
      context: context,
      globalPosition: position,
      actions: actions,
    );
  }

  Future<void> _handleUploadToCloud(Playlist playlist) async {
    final playlistsCubit = context.read<PlaylistsCubit>();
    final cloudId = await showCloudPlaylistIdDialog(
      context,
      title: '上传到云',
      confirmLabel: '上传',
      invalidMessage: playlistsCubit.cloudIdRuleDescription,
      description: '为 “${playlist.name}” 指定云端 ID，用于其它设备拉取。',
      validator: playlistsCubit.isValidCloudPlaylistId,
    );
    if (!mounted || cloudId == null) {
      return;
    }

    String? message;
    var isError = false;
    await _runWithBlockingProgress(
      title: '正在上传云歌单...',
      task: () async {
        final error = await playlistsCubit.uploadPlaylistToCloud(
          playlist: playlist,
          remoteId: cloudId,
        );
        message = error ?? '上传成功（ID: $cloudId）';
        isError = error != null;
      },
    );

    if (!mounted || message == null) {
      return;
    }
    _showSnack(message!, isError: isError);
  }

  Future<void> _runWithBlockingProgress({
    required String title,
    required Future<void> Function() task,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showPlaylistModalDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PlaylistModalScaffold(
        title: title,
        body: const SizedBox(
          height: 80,
          child: Center(child: ProgressCircle()),
        ),
        actions: const [],
        maxWidth: 240,
        contentSpacing: 20,
        actionsSpacing: 0,
      ),
    );

    await Future<void>.delayed(Duration.zero);

    try {
      await task();
    } finally {
      if (mounted && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message,locale: Locale("zh-Hans", "zh"),),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _returnOverview() {
    setState(() {
      _showList = false;
      _activePlaylistId = null;
    });
    _notifyDetailState();
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
                Text('暂无歌单',locale: Locale("zh-Hans", "zh"),),
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

              final resolvedArtwork = _resolvePlaylistArtwork(
                playlist,
                loadedTracks,
              );
              final artworkPath = resolvedArtwork?.path;
              final hasArtwork = resolvedArtwork?.hasArtwork ?? false;

              return CollectionSummaryCard(
                title: playlist.name,
                subtitle: subtitle,
                detailText: '${playlist.trackIds.length} 首歌曲',
                artworkPath: artworkPath,
                hasArtwork: hasArtwork,
                fallbackIcon: CupertinoIcons.square_stack_3d_up,
                onTap: () => _openPlaylist(playlist),
                onContextMenuRequested: (position) =>
                    _showPlaylistContextMenu(playlist, position),
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
                onRemoveFromPlaylist: (track) =>
                    _removeTrackFromPlaylist(playlist.id, track),
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

  Future<void> _removeTrackFromPlaylist(String playlistId, Track track) async {
    final playlistsCubit = context.read<PlaylistsCubit>();
    await playlistsCubit.removeTrackFromPlaylist(playlistId, track);
  }

  _ResolvedArtwork? _resolvePlaylistArtwork(
    Playlist playlist,
    List<Track>? tracks,
  ) {
    if (_coverExists(playlist.coverPath)) {
      return _ResolvedArtwork(path: playlist.coverPath, hasArtwork: true);
    }

    if (tracks == null || tracks.isEmpty) {
      return const _ResolvedArtwork(path: null, hasArtwork: false);
    }

    final Map<String, Track> trackByHash = {
      for (final track in tracks) (track.contentHash ?? track.id): track,
    };

    for (final trackId in playlist.trackIds.reversed) {
      final track = trackByHash[trackId];
      if (track == null) {
        continue;
      }
      final artworkPath = track.artworkPath;
      if (_trackArtworkExists(artworkPath)) {
        return _ResolvedArtwork(path: artworkPath, hasArtwork: true);
      }
    }

    for (final track in tracks.reversed) {
      if (_trackArtworkExists(track.artworkPath)) {
        return _ResolvedArtwork(path: track.artworkPath, hasArtwork: true);
      }
    }

    return const _ResolvedArtwork(path: null, hasArtwork: false);
  }
}

class _ResolvedArtwork {
  const _ResolvedArtwork({required this.path, required this.hasArtwork});

  final String? path;
  final bool hasArtwork;
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
