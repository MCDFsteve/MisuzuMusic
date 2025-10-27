import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../../core/constants/mystery_library_constants.dart';
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
    this.additionalActionsBuilder,
    this.onTrackSelected,
  });

  final List<Track> tracks;
  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<Track>? onRemoveFromPlaylist;
  final List<MacosContextMenuAction> Function(Track track)? additionalActionsBuilder;
  final ValueChanged<Track>? onTrackSelected;

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
            String? remoteArtworkUrl;
            if (_isNetworkSong(track)) {
              remoteArtworkUrl = track.httpHeaders?['x-netease-cover'];
            } else {
              remoteArtworkUrl = MysteryLibraryConstants.buildArtworkUrl(
                track.httpHeaders,
                thumbnail: true,
              );
            }
            return TrackListTile(
              index: index + 1,
              leading: ArtworkThumbnail(
                artworkPath: track.artworkPath,
                remoteImageUrl: remoteArtworkUrl,
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
                if (onTrackSelected != null) {
                  onTrackSelected!(track);
                } else {
                  _handleTrackTap(context, track, index);
                }
              },
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
        track.filePath.startsWith('webdav://') ||
        track.sourceType == TrackSourceType.mystery ||
        track.filePath.startsWith('mystery://') ||
        track.sourceType == TrackSourceType.netease ||
        track.filePath.startsWith('netease://');

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
    final customActions = additionalActionsBuilder != null
        ? additionalActionsBuilder!(track)
        : const <MacosContextMenuAction>[];

    if (!hasAdd && !hasRemove && customActions.isEmpty) {
      return;
    }

    final actions = <MacosContextMenuAction>[];
    if (customActions.isNotEmpty) {
      actions.addAll(customActions);
    }
    final isNeteaseTrack = track.isNeteaseTrack;
    final allowLocalAdd = hasAdd && !isNeteaseTrack;
    if (allowLocalAdd) {
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
          onSelected: () => _confirmRemoveTrack(context, track),
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

  void _confirmRemoveTrack(BuildContext context, Track track) {
    _showRemoveConfirmationDialog(context, track).then((confirmed) {
      if (confirmed == true) {
        onRemoveFromPlaylist?.call(track);
      }
    });
  }

  Future<bool?> _showRemoveConfirmationDialog(
    BuildContext context,
    Track track,
  ) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    return showGeneralDialog<bool?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        final surfaceTint = isDark
            ? const Color(0xFF1A1A20).withOpacity(0.52)
            : Colors.white.withOpacity(0.74);
        final overlayTint = isDark
            ? const Color(0xFF0B0B11).withOpacity(0.4)
            : const Color(0xFFEAF1FF).withOpacity(0.54);
        final borderColor = isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.08);
        final textColorPrimary = isDark
            ? Colors.white.withOpacity(0.92)
            : Colors.black.withOpacity(0.9);
        final textColorSecondary = isDark
            ? Colors.white.withOpacity(0.68)
            : Colors.black.withOpacity(0.62);

        final content = ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              width: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [surfaceTint, overlayTint],
                ),
                border: Border.all(color: borderColor, width: 0.65),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.35)
                        : Colors.black.withOpacity(0.12),
                    blurRadius: 26,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.08),
                    ),
                    child: Icon(
                      CupertinoIcons.minus_circle,
                      size: 24,
                      color: isDark
                          ? Colors.redAccent.shade200
                          : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '从歌单移除歌曲？',
                    locale: Locale("zh-Hans", "zh"),
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColorPrimary,
                        ) ??
                        TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColorPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '“${track.title}” 将从当前歌单移除，但文件和其它歌单不会受到影响。',
                    textAlign: TextAlign.center,
                    locale: Locale("zh-Hans", "zh"),
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                          color: textColorSecondary,
                          fontSize: 13,
                        ) ??
                        TextStyle(color: textColorSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _GlassDialogButton(
                        label: '取消',
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 12),
                      _GlassDialogButton(
                        label: '移除',
                        destructive: true,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}

  bool _isNetworkSong(Track track) => track.isNeteaseTrack;

class _GlassDialogButton extends StatefulWidget {
  const _GlassDialogButton({
    required this.label,
    this.destructive = false,
    required this.onTap,
  });

  final String label;
  final bool destructive;
  final VoidCallback onTap;

  @override
  State<_GlassDialogButton> createState() => _GlassDialogButtonState();
}

class _GlassDialogButtonState extends State<_GlassDialogButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final isDark =
        (macTheme?.brightness ?? theme.brightness) == Brightness.dark;

    final baseColor = widget.destructive
        ? (isDark ? Colors.redAccent.shade200 : Colors.redAccent)
        : (isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.black.withOpacity(0.08));
    final hoverColor = widget.destructive
        ? (isDark ? Colors.redAccent.shade100 : Colors.redAccent.shade400)
        : (isDark
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.12));
    final textColor = widget.destructive
        ? Colors.white
        : (isDark
              ? Colors.white.withOpacity(0.92)
              : Colors.black.withOpacity(0.82));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering ? hoverColor : baseColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.label,
            locale: Locale("zh-Hans", "zh"),
            style:
                theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ) ??
                TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
