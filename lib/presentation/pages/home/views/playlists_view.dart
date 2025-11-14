part of 'package:misuzu_music/presentation/pages/home_page.dart';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({
    super.key,
    this.onAddToPlaylist,
    this.onDetailStateChanged,
    this.searchQuery = '',
    this.onViewArtist,
    this.onViewAlbum,
    this.controller,
  });

  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<bool>? onDetailStateChanged;
  final String searchQuery;
  final ValueChanged<Track>? onViewArtist;
  final ValueChanged<Track>? onViewAlbum;
  final PlaylistsViewController? controller;

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

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant PlaylistsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  void _notifyDetailState() {
    widget.onDetailStateChanged?.call(_showList);
  }

  bool _matchesPlaylist(Playlist playlist, String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.isEmpty) {
      return true;
    }
    final name = playlist.name.toLowerCase();
    if (name.contains(lowerQuery)) {
      return true;
    }
    final description = playlist.description?.toLowerCase() ?? '';
    return description.contains(lowerQuery);
  }

  bool _matchesTrack(Track track, String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.isEmpty) {
      return true;
    }
    final display = deriveTrackDisplayInfo(track);
    return display.title.toLowerCase().contains(lowerQuery) ||
        display.artist.toLowerCase().contains(lowerQuery) ||
        display.album.toLowerCase().contains(lowerQuery);
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
        label: '自动同步设置…',
        icon: CupertinoIcons.arrow_2_squarepath,
        onSelected: () => _showAutoSyncSettingsDialog(playlist),
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
    await _showStatusDialog(title: '上传到云', message: message!, isError: isError);
  }

  Future<void> _showAutoSyncSettingsDialog(Playlist playlist) async {
    final playlistsCubit = context.read<PlaylistsCubit>();
    final currentConfig = playlistsCubit.autoSyncSettingOf(playlist.id);
    final result = await showPlaylistModalDialog<_PlaylistAutoSyncDialogResult>(
      context: context,
      builder: (_) => _PlaylistAutoSyncDialog(
        playlistName: playlist.name,
        initialConfig: currentConfig,
        idRuleDescription: playlistsCubit.cloudIdRuleDescription,
        validator: playlistsCubit.isValidCloudPlaylistId,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final trimmedRemoteId = result.remoteId.trim();
    final shouldClear = result.shouldClear;

    if (shouldClear) {
      await playlistsCubit.clearAutoSyncSetting(playlist.id);
      if (currentConfig != null) {
        await _showStatusDialog(title: '自动同步', message: '已清除自动同步设置');
      } else {
        await _showStatusDialog(title: '自动同步', message: '当前没有自动同步设置');
      }
      return;
    }

    final hasChange =
        currentConfig == null ||
        currentConfig.remoteId != trimmedRemoteId ||
        currentConfig.enabled != result.enabled;

    if (hasChange) {
      await playlistsCubit.saveAutoSyncSetting(
        playlistId: playlist.id,
        config: PlaylistAutoSyncConfig(
          remoteId: trimmedRemoteId,
          enabled: result.enabled,
        ),
      );
    }

    if (result.enabled) {
      final error = await playlistsCubit.syncPlaylistFromCloud(
        playlist.id,
        force: true,
      );
      if (error != null) {
        await _showStatusDialog(title: '自动同步', message: error, isError: true);
        return;
      }
      await _showStatusDialog(
        title: '自动同步',
        message: hasChange ? '已开启自动同步，并从云端刷新歌单' : '已从云端刷新自动同步歌单',
      );
    } else {
      if (hasChange) {
        await _showStatusDialog(title: '自动同步', message: '已保存自动同步设置');
      } else {
        await _showStatusDialog(title: '自动同步', message: '自动同步设置未变更');
      }
    }
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

  Future<void> _showStatusDialog({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) {
      return;
    }

    final icon = isError
        ? CupertinoIcons.exclamationmark_triangle_fill
        : CupertinoIcons.check_mark_circled_solid;
    final iconColor = isError
        ? MacosColors.systemRedColor
        : MacosColors.systemGreenColor;

    await showPlaylistModalDialog<void>(
      context: context,
      builder: (_) => _PlaylistModalScaffold(
        title: title,
        maxWidth: 360,
        contentSpacing: 16,
        actionsSpacing: 20,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MacosIcon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, locale: const Locale('zh-Hans', 'zh')),
            ),
          ],
        ),
        actions: [
          _SheetActionButton.primary(
            label: '好的',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
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
        final query = widget.searchQuery.trim();
        final hasQuery = query.isNotEmpty;

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
                Text('暂无歌单', locale: Locale("zh-Hans", "zh")),
              ],
            ),
          );
        }

        final filteredPlaylists = hasQuery
            ? playlists
                  .where((playlist) => _matchesPlaylist(playlist, query))
                  .toList()
            : playlists;

        Widget overviewContent;
        if (hasQuery && filteredPlaylists.isEmpty) {
          overviewContent = const _PlaylistMessage(
            icon: CupertinoIcons.search,
            message: '未找到匹配的歌单',
          );
        } else {
          overviewContent = CollectionOverviewGrid(
            itemCount: filteredPlaylists.length,
            itemBuilder: (context, tileWidth, index) {
              final playlist = filteredPlaylists[index];
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

        Widget detailContent;
        if (_showList) {
          final playlist = playlists.firstWhere(
            (p) => p.id == _activePlaylistId,
            orElse: () => playlists.first,
          );
          final tracks = state.playlistTracks[playlist.id];
          if (tracks == null) {
            context.read<PlaylistsCubit>().ensurePlaylistTracks(playlist.id);
            detailContent = const Center(child: ProgressCircle());
          } else {
            final List<Track> currentTracks = tracks;
            final List<Track> filteredTracks = hasQuery
                ? currentTracks
                      .where((track) => _matchesTrack(track, query))
                      .toList()
                : currentTracks;

            if (hasQuery && filteredTracks.isEmpty) {
              detailContent = const _PlaylistMessage(
                icon: CupertinoIcons.search,
                message: '歌单中未找到匹配的歌曲',
              );
            } else {
              detailContent = MacOSTrackListView(
                tracks: filteredTracks,
                onAddToPlaylist: widget.onAddToPlaylist,
                onRemoveFromPlaylist: (track) =>
                    _removeTrackFromPlaylist(playlist.id, track),
                onViewArtist: widget.onViewArtist,
                onViewAlbum: widget.onViewAlbum,
              );
            }
          }
        } else {
          detailContent = const SizedBox.shrink();
        }

        Widget detailWithShortcuts = detailContent;
        if (_showList) {
          detailWithShortcuts = Shortcuts(
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
              child: Focus(autofocus: true, child: detailContent),
            ),
          );
        }

        final Widget animated = AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            final isOverview =
                (child.key as ValueKey<String>?)?.value == 'playlists_overview';
            final offsetTween = Tween<Offset>(
              begin: isOverview
                  ? const Offset(-0.02, 0)
                  : const Offset(0.02, 0),
              end: Offset.zero,
            );
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: offsetTween.animate(curvedAnimation),
                child: child,
              ),
            );
          },
          child: _showList
              ? KeyedSubtree(
                  key: const ValueKey<String>('playlists_detail'),
                  child: detailWithShortcuts,
                )
              : KeyedSubtree(
                  key: const ValueKey<String>('playlists_overview'),
                  child: overviewContent,
                ),
        );

        return animated;
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

class PlaylistsViewController {
  _PlaylistsViewState? _state;

  void _attach(_PlaylistsViewState state) {
    _state = state;
  }

  void _detach(_PlaylistsViewState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  void exitToOverview() => _state?.exitToOverview();

  void openPlaylistById(String id) => _state?.openPlaylistById(id);
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

class _PlaylistAutoSyncDialogResult {
  const _PlaylistAutoSyncDialogResult({
    required this.remoteId,
    required this.enabled,
    this.cleared = false,
  });

  final String remoteId;
  final bool enabled;
  final bool cleared;

  bool get shouldClear => cleared || remoteId.trim().isEmpty;
}

class _PlaylistAutoSyncDialog extends StatefulWidget {
  const _PlaylistAutoSyncDialog({
    required this.playlistName,
    required this.initialConfig,
    required this.idRuleDescription,
    required this.validator,
  });

  final String playlistName;
  final PlaylistAutoSyncConfig? initialConfig;
  final String idRuleDescription;
  final bool Function(String) validator;

  @override
  State<_PlaylistAutoSyncDialog> createState() =>
      _PlaylistAutoSyncDialogState();
}

class _PlaylistAutoSyncDialogState extends State<_PlaylistAutoSyncDialog> {
  late final TextEditingController _controller;
  late final VoidCallback _controllerListener;
  bool _enabled = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialConfig?.enabled ?? false;
    _controller = TextEditingController(
      text: widget.initialConfig?.remoteId ?? '',
    );
    _controllerListener = () {
      setState(() {
        if (_errorText != null) {
          _errorText = null;
        }
      });
    };
    _controller.addListener(_controllerListener);
  }

  @override
  void dispose() {
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }

  void _onToggle(bool? value) {
    setState(() => _enabled = value ?? false);
  }

  void _onClear() {
    Navigator.of(context).pop(
      const _PlaylistAutoSyncDialogResult(
        remoteId: '',
        enabled: false,
        cleared: true,
      ),
    );
  }

  void _onSubmit() {
    final remoteId = _controller.text.trim();
    if (remoteId.isEmpty) {
      Navigator.of(context).pop(
        const _PlaylistAutoSyncDialogResult(
          remoteId: '',
          enabled: false,
          cleared: true,
        ),
      );
      return;
    }

    if (!widget.validator(remoteId)) {
      setState(() => _errorText = widget.idRuleDescription);
      return;
    }

    Navigator.of(
      context,
    ).pop(_PlaylistAutoSyncDialogResult(remoteId: remoteId, enabled: _enabled));
  }

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final typography = macTheme.typography;
    final secondaryStyle = typography.caption1.copyWith(
      color: MacosColors.secondaryLabelColor,
    );

    return _PlaylistModalScaffold(
      title: '自动同步设置',
      maxWidth: 380,
      contentSpacing: 18,
      actionsSpacing: 16,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('歌单 “${widget.playlistName}”', style: typography.title3),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MacosCheckbox(value: _enabled, onChanged: _onToggle),
              const SizedBox(width: 8),
              Expanded(child: Text('启用自动同步到云端', style: typography.body)),
            ],
          ),
          const SizedBox(height: 12),
          _MacosField(
            label: '云端 ID',
            controller: _controller,
            placeholder: '至少 5 位字母、数字或下划线',
            errorText: _errorText,
          ),
          const SizedBox(height: 6),
          Text(widget.idRuleDescription, style: secondaryStyle),
          const SizedBox(height: 16),
          Text('开启后，会在添加或移除歌曲时自动上传；每次启动应用时也会从云端拉取最新歌单。', style: secondaryStyle),
        ],
      ),
      actions: [
        _SheetActionButton.secondary(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (widget.initialConfig != null || _controller.text.trim().isNotEmpty)
          _SheetActionButton.secondary(label: '清除设置', onPressed: _onClear),
        _SheetActionButton.primary(label: '保存', onPressed: _onSubmit),
      ],
    );
  }
}
