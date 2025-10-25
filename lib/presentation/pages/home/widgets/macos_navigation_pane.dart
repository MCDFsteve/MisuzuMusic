part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _MacOSNavigationPane extends StatelessWidget {
  const _MacOSNavigationPane({
    required this.width,
    required this.collapsed,
    required this.selectedIndex,
    required this.onSelect,
    required this.onResize,
    this.enabled = true,
  });

  final double width;
  final bool collapsed;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<double> onResize;
  final bool enabled;

  static const _items = <_NavigationItem>[
    _NavigationItem(icon: CupertinoIcons.music_albums_fill, label: '音乐库'),
    _NavigationItem(icon: CupertinoIcons.square_stack_3d_up, label: '歌单'),
    _NavigationItem(icon: CupertinoIcons.music_note_list, label: '播放列表'),
    _NavigationItem(icon: CupertinoIcons.settings, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : MacosColors.labelColor;
    final frostedColor = theme.canvasColor.withOpacity(
      isDarkMode ? 0.35 : 0.32,
    );

    return Stack(
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: frostedColor,
                border: Border(
                  right: BorderSide(
                    color: theme.dividerColor.withOpacity(0.35),
                    width: 0.5,
                  ),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 84, 0, 92),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final bool active = selectedIndex == index;
                  return _NavigationTile(
                    item: item,
                    active: active,
                    collapsed: collapsed,
                    textColor: textColor,
                    enabled: enabled,
                    onTap: () => onSelect(index),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: enabled
                ? (details) => onResize(width + details.delta.dx)
                : null,
            child: MouseRegion(
              cursor: enabled
                  ? SystemMouseCursors.resizeColumn
                  : SystemMouseCursors.basic,
              child: const SizedBox(width: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigationItem {
  const _NavigationItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.textColor,
    required this.onTap,
    this.enabled = true,
  });

  final _NavigationItem item;
  final bool active;
  final bool collapsed;
  final Color textColor;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    const activeBackground = Color(0xFF1b66ff);
    final Color inactiveColor = textColor.withOpacity(0.72);
    final Color iconColor = active ? Colors.white : inactiveColor;
    final Color effectiveIconColor = enabled
        ? iconColor
        : iconColor.withOpacity(0.45);
    final Color labelColor = active
        ? Colors.white
        : textColor.withOpacity(0.82);
    final Color effectiveLabelColor = enabled
        ? labelColor
        : labelColor.withOpacity(0.45);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? activeBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: collapsed
              ? Center(
                  child: MacosIcon(
                    item.icon,
                    size: 18,
                    color: effectiveIconColor,
                  ),
                )
              : Row(
                  children: [
                    MacosIcon(item.icon, size: 18, color: effectiveIconColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        locale: Locale("zh-Hans", "zh"),
                        style: theme.typography.body.copyWith(
                          color: effectiveLabelColor,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
