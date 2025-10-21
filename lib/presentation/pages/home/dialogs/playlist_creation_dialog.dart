part of 'package:misuzu_music/presentation/pages/home_page.dart';

Future<String?> showPlaylistCreationSheet(
  BuildContext context, {
  Track? track,
}) async {
  final playlistsCubit = context.read<PlaylistsCubit>();
  final result = await showDialog<String?>(
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

class _PlaylistCreationDialog extends StatefulWidget {
  const _PlaylistCreationDialog({this.initialTrack});

  final Track? initialTrack;

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
    final track = widget.initialTrack;
    if (track != null) {
      _nameController.text = '${track.artist} - ${track.album}';
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
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(240.0, 340.0);
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: _FrostedDialogSurface(
                isDark: isDark,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '新建歌单',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                                onPressed: state.isProcessing
                                    ? null
                                    : _pickCover,
                              ),
                              if (_coverPath != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _coverPath!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.62),
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
                          label: '保存',
                          onPressed: state.isProcessing
                              ? null
                              : () async {
                                  final name = _nameController.text.trim();
                                  if (name.isEmpty) {
                                    setState(() {
                                      _error = '歌单名称不能为空';
                                    });
                                    return;
                                  }
                                  final playlistsCubit = context
                                      .read<PlaylistsCubit>();
                                  final newId = await playlistsCubit
                                      .createPlaylist(
                                        name: name,
                                        description: _descriptionController.text
                                            .trim(),
                                        coverPath: _coverPath,
                                      );
                                  if (!mounted) return;
                                  if (newId == null) {
                                    setState(() {
                                      _error =
                                          playlistsCubit.state.errorMessage ??
                                          '创建歌单失败';
                                    });
                                    return;
                                  }
                                  if (widget.initialTrack != null) {
                                    await playlistsCubit.addTrackToPlaylist(
                                      newId,
                                      widget.initialTrack!,
                                    );
                                  }
                                  if (mounted) {
                                    Navigator.of(context).pop(newId);
                                  }
                                },
                          isBusy: state.isProcessing,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FrostedDialogSurface extends StatelessWidget {
  const _FrostedDialogSurface({required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? const Color(0xFF1C1C1E).withOpacity(0.33)
        : Colors.white.withOpacity(0.5);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.07);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.6),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: child,
          ),
        ),
      ),
    );

    return HoverGlowOverlay(
      isDarkMode: isDark,
      borderRadius: BorderRadius.circular(14),
      blurSigma: 0,
      child: card,
    );
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
