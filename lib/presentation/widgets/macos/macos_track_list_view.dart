import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../../domain/entities/music_entities.dart';
import '../../blocs/player/player_bloc.dart';
import '../common/adaptive_scrollbar.dart';
import '../common/artwork_thumbnail.dart';
import '../common/track_list_tile.dart';
import 'context_menu/macos_context_menu.dart';

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
              onTap: () => _handleTrackTap(context, track, index),
              onSecondaryTap: (position) =>
                  _handleSecondaryTap(context, position, track),
            );
          },
        );
      },
    );
  }

  void _handleTrackTap(BuildContext context, Track track, int index) {
    final isRemoteTrack =
        track.sourceType == TrackSourceType.webdav ||
        track.filePath.startsWith('webdav://');

    if (!isRemoteTrack && !kIsWeb) {
      final file = File(track.filePath);
      if (!file.existsSync()) {
        return;
      }
    }

    context.read<PlayerBloc>().add(PlayerSetQueue(tracks, startIndex: index));
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

    final actions = <MacosContextMenuAction>[];
    if (hasAdd) {
      actions.add(
        MacosContextMenuAction(
          label: '添加到歌单',
          icon: CupertinoIcons.add_circled,
          onSelected: () => onAddToPlaylist?.call(track),
        ),
      );
    }
    if (hasRemove) {
      actions.add(
        MacosContextMenuAction(
          label: '从歌单删除',
          icon: CupertinoIcons.minus_circle,
          onSelected: () => onRemoveFromPlaylist?.call(track),
          destructive: true,
        ),
      );
    }

    await MacosContextMenu.show(
      context: context,
      globalPosition: globalPosition,
      actions: actions,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
