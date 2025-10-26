part of 'package:misuzu_music/presentation/pages/home_page.dart';

class NeteaseView extends StatefulWidget {
  const NeteaseView({
    super.key,
    this.onAddToPlaylist,
    this.onDetailStateChanged,
  });

  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<bool>? onDetailStateChanged;

  @override
  State<NeteaseView> createState() => _NeteaseViewState();
}

class _NeteaseViewState extends State<NeteaseView> {
  bool _showPlaylistDetail = false;
  int? _activePlaylistId;
  bool _promptedForCookie = false;
  bool _dialogVisible = false;
  String? _toastMessage;
  bool _toastIsError = false;
  Timer? _toastTimer;

  bool get canNavigateBack => _showPlaylistDetail;

  void exitToOverview() {
    if (!_showPlaylistDetail) {
      return;
    }
    setState(() {
      _showPlaylistDetail = false;
      _activePlaylistId = null;
    });
    _notifyDetailState();
  }

  void _notifyDetailState() {
    widget.onDetailStateChanged?.call(_showPlaylistDetail);
  }

  Future<void> _promptForCookie({bool force = false}) async {
    if (_dialogVisible) {
      return;
    }
    _dialogVisible = true;
    final cookie = await showNeteaseCookieDialog(context, force: force);
    _dialogVisible = false;
    if (!mounted || cookie == null || cookie.trim().isEmpty) {
      return;
    }
    await context.read<NeteaseCubit>().loginWithCookie(cookie);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastIsError = isError;
    });
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _toastMessage = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NeteaseCubit, NeteaseState>(
      listener: (context, state) {
        if (!state.isInitializing && !state.hasSession && !_promptedForCookie) {
          _promptForCookie(force: true);
          _promptedForCookie = true;
        }
        if (state.errorMessage != null) {
          _showToast(state.errorMessage!, isError: true);
          context.read<NeteaseCubit>().clearMessage();
        }
      },
      builder: (context, state) {
        if (state.isInitializing) {
          return const Center(child: ProgressCircle());
        }

        final overlay = <Widget>[];
        if (_toastMessage != null) {
          overlay.add(
            Positioned(
              bottom: 16,
              right: 16,
              child: _NeteaseToast(
                message: _toastMessage!,
                isError: _toastIsError,
              ),
            ),
          );
        }
        if (state.isSubmittingCookie) {
          overlay.add(
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: ProgressCircle()),
              ),
            ),
          );
        }

        Widget content;
        if (state.session == null) {
          content = _NeteaseLoginPlaceholder(
            onTap: () => _promptForCookie(force: true),
          );
        } else if (_showPlaylistDetail) {
          content = _buildPlaylistDetail(state);
        } else {
          content = _buildPlaylistOverview(state);
        }

        return Stack(children: [content, ...overlay]);
      },
    );
  }

  Widget _buildPlaylistOverview(NeteaseState state) {
    if (state.isLoadingPlaylists && state.playlists.isEmpty) {
      return const Center(child: ProgressCircle());
    }
    if (state.playlists.isEmpty) {
      return _NeteaseEmptyMessage(
        message: '还没有同步网易云歌单',
        actionLabel: '刷新歌单',
        onAction: () => context.read<NeteaseCubit>().refreshPlaylists(),
      );
    }
    return CollectionOverviewGrid(
      itemCount: state.playlists.length,
      padding: EdgeInsets.zero,
      scrollbarMargin: EdgeInsets.zero,
      itemBuilder: (context, tileWidth, index) {
        final playlist = state.playlists[index];
        final subtitle = playlist.description?.trim().isNotEmpty == true
            ? playlist.description!.trim()
            : '网易云歌单';
        final detailText =
            '${playlist.trackCount} 首 · 播放 ${_formatPlayCount(playlist.playCount)}';
        return CollectionSummaryCard(
          title: playlist.name,
          subtitle: subtitle,
          detailText: detailText,
          remoteImageUrl: playlist.coverUrl,
          hasArtwork: playlist.coverUrl != null,
          fallbackIcon: CupertinoIcons.music_note,
          onTap: () => _openPlaylist(playlist),
        );
      },
    );
  }

  Widget _buildPlaylistDetail(NeteaseState state) {
    NeteasePlaylist? playlist;
    if (_activePlaylistId != null) {
      for (final item in state.playlists) {
        if (item.id == _activePlaylistId) {
          playlist = item;
          break;
        }
      }
    }
    playlist ??= state.playlists.isNotEmpty ? state.playlists.first : null;
    if (playlist == null) {
      exitToOverview();
      return _buildPlaylistOverview(state);
    }
    final resolvedPlaylist = playlist;
    final tracks = state.playlistTracks[resolvedPlaylist.id];
    if (tracks == null) {
      context.read<NeteaseCubit>().ensurePlaylistTracks(resolvedPlaylist.id);
    }
    final Widget content = tracks == null
        ? const Center(child: ProgressCircle())
        : MacOSTrackListView(
            tracks: tracks,
            onAddToPlaylist: null,
            additionalActionsBuilder: _neteaseContextActions,
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
              exitToOverview();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: content,
        ),
      ),
    );
  }

  void _openPlaylist(NeteasePlaylist playlist) {
    setState(() {
      _showPlaylistDetail = true;
      _activePlaylistId = playlist.id;
    });
    _notifyDetailState();
    context.read<NeteaseCubit>().ensurePlaylistTracks(playlist.id);
  }

  String _formatPlayCount(int value) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)} 亿';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)} 万';
    }
    return value.toString();
  }

  List<MacosContextMenuAction> _neteaseContextActions(Track track) {
    if (track.sourceType == TrackSourceType.netease) {
      return [
        MacosContextMenuAction(
          label: '添加到网易云歌单…',
          icon: CupertinoIcons.cloud_upload,
          onSelected: () => _promptAddTrackToNeteasePlaylist(track),
        ),
      ];
    }
    if (widget.onAddToPlaylist == null) {
      return const [];
    }
    return [
      MacosContextMenuAction(
        label: '添加到歌单',
        icon: CupertinoIcons.add_circled,
        onSelected: () => widget.onAddToPlaylist?.call(track),
      ),
    ];
  }

  Future<void> _promptAddTrackToNeteasePlaylist(Track track) async {
    final cubit = context.read<NeteaseCubit>();
    List<NeteasePlaylist> playlists = cubit.state.playlists;
    if (playlists.isEmpty) {
      await cubit.refreshPlaylists();
      if (!mounted) return;
      playlists = cubit.state.playlists;
      if (playlists.isEmpty) {
        _showToast('暂无可用的网易云歌单', isError: true);
        return;
      }
    }

    final selectedId = await _showNeteasePlaylistSelectionSheet(
      context,
      playlists: playlists,
      initialId: playlists.first.id,
    );

    if (!mounted || selectedId == null) {
      return;
    }

    final error = await cubit.addTrackToPlaylist(selectedId, track);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _showToast('已添加到网易云歌单');
    } else {
      _showToast(error, isError: true);
    }
  }
}

Future<int?> _showNeteasePlaylistSelectionSheet(
  BuildContext context, {
  required List<NeteasePlaylist> playlists,
  required int initialId,
}) {
  return showPlaylistModalDialog<int>(
    context: context,
    builder: (_) => _NeteasePlaylistSelectionSheet(
      playlists: playlists,
      initialId: initialId,
    ),
  );
}

class _NeteasePlaylistSelectionSheet extends StatefulWidget {
  const _NeteasePlaylistSelectionSheet({
    required this.playlists,
    required this.initialId,
  });

  final List<NeteasePlaylist> playlists;
  final int initialId;

  @override
  State<_NeteasePlaylistSelectionSheet> createState() =>
      _NeteasePlaylistSelectionSheetState();
}

class _NeteasePlaylistSelectionSheetState
    extends State<_NeteasePlaylistSelectionSheet> {
  late int? _selectedId = widget.initialId;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlists = widget.playlists;
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;

    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: MacosScrollbar(
        controller: _controller,
        child: ListView.separated(
          controller: _controller,
          shrinkWrap: true,
          itemCount: playlists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return _NeteasePlaylistEntryTile(
              playlist: playlist,
              isDark: isDark,
              selectedId: _selectedId,
              onSelected: () {
                setState(() {
                  _selectedId = playlist.id;
                });
              },
            );
          },
        ),
      ),
    );

    final actions = <Widget>[
      _SheetActionButton.secondary(
        label: '取消',
        onPressed: () => Navigator.of(context).pop(),
      ),
      _SheetActionButton.primary(
        label: '添加',
        onPressed: _selectedId == null
            ? null
            : () => Navigator.of(context).pop(_selectedId),
      ),
    ];

    return _PlaylistModalScaffold(
      title: '添加到网易云歌单',
      body: body,
      actions: actions,
      maxWidth: 360,
      contentSpacing: 14,
      actionsSpacing: 14,
    );
  }
}

class _NeteasePlaylistEntryTile extends StatelessWidget {
  const _NeteasePlaylistEntryTile({
    required this.playlist,
    required this.isDark,
    required this.selectedId,
    required this.onSelected,
  });

  final NeteasePlaylist playlist;
  final bool isDark;
  final int? selectedId;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.65)
        : Colors.black.withOpacity(0.6);
    final selected = playlist.id == selectedId;

    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? macTheme.primaryColor.withOpacity(0.6)
                : macTheme.dividerColor.withOpacity(0.4),
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            MacosRadioButton<int>(
              value: playlist.id,
              groupValue: selectedId,
              onChanged: (_) => onSelected(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    locale: const Locale('zh-Hans', 'zh'),
                    style: macTheme.typography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.trackCount} 首 · ${playlist.playCount} 次播放',
                    locale: const Locale('zh-Hans', 'zh'),
                    style: macTheme.typography.caption1.copyWith(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _NeteaseLoginPlaceholder extends StatelessWidget {
  const _NeteaseLoginPlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MacosIcon(
            CupertinoIcons.cloud,
            size: 72,
            color: MacosColors.systemGrayColor,
          ),
          const SizedBox(height: 16),
          const Text('需要先粘贴网易云 Cookie 才能读取歌单', locale: Locale("zh-Hans", "zh")),
          const SizedBox(height: 12),
          PushButton(
            controlSize: ControlSize.large,
            onPressed: onTap,
            child: const Text('粘贴 Cookie 登录', locale: Locale("zh-Hans", "zh")),
          ),
        ],
      ),
    );
  }
}

class _NeteaseEmptyMessage extends StatelessWidget {
  const _NeteaseEmptyMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, locale: Locale("zh-Hans", "zh")),
          const SizedBox(height: 12),
          PushButton(
            controlSize: ControlSize.large,
            onPressed: onAction,
            child: Text(actionLabel, locale: Locale("zh-Hans", "zh")),
          ),
        ],
      ),
    );
  }
}

class _NeteaseToast extends StatelessWidget {
  const _NeteaseToast({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isError
                ? Colors.red.withOpacity(0.65)
                : Colors.black.withOpacity(0.35),
          ),
          child: Text(
            message,
            locale: Locale("zh-Hans", "zh"),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

Future<String?> showNeteaseCookieDialog(
  BuildContext context, {
  bool force = false,
}) {
  final controller = TextEditingController();
  return showMacosAlertDialog(
    context: context,
    builder: (ctx) => MacosAlertDialog(
      appIcon: const MacosIcon(CupertinoIcons.cloud),
      title: const Text('粘贴网易云 Cookie', locale: Locale("zh-Hans", "zh")),
      message: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '打开 https://music.163.com/ 并登录后，使用浏览器复制包含 MUSIC_U、__csrf 等字段的 Cookie。',
            locale: Locale("zh-Hans", "zh"),
          ),
          const SizedBox(height: 12),
          MacosTextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            placeholder: 'MUSIC_U=...; __csrf=...;',
          ),
        ],
      ),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
        child: const Text('确认', locale: Locale("zh-Hans", "zh")),
      ),
      secondaryButton: force
          ? PushButton(
              controlSize: ControlSize.large,
              secondary: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消', locale: Locale("zh-Hans", "zh")),
            )
          : null,
    ),
  );
}
