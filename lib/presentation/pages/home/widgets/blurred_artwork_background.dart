part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _BlurredArtworkBackground extends StatelessWidget {
  const _BlurredArtworkBackground({
    super.key,
    required this.artworkPath,
    required this.isDarkMode,
  });

  final String artworkPath;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final file = File(artworkPath);
    if (!file.existsSync()) {
      return Container(color: MacosTheme.of(context).canvasColor);
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
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                isDarkMode
                    ? Colors.black.withOpacity(0.22)
                    : Colors.white.withOpacity(0.28),
                isDarkMode ? BlendMode.darken : BlendMode.screen,
              ),
              child: Image.file(file, fit: BoxFit.cover),
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
}
