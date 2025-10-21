part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _PlaylistCreationSheet extends StatefulWidget {
  const _PlaylistCreationSheet({this.initialTrack});

  final Track? initialTrack;

  @override
  State<_PlaylistCreationSheet> createState() => _PlaylistCreationSheetState();
}

class _PlaylistCreationSheetState extends State<_PlaylistCreationSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _coverPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialTrack != null) {
      _nameController.text =
          '${widget.initialTrack!.artist} - ${widget.initialTrack!.album}';
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
    final theme = MacosTheme.of(context);

    return MacosSheet(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '新建歌单',
                style: theme.typography.title3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlaylistCoverPreview(coverPath: _coverPath, size: 120),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('封面'),
                        const SizedBox(height: 6),
                        PushButton(
                          onPressed: state.isProcessing ? null : _pickCover,
                          controlSize: ControlSize.small,
                          child: const Text('选择图片'),
                        ),
                        if (_coverPath != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _coverPath!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption1,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('歌单名称'),
              const SizedBox(height: 6),
              MacosTextField(
                controller: _nameController,
                maxLines: 1,
                placeholder: '请输入歌单名称',
              ),
              const SizedBox(height: 16),
              const Text('简介'),
              const SizedBox(height: 6),
              MacosTextField(
                controller: _descriptionController,
                maxLines: 4,
                minLines: 3,
                placeholder: '介绍一下这个歌单吧',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.typography.caption1.copyWith(
                    color: MacosColors.systemRedColor,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PushButton(
                    onPressed: state.isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                    controlSize: ControlSize.regular,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  PushButton(
                    controlSize: ControlSize.regular,
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
                            final newId = await playlistsCubit.createPlaylist(
                              name: name,
                              description: _descriptionController.text.trim(),
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
                            child: ProgressCircle(radius: 6),
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
  }
}

Future<String?> showPlaylistCreationSheet(
  BuildContext context, {
  Track? track,
}) async {
  final playlistsCubit = context.read<PlaylistsCubit>();
  final result = await showMacosSheet<String?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => BlocProvider.value(
      value: playlistsCubit,
      child: _PlaylistCreationSheet(initialTrack: track),
    ),
  );
  if (result != null) {
    await playlistsCubit.ensurePlaylistTracks(result, force: true);
  }
  return result;
}
