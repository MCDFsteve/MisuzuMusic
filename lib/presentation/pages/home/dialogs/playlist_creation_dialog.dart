part of 'package:misuzu_music/presentation/pages/home_page.dart';

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
  final result = await showPlaylistModalDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => BlocProvider.value(
      value: playlistsCubit,
      child: _PlaylistCreationDialog(initialPlaylist: playlist),
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
  const _PlaylistCreationDialog({this.initialTrack, this.initialPlaylist});

  static const String deleteSignal = '__delete_playlist__';

  final Track? initialTrack;
  final Playlist? initialPlaylist;

  bool get isEditing => initialPlaylist != null;

  @override
  State<_PlaylistCreationDialog> createState() =>
      _PlaylistCreationDialogState();
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
      _coverPath = playlist.coverPath;
    } else {
      final track = widget.initialTrack;
      if (track != null) {
        _nameController.text = '${track.artist} - ${track.album}';
      }
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
    final isEditing = widget.isEditing;
    final dialogTitle = isEditing ? '编辑歌单' : '新建歌单';

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
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SheetActionButton.secondary(
                      label: '选择图片',
                      onPressed: state.isProcessing ? null : _pickCover,
                    ),
                    if (_coverPath != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _coverPath!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.62),
                        ),
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
          ),
          const SizedBox(height: 12),
          _LabeledTextField(
            label: '简介',
            controller: _descriptionController,
            hintText: '介绍一下这个歌单吧',
            maxLines: 3,
            enabled: !state.isProcessing,
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
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = theme.colorScheme.outline.withOpacity(0.2);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor, width: 0.8),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.62),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.4),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
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
