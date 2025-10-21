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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(320.0, 520.0);
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _DialogCoverPreview(coverPath: _coverPath),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('封面', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: state.isProcessing
                                    ? null
                                    : _pickCover,
                                child: const Text('选择图片'),
                              ),
                              if (_coverPath != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _coverPath!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _LabeledTextField(
                      label: '歌单名称',
                      controller: _nameController,
                      hintText: '请输入歌单名称',
                      enabled: !state.isProcessing,
                    ),
                    const SizedBox(height: 16),
                    _LabeledTextField(
                      label: '简介',
                      controller: _descriptionController,
                      hintText: '介绍一下这个歌单吧',
                      maxLines: 4,
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: state.isProcessing
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
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
                          child: state.isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('保存'),
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
        ? const Color(0xFF1C1C1E).withOpacity(0.35)
        : Colors.white.withOpacity(0.58);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 0.7),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.4) : Colors.black12,
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            child: child,
          ),
        ),
      ),
    );

    return HoverGlowOverlay(
      isDarkMode: isDark,
      borderRadius: BorderRadius.circular(18),
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

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: theme.colorScheme.outline.withOpacity(0.25),
        width: 1,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.66),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.45),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogCoverPreview extends StatelessWidget {
  const _DialogCoverPreview({required this.coverPath});

  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.08);

    Widget placeholder = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.6),
        border: Border.all(color: borderColor, width: 0.7),
      ),
      child: Icon(
        CupertinoIcons.square_stack_3d_up,
        size: 26,
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
        borderRadius: BorderRadius.circular(16),
        child: Image.file(file, width: 120, height: 120, fit: BoxFit.cover),
      );
    } catch (_) {
      return placeholder;
    }
  }
}
