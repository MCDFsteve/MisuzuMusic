part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _MacOSGlassHeader extends StatelessWidget {
  const _MacOSGlassHeader({
    required this.height,
    required this.sectionLabel,
    required this.statsLabel,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSelectMusicFolder,
    required this.onCreatePlaylist,
    this.showBackButton = false,
    this.canNavigateBack = false,
    this.onNavigateBack,
    this.backTooltip = '返回上一层',
  });

  final double height;
  final String sectionLabel;
  final String? statsLabel;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectMusicFolder;
  final VoidCallback onCreatePlaylist;
  final bool showBackButton;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;
  final String backTooltip;

  Future<void> _handleDoubleTap() async {
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return;
    }

    final bool isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : MacosColors.labelColor;

    final frostedColor = theme.canvasColor.withOpacity(
      isDarkMode ? 0.35 : 0.36,
    );

    final headerContent = ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: frostedColor,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.45),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Misuzu Music',
                      style: theme.typography.title2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sectionLabel,
                      style: theme.typography.caption1.copyWith(
                        color: textColor.withOpacity(0.68),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (statsLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      statsLabel!,
                      style: theme.typography.caption1.copyWith(
                        color: textColor.withOpacity(0.68),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 320,
                  ),
                  child: LibrarySearchField(
                    query: searchQuery,
                    onQueryChanged: onSearchChanged,
                  ),
                ),
              ),
              if (showBackButton)
                MacosTooltip(
                  message: backTooltip,
                  child: _HeaderIconButton(
                    baseColor: canNavigateBack
                        ? textColor.withOpacity(0.72)
                        : textColor.withOpacity(0.24),
                    hoverColor: textColor,
                    icon: CupertinoIcons.left_chevron,
                    onPressed: canNavigateBack ? onNavigateBack : null,
                    size: 36,
                    iconSize: 20,
                    enabled: canNavigateBack,
                  ),
                ),
              if (showBackButton) const SizedBox(width: 8),
              MacosTooltip(
                message: '新建歌单',
                child: _HeaderIconButton(
                  baseColor: textColor.withOpacity(0.72),
                  hoverColor: textColor,
                  size: 36,
                  iconSize: 22,
                  icon: CupertinoIcons.add,
                  onPressed: onCreatePlaylist,
                ),
              ),
              const SizedBox(width: 8),
              MacosTooltip(
                message: '选择音乐文件夹',
                child: _HeaderIconButton(
                  baseColor: textColor.withOpacity(0.72),
                  hoverColor: textColor,
                  size: 36,
                  iconSize: 22,
                  icon: CupertinoIcons.folder,
                  onPressed: onSelectMusicFolder,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _handleDoubleTap,
      child: headerContent,
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.baseColor,
    required this.hoverColor,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.iconSize = 22,
    this.enabled = true,
  });

  final Color baseColor;
  final Color hoverColor;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool enabled;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovering = false;
  bool _pressing = false;

  void _updateHovering(bool value) {
    if (_hovering == value || !mounted) return;
    setState(() => _hovering = value);
  }

  void _updatePressing(bool value) {
    if (_pressing == value || !mounted) return;
    setState(() => _pressing = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.enabled && widget.onPressed != null;
    final Color targetColor = !isEnabled
        ? widget.baseColor
        : (_hovering ? widget.hoverColor : widget.baseColor);
    final double scale = !isEnabled
        ? 1.0
        : (_pressing ? 0.95 : (_hovering ? 1.05 : 1.0));

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isEnabled) {
          _updateHovering(true);
        }
      },
      onExit: (_) {
        _updateHovering(false);
        _updatePressing(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled ? (_) => _updatePressing(true) : null,
        onTapUp: isEnabled ? (_) => _updatePressing(false) : null,
        onTapCancel: isEnabled ? () => _updatePressing(false) : null,
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: MacosIcon(
                widget.icon,
                size: widget.iconSize,
                color: targetColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
