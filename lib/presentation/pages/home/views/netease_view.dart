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
  Widget build(BuildContext context) {
    return BlocConsumer<NeteaseCubit, NeteaseState>(
      listener: (context, state) {
        if (!state.isInitializing && !state.hasSession && !_promptedForCookie) {
          _promptForCookie(force: true);
          _promptedForCookie = true;
        }
      },
      builder: (context, state) {
        if (state.isInitializing) {
          return const Center(child: ProgressCircle());
        }

        final overlay = <Widget>[];
        if (state.errorMessage != null) {
          overlay.add(
            Positioned(
              bottom: 16,
              right: 16,
              child: _NeteaseToast(message: state.errorMessage!),
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

    final header = _NeteasePlaylistHeader(playlist: resolvedPlaylist);
    final content = tracks == null
        ? const Expanded(child: Center(child: ProgressCircle()))
        : Expanded(
            child: MacOSTrackListView(
              tracks: tracks,
              onAddToPlaylist: widget.onAddToPlaylist,
            ),
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, const SizedBox(height: 16), content],
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
          child: Padding(padding: const EdgeInsets.all(24), child: body),
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
}

class _NeteasePlaylistHeader extends StatelessWidget {
  const _NeteasePlaylistHeader({required this.playlist});

  final NeteasePlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final titleStyle = macTheme.typography.title2;
    final subtitleStyle = macTheme.typography.body.copyWith(
      color: macTheme.typography.body.color?.withOpacity(0.72),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RemoteArtworkPreview(url: playlist.coverUrl),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playlist.name,
                locale: Locale("zh-Hans", "zh"),
                style: titleStyle,
              ),
              const SizedBox(height: 6),
              Text(
                '${playlist.trackCount} 首歌曲 · 创建者 ${playlist.creatorName}',
                locale: Locale("zh-Hans", "zh"),
                style: subtitleStyle,
              ),
              if ((playlist.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  playlist.description!.trim(),
                  locale: Locale("zh-Hans", "zh"),
                  style: subtitleStyle,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RemoteArtworkPreview extends StatelessWidget {
  const _RemoteArtworkPreview({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: MacosColors.controlBackgroundColor,
        border: Border.all(
          color: MacosTheme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Center(
              child: MacosIcon(
                CupertinoIcons.music_note,
                size: 40,
                color: MacosColors.systemGrayColor,
              ),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: MacosIcon(
                  CupertinoIcons.photo,
                  size: 36,
                  color: MacosColors.systemGrayColor,
                ),
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
  const _NeteaseToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35)),
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
