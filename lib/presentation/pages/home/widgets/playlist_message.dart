part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _PlaylistMessage extends StatelessWidget {
  const _PlaylistMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final color = isDark ? Colors.white : MacosColors.labelColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MacosIcon(icon, size: 64, color: color.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text(
            message,
            locale: Locale("zh-Hans", "zh"),
            style: macTheme.typography.title1.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
