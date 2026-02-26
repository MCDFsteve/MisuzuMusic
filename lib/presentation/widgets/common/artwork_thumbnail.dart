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
    this.remoteImageUrl,
  });

  final String? artworkPath;
  final double size;
  final Widget placeholder;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? remoteImageUrl;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 6);
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (size * devicePixelRatio).round();

    if (artworkPath != null && artworkPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(artworkPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(radius),
        ),
      );
    }

    if (remoteImageUrl != null && remoteImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          remoteImageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(radius),
        ),
      );
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
