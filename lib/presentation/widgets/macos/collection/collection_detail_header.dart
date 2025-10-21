import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class CollectionDetailHeader extends StatelessWidget {
  const CollectionDetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.secondaryText,
    this.artworkPath,
    this.fallbackIcon = CupertinoIcons.square_stack_3d_up,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final String? secondaryText;
  final String? artworkPath;
  final IconData fallbackIcon;
  final List<Widget> actions;

  bool get _hasArtwork =>
      artworkPath != null && artworkPath!.trim().isNotEmpty && !kIsWeb;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.maybeOf(context);
    final isDark = macTheme != null
        ? macTheme.brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;

    final titleStyle =
        macTheme?.typography.title2.copyWith(fontWeight: FontWeight.w700) ??
        Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);

    final subtitleStyle =
        macTheme?.typography.headline.copyWith(
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.black54,
        ) ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.white70 : Colors.black54,
        );

    final artwork = _buildArtwork(isDark);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        artwork,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: titleStyle),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(subtitle!.trim(), style: subtitleStyle),
              ],
              if (secondaryText != null &&
                  secondaryText!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  secondaryText!,
                  style: subtitleStyle?.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[const SizedBox(width: 16), ...actions],
      ],
    );
  }

  Widget _buildArtwork(bool isDark) {
    const double size = 120;
    if (_hasArtwork) {
      final file = File(artworkPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
        );
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C2C2E)
            : MacosColors.controlBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Icon(
        fallbackIcon,
        size: 40,
        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
      ),
    );
  }
}
