import 'dart:io';

import 'package:flutter/material.dart';

class ArtworkThumbnail extends StatelessWidget {
  const ArtworkThumbnail({
    super.key,
    required this.artworkPath,
    required this.size,
    required this.placeholder,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
  });

  final String? artworkPath;
  final double size;
  final Widget placeholder;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 6);

    if (artworkPath != null && artworkPath!.isNotEmpty) {
      final file = File(artworkPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: radius,
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholder(radius),
          ),
        );
      }
    }

    return _buildPlaceholder(radius);
  }

  Widget _buildPlaceholder(BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 0.5)
            : null,
      ),
      child: Center(child: placeholder),
    );
  }
}
