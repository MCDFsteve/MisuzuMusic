part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _PlaybackQueueSnapshot {
  const _PlaybackQueueSnapshot({
    required this.queue,
    required this.currentIndex,
  });

  final List<Track> queue;
  final int currentIndex;

  bool get hasQueue => queue.isNotEmpty;
}

_PlaybackQueueSnapshot _queueSnapshotFromState(PlayerBlocState state) {
  List<Track> queue = const [];
  int currentIndex = 0;
  Track? currentTrack;

  if (state is PlayerPlaying) {
    queue = state.queue;
    currentIndex = state.currentIndex;
    currentTrack = state.track;
  } else if (state is PlayerPaused) {
    queue = state.queue;
    currentIndex = state.currentIndex;
    currentTrack = state.track;
  } else if (state is PlayerLoading) {
    queue = state.queue;
    currentIndex = state.currentIndex;
    currentTrack = state.track;
  } else if (state is PlayerStopped) {
    queue = state.queue;
    currentIndex = 0;
  }

  if (queue.isEmpty) {
    return const _PlaybackQueueSnapshot(queue: [], currentIndex: 0);
  }

  int effectiveIndex = currentIndex.clamp(0, queue.length - 1);
  if (currentTrack != null) {
    final currentTrackId = currentTrack!.id;
    final playingIndex = queue.indexWhere((track) => track.id == currentTrackId);
    if (playingIndex != -1) {
      effectiveIndex = playingIndex;
    }
  }

  return _PlaybackQueueSnapshot(queue: queue, currentIndex: effectiveIndex);
}

class _PlaybackQueueOverlay extends StatelessWidget {
  const _PlaybackQueueOverlay({
    required this.visible,
    required this.snapshot,
    required this.onDismiss,
    required this.onSelectTrack,
  });

  final bool visible;
  final _PlaybackQueueSnapshot snapshot;
  final VoidCallback onDismiss;
  final ValueChanged<int> onSelectTrack;

  static const double _panelWidth = 340;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (visible)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
        top: 5,
        bottom: 5,
        right: visible ? 0 : -_panelWidth - 24,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: _PlaybackQueuePanel(
              snapshot: snapshot,
              onClose: onDismiss,
              onSelectTrack: onSelectTrack,
              width: _panelWidth,
            ),
          ),
        ),
      ),
    ];

    return Stack(children: children);
  }
}

class _PlaybackQueuePanel extends StatelessWidget {
  const _PlaybackQueuePanel({
    required this.snapshot,
    required this.onClose,
    required this.onSelectTrack,
    required this.width,
  });

  final _PlaybackQueueSnapshot snapshot;
  final VoidCallback onClose;
  final ValueChanged<int> onSelectTrack;
  final double width;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(16);
    final background = macTheme.canvasColor.withOpacity(isDark ? 0.62 : 0.72);
    final borderColor =
        MacosColors.systemGrayColor.withOpacity(isDark ? 0.55 : 0.42);
    final accent = macTheme.primaryColor;
    final titleStyle = macTheme.typography.headline.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                  child: Row(
                    children: [
                      Text(context.l10n.homeQueueLabel, style: titleStyle),
                      const SizedBox(width: 6),
                      Text(
                        '${snapshot.queue.length}',
                        style: titleStyle.copyWith(
                          fontWeight: FontWeight.w500,
                          color: MacosColors.systemGrayColor,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 0.6, color: borderColor),
                Expanded(
                  child: _PlaybackQueueList(
                    queue: snapshot.queue,
                    currentIndex: snapshot.currentIndex,
                    onTap: onSelectTrack,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackQueueList extends StatefulWidget {
  const _PlaybackQueueList({
    required this.queue,
    required this.currentIndex,
    required this.onTap,
    this.controller,
    this.padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  });

  final List<Track> queue;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  State<_PlaybackQueueList> createState() => _PlaybackQueueListState();
}

class _PlaybackQueueListState extends State<_PlaybackQueueList> {
  static const double _estimatedItemExtent = 76;
  static const double _separatorExtent = 1;
  late ScrollController _controller;
  late bool _ownsController;
  final GlobalKey _currentItemKey = GlobalKey();
  Object? _lastAutoScrollSignature;

  @override
  void initState() {
    super.initState();
    _initController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant _PlaybackQueueList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _disposeControllerIfNeeded();
      _initController(widget.controller);
    }
    _scheduleScrollToCurrent();
  }

  @override
  void dispose() {
    _disposeControllerIfNeeded();
    super.dispose();
  }

  void _initController(ScrollController? external) {
    _controller = external ?? ScrollController();
    _ownsController = external == null;
    _scheduleScrollToCurrent();
  }

  void _disposeControllerIfNeeded() {
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _scheduleScrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _currentItemKey.currentContext;
      final signature = Object.hash(
        widget.currentIndex,
        widget.queue.length,
        widget.padding.top,
        widget.padding.bottom,
      );
      if (_lastAutoScrollSignature == signature) return;
      _lastAutoScrollSignature = signature;

      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: Duration.zero,
          alignment: 0.35,
        );
        return;
      }

      if (!_controller.hasClients) {
        _scheduleScrollToCurrent();
        return;
      }

      final resolvedPadding = widget.padding.resolve(TextDirection.ltr);
      final estimatedOffset = resolvedPadding.top +
          widget.currentIndex * (_estimatedItemExtent + _separatorExtent);
      final maxOffset = _controller.position.maxScrollExtent;
      final clampedOffset = estimatedOffset.clamp(0.0, maxOffset);
      _controller.jumpTo(clampedOffset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final isDark =
        (macTheme?.brightness ?? theme.brightness) == Brightness.dark;
    final accent = macTheme?.primaryColor ?? theme.colorScheme.primary;
    final dividerColor =
        (macTheme?.dividerColor ?? theme.dividerColor).withOpacity(0.9);
    final baseTextColor =
        theme.textTheme.bodyMedium?.color ??
            (isDark ? Colors.white70 : Colors.black87);

    if (widget.queue.isEmpty) {
      return Center(
        child: Text(
          context.l10n.queueEmptyMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
                color: baseTextColor.withOpacity(0.72),
              ),
        ),
      );
    }

    return ListView.separated(
      controller: _controller,
      padding: widget.padding,
      itemBuilder: (context, index) {
        final track = widget.queue[index];
        final displayInfo = deriveTrackDisplayInfo(track);
        final isCurrent = index == widget.currentIndex;
        final durationText = _formatQueueDuration(track.duration) ?? '';
        final remoteArtworkUrl = _queueArtworkUrl(track);

        final tile = TrackListTile(
          index: index + 1,
          leading: ArtworkThumbnail(
            artworkPath: track.artworkPath,
            remoteImageUrl: remoteArtworkUrl,
            size: 48,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: macTheme?.canvasColor.withOpacity(
                  isDark ? 0.16 : 0.12,
                ) ??
                theme.colorScheme.surfaceVariant
                    .withOpacity(isDark ? 0.24 : 0.18),
            borderColor: macTheme?.dividerColor ?? theme.dividerColor,
            placeholder: const MacosIcon(
              CupertinoIcons.music_note,
              color: MacosColors.systemGrayColor,
              size: 20,
            ),
          ),
          title: displayInfo.title,
          artistAlbum: '${displayInfo.artist} • ${displayInfo.album}',
          duration: durationText,
          meta: isCurrent ? context.l10n.queueNowPlaying : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          hoverDistance: 10,
          onTap: () => widget.onTap(index),
        );

        final itemKey = isCurrent ? _currentItemKey : null;

        return AnimatedContainer(
          key: itemKey,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: tile,
        );
      },
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.6,
        color: dividerColor,
        indent: 88,
      ),
      itemCount: widget.queue.length,
    );
  }
}

String? _queueArtworkUrl(Track track) {
  if (track.isNeteaseTrack) {
    return track.httpHeaders?['x-netease-cover'];
  }
  return MysteryLibraryConstants.buildArtworkUrl(
    track.httpHeaders,
    thumbnail: true,
  );
}

class _QueueBadge extends StatelessWidget {
  const _QueueBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _PlaybackQueueSheet extends StatelessWidget {
  const _PlaybackQueueSheet({required this.onPlayTrack});

  final void Function(List<Track> queue, int index) onPlayTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handleColor =
        theme.colorScheme.onSurface.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.24);
    final queueCountColor =
        theme.colorScheme.onSurface.withOpacity(theme.brightness == Brightness.dark ? 0.64 : 0.6);

    return MediaQuery.removeViewPadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: SafeArea(
        top: false,
        bottom: false,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return BlocBuilder<PlayerBloc, PlayerBlocState>(
              builder: (context, state) {
                final snapshot = _queueSnapshotFromState(state);
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.45 : 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: [
                            Text(
                              context.l10n.homeQueueLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _QueueBadge(
                              label: '${snapshot.queue.length}',
                              color: queueCountColor,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _PlaybackQueueList(
                          queue: snapshot.queue,
                          currentIndex: snapshot.currentIndex,
                          onTap: (index) {
                            onPlayTrack(snapshot.queue, index);
                            Navigator.of(context).pop();
                          },
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String? _formatQueueDuration(Duration duration) {
  if (duration.inMilliseconds <= 0) {
    return null;
  }
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${minutes}:${seconds.toString().padLeft(2, '0')}';
}
