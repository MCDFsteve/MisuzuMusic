part of 'package:misuzu_music/presentation/pages/home_page.dart';

enum PlaylistCreationMode {
  local,
  cloud,
}

Future<PlaylistCreationMode?> showPlaylistCreationModeDialog(
  BuildContext context,
) {
  return showPlaylistModalDialog<PlaylistCreationMode>(
    context: context,
    builder: (dialogContext) {
      return _PlaylistModalScaffold(
        title: '选择新建方式',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlaylistCreationModeOption(
              icon: CupertinoIcons.add_circled_solid,
              title: '本地新建歌单',
              description: '使用本地存储，立即编辑歌单名称和内容。',
              onTap: () => Navigator.of(dialogContext).pop(PlaylistCreationMode.local),
            ),
            const SizedBox(height: 12),
            _PlaylistCreationModeOption(
              icon: CupertinoIcons.cloud_download,
              title: '拉取云歌单',
              description: '根据云端 ID 下载现有歌单并导入本地。',
              onTap: () => Navigator.of(dialogContext).pop(PlaylistCreationMode.cloud),
            ),
          ],
        ),
        actions: [
          _SheetActionButton.secondary(
            label: '取消',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
        maxWidth: 360,
        contentSpacing: 18,
        actionsSpacing: 16,
      );
    },
  );
}

Future<String?> showCloudPlaylistIdDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String invalidMessage,
  String? description,
  required bool Function(String id) validator,
}) {
  final controller = TextEditingController();
  String? errorText;
  return showPlaylistModalDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final macTheme = MacosTheme.maybeOf(context);
          final isDark = macTheme?.brightness == Brightness.dark ||
              Theme.of(context).brightness == Brightness.dark;

          final descriptionStyle = Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: isDark
                    ? Colors.white.withOpacity(0.72)
                    : Colors.black.withOpacity(0.68),
              ) ??
              TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.72)
                    : Colors.black.withOpacity(0.68),
                fontSize: 13,
              );
          final errorStyle = Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: MacosColors.systemRedColor) ??
              TextStyle(color: MacosColors.systemRedColor, fontSize: 12);

          void submit() {
            final value = controller.text.trim();
            if (!validator(value)) {
              setState(() => errorText = invalidMessage);
              return;
            }
            Navigator.of(dialogContext).pop(value);
          }

          return _PlaylistModalScaffold(
            title: title,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (description != null) ...[
                  Text(description!, style: descriptionStyle),
                  const SizedBox(height: 12),
                ],
                _ModalTextField(
                  controller: controller,
                  label: '云端ID',
                  hintText: '至少 5 位，仅限字母/数字/下划线',
                  enabled: true,
                  onChanged: (_) {
                    if (errorText != null) {
                      setState(() => errorText = null);
                    }
                  },
                  onSubmitted: (_) => submit(),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: errorStyle),
                ],
              ],
            ),
            actions: [
              _SheetActionButton.secondary(
                label: '取消',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              _SheetActionButton.primary(
                label: confirmLabel,
                onPressed: submit,
              ),
            ],
            maxWidth: 360,
            contentSpacing: 18,
            actionsSpacing: 16,
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}

Future<String?> showPlaylistCreationSheet(
  BuildContext context, {
  Track? track,
}) async {
  final playlistsCubit = context.read<PlaylistsCubit>();
  final result = await showPlaylistModalDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => BlocProvider.value(
      value: playlistsCubit,
      child: _PlaylistCreationDialog(initialTrack: track),
    ),
  );
  if (result != null) {
    await playlistsCubit.ensurePlaylistTracks(result, force: true);
  }
  return result;
}

Future<String?> showPlaylistEditDialog(
  BuildContext context, {
  required Playlist playlist,
}) async {
  final playlistsCubit = context.read<PlaylistsCubit>();
  await playlistsCubit.ensurePlaylistTracks(playlist.id, force: false);
  final tracks = playlistsCubit.state.playlistTracks[playlist.id];

  String? fallbackCoverPath;
  if ((playlist.coverPath == null || playlist.coverPath!.trim().isEmpty) &&
      tracks != null &&
      tracks.isNotEmpty) {
    final Map<String, Track> trackByHash = {
      for (final track in tracks) (track.contentHash ?? track.id): track,
    };

    for (final trackHash in playlist.trackIds.reversed) {
      final track = trackByHash[trackHash];
      if (track == null) {
        continue;
      }
      final artworkPath = track.artworkPath;
      if (artworkPath != null && artworkPath.trim().isNotEmpty) {
        fallbackCoverPath = artworkPath;
        break;
      }
    }

    if (fallbackCoverPath == null) {
      for (final track in tracks.reversed) {
        final artworkPath = track.artworkPath;
        if (artworkPath != null && artworkPath.trim().isNotEmpty) {
          fallbackCoverPath = artworkPath;
          break;
        }
      }
    }

    if (fallbackCoverPath != null && fallbackCoverPath.trim().isEmpty) {
      fallbackCoverPath = null;
    }
  }

  final result = await showPlaylistModalDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => BlocProvider.value(
      value: playlistsCubit,
      child: _PlaylistCreationDialog(
        initialPlaylist: playlist,
        fallbackCoverPath: fallbackCoverPath,
      ),
    ),
  );
  if (result != null &&
      result != _PlaylistCreationDialog.deleteSignal &&
      result == playlist.id) {
    await playlistsCubit.ensurePlaylistTracks(playlist.id, force: true);
  }
  return result;
}

class _PlaylistCreationDialog extends StatefulWidget {
  const _PlaylistCreationDialog({
    this.initialTrack,
    this.initialPlaylist,
    this.fallbackCoverPath,
  });

  static const String deleteSignal = '__delete_playlist__';

  final Track? initialTrack;
  final Playlist? initialPlaylist;
  final String? fallbackCoverPath;

  bool get isEditing => initialPlaylist != null;

  @override
  State<_PlaylistCreationDialog> createState() =>
      _PlaylistCreationDialogState();
}

class _PlaylistCreationModeOption extends StatelessWidget {
  const _PlaylistCreationModeOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.maybeOf(context);
    final isDark = macTheme?.brightness == Brightness.dark ||
        Theme.of(context).brightness == Brightness.dark;

    final background = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    final hoverBackground = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.08);
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withOpacity(0.92)
              : Colors.black.withOpacity(0.9),
        ) ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withOpacity(0.92)
              : Colors.black.withOpacity(0.9),
        );
    final descriptionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isDark
              ? Colors.white.withOpacity(0.66)
              : Colors.black.withOpacity(0.62),
        ) ??
        TextStyle(
          fontSize: 12,
          color: isDark
              ? Colors.white.withOpacity(0.66)
              : Colors.black.withOpacity(0.62),
        );

    return _HoverableCard(
      baseColor: background,
      hoverColor: hoverBackground,
      borderColor: isDark
          ? Colors.white.withOpacity(0.14)
          : Colors.black.withOpacity(0.08),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isDark
                  ? Colors.white.withOpacity(0.86)
                  : Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: descriptionStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: isDark
                ? Colors.white.withOpacity(0.42)
                : Colors.black.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _ModalTextField extends StatelessWidget {
  const _ModalTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final isDark = macTheme?.brightness == Brightness.dark ||
        theme.brightness == Brightness.dark;

    final labelColor = isDark
        ? Colors.white.withOpacity(0.86)
        : Colors.black.withOpacity(0.78);
    final hintColor = isDark
        ? Colors.white.withOpacity(0.42)
        : Colors.black.withOpacity(0.45);
    final fillColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.74);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ) ??
              TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor, fontSize: 13),
            filled: true,
            fillColor: fillColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: macTheme?.primaryColor ?? theme.colorScheme.primary,
                width: 1.1,
              ),
            ),
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}

class _HoverableCard extends StatefulWidget {
  const _HoverableCard({
    required this.child,
    required this.baseColor,
    required this.hoverColor,
    required this.borderColor,
    required this.onTap,
  });

  final Widget child;
  final Color baseColor;
  final Color hoverColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> {
  bool _hovering = false;
  bool _pressing = false;

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
    final showHover = _hovering || _pressing;
    final background = showHover ? widget.hoverColor : widget.baseColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: GestureDetector(
        onTapDown: (_) => _setPressing(true),
        onTapCancel: () => _setPressing(false),
        onTapUp: (_) => _setPressing(false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.borderColor, width: 0.8),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PlaylistCreationDialogState extends State<_PlaylistCreationDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _coverPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    final playlist = widget.initialPlaylist;
    if (playlist != null) {
      _nameController.text = playlist.name;
      _descriptionController.text = playlist.description ?? '';
      if (widget.fallbackCoverPath != null &&
          widget.fallbackCoverPath!.trim().isNotEmpty) {
        _coverPath = widget.fallbackCoverPath;
      } else if (playlist.coverPath?.trim().isNotEmpty == true) {
        _coverPath = playlist.coverPath;
      }
    } else {
      final track = widget.initialTrack;
      if (track != null) {
        _nameController.text = '${track.artist} - ${track.album}';
      }
      _coverPath ??= widget.fallbackCoverPath;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _coverPath = result.files.first.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsCubit = context.watch<PlaylistsCubit>();
    final state = playlistsCubit.state;
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;
    final isEditing = widget.isEditing;
    final dialogTitle = isEditing ? '编辑歌单' : '新建歌单';
    final playlist = widget.initialPlaylist;
    final isAutoGeneratedCover =
        playlist != null &&
        widget.fallbackCoverPath != null &&
        widget.fallbackCoverPath == _coverPath &&
        _isUsingFallbackCover(playlist);

    final labelColor = isDark
        ? Colors.white.withOpacity(0.86)
        : Colors.black.withOpacity(0.78);
    final secondaryColor = isDark
        ? Colors.white.withOpacity(0.62)
        : Colors.black.withOpacity(0.6);
    final fieldTextColor = isDark
        ? Colors.white.withOpacity(0.92)
        : Colors.black.withOpacity(0.88);
    final hintColor = isDark
        ? Colors.white.withOpacity(0.42)
        : Colors.black.withOpacity(0.45);
    final fieldFillColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.72);
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.12);

    return _PlaylistModalScaffold(
      title: dialogTitle,
      maxWidth: 340,
      contentSpacing: 14,
      actionsSpacing: 16,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogCoverPreview(coverPath: _coverPath, size: 80),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '封面',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SheetActionButton.secondary(
                      label: '选择图片',
                      onPressed: state.isProcessing ? null : _pickCover,
                    ),
                    if (_coverPath != null && !isAutoGeneratedCover) ...[
                      const SizedBox(height: 6),
                      Text(
                        _coverPath!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: secondaryColor,
                            ) ??
                            TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LabeledTextField(
            label: '歌单名称',
            controller: _nameController,
            hintText: '请输入歌单名称',
            enabled: !state.isProcessing,
            labelColor: labelColor,
            textColor: fieldTextColor,
            hintColor: hintColor,
            fillColor: fieldFillColor,
            borderColor: dividerColor,
            isDarkOverride: isDark,
          ),
          const SizedBox(height: 12),
          _LabeledTextField(
            label: '简介',
            controller: _descriptionController,
            hintText: '介绍一下这个歌单吧',
            maxLines: 3,
            enabled: !state.isProcessing,
            labelColor: labelColor,
            textColor: fieldTextColor,
            hintColor: hintColor,
            fillColor: fieldFillColor,
            borderColor: dividerColor,
            isDarkOverride: isDark,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        _SheetActionButton.secondary(
          label: '取消',
          onPressed: state.isProcessing
              ? null
              : () => Navigator.of(context).pop(),
        ),
        if (isEditing)
          _SheetActionButton.secondary(
            label: '删除歌单',
            onPressed: state.isProcessing
                ? null
                : () => _handleDelete(playlistsCubit),
          ),
        _SheetActionButton.primary(
          label: '保存',
          onPressed: state.isProcessing
              ? null
              : () => _handleSubmit(playlistsCubit),
          isBusy: state.isProcessing,
        ),
      ],
    );
  }

  Future<void> _handleSubmit(PlaylistsCubit playlistsCubit) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = '歌单名称不能为空';
      });
      return;
    }

    setState(() {
      _error = null;
    });

    if (widget.isEditing) {
      final playlist = widget.initialPlaylist!;
      final success = await playlistsCubit.updatePlaylist(
        playlistId: playlist.id,
        name: name,
        description: _descriptionController.text.trim(),
        coverPath: _coverPath,
      );
      if (!mounted) return;
      if (!success) {
        setState(() {
          _error = playlistsCubit.state.errorMessage ?? '保存失败';
        });
        return;
      }
      Navigator.of(context).pop(playlist.id);
      return;
    }

    final newId = await playlistsCubit.createPlaylist(
      name: name,
      description: _descriptionController.text.trim(),
      coverPath: _coverPath,
    );
    if (!mounted) return;
    if (newId == null) {
      setState(() {
        _error = playlistsCubit.state.errorMessage ?? '创建歌单失败';
      });
      return;
    }
    if (widget.initialTrack != null) {
      await playlistsCubit.addTrackToPlaylist(newId, widget.initialTrack!);
    }
    if (mounted) {
      Navigator.of(context).pop(newId);
    }
  }

  Future<void> _handleDelete(PlaylistsCubit playlistsCubit) async {
    final playlist = widget.initialPlaylist;
    if (playlist == null) {
      return;
    }
    if (playlistsCubit.state.isProcessing) {
      return;
    }

    final confirmed = await _confirmDeleteDialog(context, playlist.name);
    if (confirmed != true) {
      return;
    }

    final success = await playlistsCubit.deletePlaylist(playlist.id);
    if (!mounted) return;
    if (!success) {
      setState(() {
        _error = playlistsCubit.state.errorMessage ?? '删除歌单失败';
      });
      return;
    }
    Navigator.of(context).pop(_PlaylistCreationDialog.deleteSignal);
  }

  Future<bool?> _confirmDeleteDialog(
    BuildContext context,
    String playlistName,
  ) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.trash,
            color: isDark
                ? Colors.redAccent.shade100
                : Colors.redAccent.shade200,
            size: 26,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '确定删除 “$playlistName” 吗？',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withOpacity(0.92)
                    : Colors.black.withOpacity(0.88),
              ) ??
              TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withOpacity(0.92)
                    : Colors.black.withOpacity(0.88),
                fontSize: 16,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '该歌单将被永久移除，包含的歌曲不会删除。',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? Colors.white.withOpacity(0.68)
                    : Colors.black.withOpacity(0.62),
              ) ??
              TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.68)
                    : Colors.black.withOpacity(0.62),
                fontSize: 13,
              ),
        ),
      ],
    );

    final actions = [
      _SheetActionButton.secondary(
        label: '取消',
        onPressed: () => Navigator.of(context).pop(false),
      ),
      _SheetActionButton.primary(
        label: '删除',
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ];

    return showPlaylistModalDialog<bool?>(
      context: context,
      builder: (_) => _PlaylistModalScaffold(
        title: '删除歌单',
        body: body,
        actions: actions,
        maxWidth: 320,
        contentSpacing: 20,
        actionsSpacing: 18,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      ),
    );
  }
}

bool _isUsingFallbackCover(Playlist? playlist) {
  if (playlist == null) {
    return false;
  }
  return playlist.coverPath == null || playlist.coverPath!.trim().isEmpty;
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.enabled = true,
    this.labelColor,
    this.textColor,
    this.hintColor,
    this.fillColor,
    this.borderColor,
    this.isDarkOverride,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final bool enabled;
  final Color? labelColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? fillColor;
  final Color? borderColor;
  final bool? isDarkOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = isDarkOverride ?? theme.brightness == Brightness.dark;

    final resolvedBorderColor =
        borderColor ??
        theme.colorScheme.outline.withOpacity(isDark ? 0.24 : 0.18);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: resolvedBorderColor, width: 0.8),
    );

    final resolvedLabelColor =
        labelColor ??
        (isDark
            ? Colors.white.withOpacity(0.86)
            : Colors.black.withOpacity(0.78));
    final resolvedTextColor =
        textColor ??
        (isDark
            ? Colors.white.withOpacity(0.92)
            : Colors.black.withOpacity(0.88));
    final resolvedHintColor =
        hintColor ??
        (isDark
            ? Colors.white.withOpacity(0.42)
            : Colors.black.withOpacity(0.45));
    final resolvedFillColor =
        fillColor ??
        (isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: resolvedLabelColor,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
                theme.textTheme.bodySmall?.copyWith(
                  color: resolvedHintColor,
                  fontSize: 12,
                ) ??
                TextStyle(fontSize: 12, color: resolvedHintColor),
            filled: true,
            fillColor: resolvedFillColor,
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withOpacity(
                  isDark ? 0.52 : 0.45,
                ),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style:
              theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12.5,
                color: resolvedTextColor,
              ) ??
              TextStyle(fontSize: 12.5, color: resolvedTextColor),
        ),
      ],
    );
  }
}

class _DialogCoverPreview extends StatelessWidget {
  const _DialogCoverPreview({required this.coverPath, this.size = 120});

  final String? coverPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.08);

    final borderRadius = BorderRadius.circular(12);

    Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.6),
        border: Border.all(color: borderColor, width: 0.7),
      ),
      child: Icon(
        CupertinoIcons.square_stack_3d_up,
        size: size * 0.28,
        color: isDark
            ? Colors.white.withOpacity(0.6)
            : Colors.black.withOpacity(0.45),
      ),
    );

    if (coverPath == null || coverPath!.isEmpty) {
      return placeholder;
    }

    try {
      final file = File(coverPath!);
      if (!file.existsSync()) {
        return placeholder;
      }
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
      );
    } catch (_) {
      return placeholder;
    }
  }
}
