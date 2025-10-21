part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _PlaylistSelectionSheet extends StatefulWidget {
  const _PlaylistSelectionSheet({required this.track});

  final Track track;

  static const String createSignal = '__create_playlist__';

  @override
  State<_PlaylistSelectionSheet> createState() =>
      _PlaylistSelectionSheetState();
}

class _PlaylistSelectionSheetState extends State<_PlaylistSelectionSheet> {
  String? _selectedPlaylistId;
  String? _localError;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PlaylistsCubit>();
    final state = cubit.state;
    final playlists = state.playlists;
    final theme = MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_selectedPlaylistId != null &&
        playlists.every((element) => element.id != _selectedPlaylistId)) {
      _selectedPlaylistId = playlists.isNotEmpty ? playlists.first.id : null;
    }

    return MacosSheet(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '添加到歌单',
                style: MacosTheme.of(context).typography.title3.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.12,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 10),
              if (playlists.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '当前没有歌单，可立即创建一个新的歌单。',
                      style: MacosTheme.of(
                        context,
                      ).typography.body.copyWith(fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _SheetActionButton.secondary(
                          label: '取消',
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 10),
                        _SheetActionButton.primary(
                          label: '新建歌单',
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pop(_PlaylistSelectionSheet.createSignal),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 160,
                      child: MacosScrollbar(
                        controller: _scrollController,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: playlists.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            final bool active =
                                playlist.id == _selectedPlaylistId;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPlaylistId = playlist.id;
                                  _localError = null;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? theme.primaryColor.withOpacity(
                                          isDark ? 0.24 : 0.16,
                                        )
                                      : (isDark
                                            ? Colors.white.withOpacity(0.03)
                                            : Colors.black.withOpacity(0.03)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: active
                                        ? theme.primaryColor.withOpacity(
                                            isDark ? 0.48 : 0.32,
                                          )
                                        : (isDark
                                              ? Colors.white.withOpacity(0.06)
                                              : Colors.black.withOpacity(0.06)),
                                    width: 0.8,
                                  ),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                            color: theme.primaryColor
                                                .withOpacity(
                                                  isDark ? 0.2 : 0.16,
                                                ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: _PlaylistCoverPreview(
                                        coverPath: playlist.coverPath,
                                        size: 36,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playlist.name,
                                            style: theme.typography.body
                                                .copyWith(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black
                                                            .withOpacity(0.85),
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${playlist.trackIds.length} 首歌曲',
                                            style: theme.typography.caption1
                                                .copyWith(
                                                  fontSize: 10,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : MacosColors
                                                            .secondaryLabelColor,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    MacosRadioButton<String>(
                                      value: playlist.id,
                                      groupValue: _selectedPlaylistId,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedPlaylistId = value;
                                          _localError = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _localError!,
                        style: MacosTheme.of(context).typography.caption1
                            .copyWith(color: MacosColors.systemRedColor),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _SheetActionButton.secondary(
                          label: '取消',
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 10),
                        _SheetActionButton.secondary(
                          label: '新建歌单',
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pop(_PlaylistSelectionSheet.createSignal),
                        ),
                        const SizedBox(width: 10),
                        _SheetActionButton.primary(
                          label: '添加',
                          onPressed:
                              state.isProcessing || _selectedPlaylistId == null
                              ? null
                              : () async {
                                  final playlistId = _selectedPlaylistId;
                                  if (playlistId == null) {
                                    return;
                                  }
                                  final added = await context
                                      .read<PlaylistsCubit>()
                                      .addTrackToPlaylist(
                                        playlistId,
                                        widget.track,
                                      );
                                  if (!added) {
                                    setState(() {
                                      _localError = '歌曲已在该歌单中';
                                    });
                                    return;
                                  }
                                  if (mounted) {
                                    Navigator.of(context).pop(playlistId);
                                  }
                                },
                          isBusy: state.isProcessing,
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SheetActionVariant { primary, secondary }

class _SheetActionButton extends StatefulWidget {
  const _SheetActionButton._({
    required this.label,
    required this.onPressed,
    required this.variant,
    this.isBusy = false,
  });

  factory _SheetActionButton.primary({
    required String label,
    required VoidCallback? onPressed,
    bool isBusy = false,
  }) {
    return _SheetActionButton._(
      label: label,
      onPressed: onPressed,
      variant: _SheetActionVariant.primary,
      isBusy: isBusy,
    );
  }

  factory _SheetActionButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    bool isBusy = false,
  }) {
    return _SheetActionButton._(
      label: label,
      onPressed: onPressed,
      variant: _SheetActionVariant.secondary,
      isBusy: isBusy,
    );
  }

  final String label;
  final VoidCallback? onPressed;
  final _SheetActionVariant variant;
  final bool isBusy;

  @override
  State<_SheetActionButton> createState() => _SheetActionButtonState();
}

class _SheetActionButtonState extends State<_SheetActionButton> {
  bool _hovering = false;
  bool _pressing = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isBusy;

  void _setHovering(bool value) {
    if (_hovering == value) {
      return;
    }
    setState(() {
      _hovering = value;
      if (!value) {
        _pressing = false;
      }
    });
  }

  void _setPressing(bool value) {
    if (_pressing == value) {
      return;
    }
    setState(() {
      _pressing = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final isPrimary = widget.variant == _SheetActionVariant.primary;
    final enabled = _isEnabled;

    final baseBackground = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.88 : 0.84)
        : (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04));
    final hoverBackground = isPrimary
        ? macTheme.primaryColor
        : (isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08));
    final pressBackground = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.84 : 0.9)
        : (isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.black.withOpacity(0.12));
    final disabledBackground = isPrimary
        ? macTheme.primaryColor.withOpacity(0.28)
        : (isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03));

    final baseBorder = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.55 : 0.42)
        : (isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.black.withOpacity(0.1));
    final hoverBorder = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.75 : 0.58)
        : (isDark
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.16));
    final pressBorder = isPrimary
        ? macTheme.primaryColor.withOpacity(isDark ? 0.68 : 0.5)
        : (isDark
              ? Colors.white.withOpacity(0.24)
              : Colors.black.withOpacity(0.2));
    final disabledBorder = isPrimary
        ? macTheme.primaryColor.withOpacity(0.18)
        : Colors.transparent;

    final baseTextColor = isPrimary
        ? Colors.white
        : (isDark
              ? Colors.white.withOpacity(0.82)
              : Colors.black.withOpacity(0.75));
    final disabledTextColor = isPrimary
        ? Colors.white.withOpacity(0.6)
        : (isDark
              ? Colors.white.withOpacity(0.36)
              : Colors.black.withOpacity(0.36));

    final backgroundColor = !enabled
        ? disabledBackground
        : _pressing
        ? pressBackground
        : (_hovering ? hoverBackground : baseBackground);
    final borderColor = !enabled
        ? disabledBorder
        : _pressing
        ? pressBorder
        : (_hovering ? hoverBorder : baseBorder);
    final textColor = !enabled ? disabledTextColor : baseTextColor;

    final boxShadow = isPrimary && enabled && (_hovering || _pressing)
        ? [
            BoxShadow(
              color: macTheme.primaryColor.withOpacity(
                _pressing ? (isDark ? 0.45 : 0.28) : (isDark ? 0.36 : 0.24),
              ),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

    Widget child;
    if (widget.isBusy) {
      child = const SizedBox(
        key: ValueKey('busy'),
        width: 14,
        height: 14,
        child: ProgressCircle(radius: 5),
      );
    } else {
      child = Text(
        widget.label,
        key: ValueKey(widget.label),
        style: macTheme.typography.body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
          letterSpacing: -0.1,
        ),
      );
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) {
          _setHovering(true);
        }
      },
      onExit: (_) => _setHovering(false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressing(true) : null,
        onTapCancel: enabled ? () => _setPressing(false) : null,
        onTapUp: enabled ? (_) => _setPressing(false) : null,
        onTap: enabled ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          constraints: const BoxConstraints(minHeight: 30, minWidth: 74),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.9),
            boxShadow: boxShadow,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
