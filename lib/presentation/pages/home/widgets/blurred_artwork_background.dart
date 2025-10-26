part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _BlurredArtworkBackground extends StatelessWidget {
  const _BlurredArtworkBackground({
    super.key,
    this.artworkPath,
    this.remoteImageUrl,
    required this.isDarkMode,
  });

  final String? artworkPath;
  final String? remoteImageUrl;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final fallback = _buildFallbackBackground(context);

    final Widget? baseImage = _buildBaseImage();
    if (baseImage == null) {
      return fallback;
    }

    final Color overlayStrong;
    final Color overlayMid;
    final Color overlayWeak;

    if (isDarkMode) {
      overlayStrong = Colors.black.withOpacity(0.6);
      overlayMid = Colors.black.withOpacity(0.38);
      overlayWeak = Colors.black.withOpacity(0.48);
    } else {
      overlayStrong = Colors.white.withOpacity(0.42);
      overlayMid = Colors.white.withOpacity(0.28);
      overlayWeak = Colors.white.withOpacity(0.22);
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 完全不透明的底层背景，防止在Windows上透过模糊层看到其他窗口
          Container(
            color: isDarkMode ? Colors.black : Colors.white,
          ),
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                isDarkMode
                    ? Colors.black.withOpacity(0.22)
                    : Colors.white.withOpacity(0.28),
                isDarkMode ? BlendMode.darken : BlendMode.screen,
              ),
              child: baseImage,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [overlayStrong, overlayMid, overlayWeak],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBaseImage() {
    if (artworkPath != null && artworkPath!.isNotEmpty) {
      final file = File(artworkPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    if (remoteImageUrl != null && remoteImageUrl!.isNotEmpty) {
      return Image.network(
        remoteImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    return null;
  }

  Widget _buildFallbackBackground(BuildContext context) {
    return Container(color: MacosTheme.of(context).canvasColor);
  }
}
