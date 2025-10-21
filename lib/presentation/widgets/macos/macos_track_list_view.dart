import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../common/adaptive_scrollbar.dart';
import '../common/artwork_thumbnail.dart';
import '../common/track_list_tile.dart';

class MacOSTrackListView extends StatelessWidget {
  const MacOSTrackListView({
    super.key,
    required this.tracks,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
  });

  final List<Track> tracks;
  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<Track>? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return AdaptiveScrollbar(
      isDarkMode: isDarkMode,
      builder: (controller) {
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tracks.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: MacosTheme.of(context).dividerColor,
            indent: 88,
          ),
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackListTile(
              index: index + 1,
              leading: ArtworkThumbnail(
                artworkPath: track.artworkPath,
                size: 48,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: MacosColors.controlBackgroundColor,
                borderColor: MacosTheme.of(context).dividerColor,
                placeholder: const MacosIcon(
                  CupertinoIcons.music_note,
                  color: MacosColors.systemGrayColor,
                  size: 20,
                ),
              ),
              title: track.title,
              artistAlbum: '${track.artist} • ${track.album}',
              duration: _formatDuration(track.duration),
              onTap: () {
                final isRemoteTrack =
                    track.sourceType == TrackSourceType.webdav ||
                    track.filePath.startsWith('webdav://');

                if (!isRemoteTrack && !kIsWeb) {
                  final file = File(track.filePath);
                  final exists = file.existsSync();

                  if (!exists) {
                    return;
                  }
                }

                context.read<PlayerBloc>().add(
                  PlayerSetQueue(tracks, startIndex: index),
                );
              },
              onSecondaryTap: (position) {
                _handleSecondaryTap(context, position, track);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleSecondaryTap(
    BuildContext context,
    Offset globalPosition,
    Track track,
  ) async {
    final hasAdd = onAddToPlaylist != null;
    final hasRemove = onRemoveFromPlaylist != null;
    if (!hasAdd && !hasRemove) {
      return;
    }

    final overlay = Overlay.of(context);
    if (overlay == null) {
      return;
    }

    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final position = overlayBox.globalToLocal(globalPosition);

    final actions = <_ContextMenuAction>[];
    if (hasAdd) {
      actions.add(
        _ContextMenuAction(
          id: 'add',
          label: '添加到歌单',
          icon: CupertinoIcons.add_circled,
          onSelected: () => onAddToPlaylist?.call(track),
        ),
      );
    }
    if (hasRemove) {
      actions.add(
        _ContextMenuAction(
          id: 'remove',
          label: '从歌单删除',
          icon: CupertinoIcons.minus_circle,
          onSelected: () => onRemoveFromPlaylist?.call(track),
        ),
      );
    }

    await _TrackContextMenu.show(
      overlay: overlay,
      position: position,
      actions: actions,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ContextMenuAction {
  const _ContextMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

class _TrackContextMenu extends StatefulWidget {
  const _TrackContextMenu({
    required this.position,
    required this.actions,
    required this.onDismiss,
  });

  final Offset position;
  final List<_ContextMenuAction> actions;
  final VoidCallback onDismiss;

  static Future<void> show({
    required OverlayState overlay,
    required Offset position,
    required List<_ContextMenuAction> actions,
  }) {
    final completer = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TrackContextMenu(
        position: position,
        actions: actions,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );
    overlay.insert(entry);
    return completer.future;
  }

  @override
  State<_TrackContextMenu> createState() => _TrackContextMenuState();
}

class _TrackContextMenuState extends State<_TrackContextMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final isDark =
        (macTheme?.brightness ?? theme.brightness) == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
            ),
          ),
          Positioned(
            left: widget.position.dx,
            top: widget.position.dy,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOut,
              ),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutBack,
                ),
                child: _MenuSurface(
                  actions: widget.actions,
                  onDismiss: widget.onDismiss,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSurface extends StatelessWidget {
  const _MenuSurface({
    required this.actions,
    required this.onDismiss,
    required this.isDark,
  });

  final List<_ContextMenuAction> actions;
  final VoidCallback onDismiss;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final background = isDark
        ? const Color(0xFF1C1C23).withOpacity(0.9)
        : Colors.white.withOpacity(0.97);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    return Container(
      width: 188,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: actions
            .map(
              (action) => _MenuTile(
                action: action,
                onDismiss: onDismiss,
                isDark: isDark,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MenuTile extends StatefulWidget {
  const _MenuTile({
    required this.action,
    required this.onDismiss,
    required this.isDark,
  });

  final _ContextMenuAction action;
  final VoidCallback onDismiss;
  final bool isDark;

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);
    final iconColor = widget.isDark
        ? Colors.white.withOpacity(_hovering ? 0.95 : 0.82)
        : Colors.black.withOpacity(_hovering ? 0.82 : 0.7);
    final textColor = widget.isDark
        ? Colors.white.withOpacity(_hovering ? 0.95 : 0.88)
        : Colors.black.withOpacity(_hovering ? 0.9 : 0.75);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onDismiss();
          widget.action.onSelected();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering ? hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.action.icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.action.label,
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontSize: 13,
                      ) ??
                      TextStyle(color: textColor, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
