import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

import 'package:misuzu_music/presentation/widgets/common/hover_glow_overlay.dart';

class CollectionSummaryCard extends StatelessWidget {
  const CollectionSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.detailText,
    required this.onTap,
    this.artworkPath,
    this.remoteImageUrl,
    this.hasArtwork = false,
    this.fallbackIcon = CupertinoIcons.folder_solid,
    this.gradientColors,
    this.onRemove,
    this.contextMenuLabel,
    this.cardSize = 220,
    this.onSecondaryTap,
    this.onContextMenuRequested,
  });

  final String title;
  final String subtitle;
  final String detailText;
  final VoidCallback onTap;
  final String? artworkPath;
  final String? remoteImageUrl;
  final bool hasArtwork;
  final IconData fallbackIcon;
  final List<Color>? gradientColors;
  final VoidCallback? onRemove;
  final String? contextMenuLabel;
  final double cardSize;
  final VoidCallback? onSecondaryTap;
  final ValueChanged<Offset>? onContextMenuRequested;

  bool get _canShowArtwork =>
      hasArtwork &&
      artworkPath != null &&
      artworkPath!.trim().isNotEmpty &&
      !kIsWeb;

  bool get _hasRemoteArtwork =>
      remoteImageUrl != null && remoteImageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.maybeOf(context);
    final isDark = macTheme != null
        ? macTheme.brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.72)
        : Colors.black.withOpacity(0.64);

    final Widget artworkWidget = _buildArtworkWidget(isDark);

    final card = HoverGlowOverlay(
      isDarkMode: isDark,
      borderRadius: BorderRadius.circular(20),
      cursor: SystemMouseCursors.click,
      glowRadius: 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.6),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.42)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: artworkWidget,
        ),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onSecondaryTapDown: (details) {
          if (onContextMenuRequested != null) {
            onContextMenuRequested!(details.globalPosition);
            return;
          }
          if (onSecondaryTap != null) {
            onSecondaryTap!();
          } else if (onRemove != null) {
            _showContextMenu(context, details.globalPosition, subtitle);
          }
        },
        onSecondaryTap: onContextMenuRequested != null
            ? null
            : (onSecondaryTap != null
                ? () => onSecondaryTap!()
                : null),
        onLongPressStart: (details) {
          if (onContextMenuRequested != null) {
            onContextMenuRequested!(details.globalPosition);
            return;
          }
          if (onSecondaryTap != null) {
            onSecondaryTap!();
          } else if (onRemove != null) {
            _showContextMenu(context, details.globalPosition, subtitle);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            card,
            const SizedBox(width: 22),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      locale: Locale("zh-Hans", "zh"),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      locale: Locale("zh-Hans", "zh"),
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detailText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      locale: Locale("zh-Hans", "zh"),
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkWidget(bool isDark) {
    if (_canShowArtwork) {
      final file = File(artworkPath!);
      if (file.existsSync()) {
        try {
          if (file.lengthSync() > 12) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildGradientFallback(isDark),
            );
          }
          file.deleteSync();
        } catch (_) {
          try {
            file.deleteSync();
          } catch (_) {}
          // Ignore and fall back
        }
      }
    }

    if (_hasRemoteArtwork) {
      return Image.network(
        remoteImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildGradientFallback(isDark),
      );
    }

    return _buildGradientFallback(isDark);
  }

  Widget _buildGradientFallback(bool isDark) {
    final colors = gradientColors ??
        (isDark
            ? [const Color(0xFF3C3C3E), const Color(0xFF1C1C1E)]
            : [const Color(0xFFE9F1FF), const Color(0xFFFDFEFF)]);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(
        fallbackIcon,
        size: 60,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset position,
    String subtitle,
  ) async {
    if (onRemove == null) {
      return;
    }

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(value: 'remove', child: Text(contextMenuLabel ?? '移除',locale: Locale("zh-Hans", "zh"),)),
      ],
    );
    if (result == 'remove') {
      onRemove?.call();
    }
  }
}
