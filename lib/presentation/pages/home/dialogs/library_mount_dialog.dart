part of 'package:misuzu_music/presentation/pages/home_page.dart';

enum LibraryMountMode { local, mystery }

Future<LibraryMountMode?> showLibraryMountModeDialog(BuildContext context) {
  return showPlaylistModalDialog<LibraryMountMode>(
    context: context,
    builder: (dialogContext) {
      return _PlaylistModalScaffold(
        title: '选择挂载方式',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlaylistCreationModeOption(
              icon: CupertinoIcons.folder_solid,
              title: '挂载本地文件夹',
              description: '从磁盘选择文件夹并扫描其中的音乐文件。',
              onTap: () =>
                  Navigator.of(dialogContext).pop(LibraryMountMode.local),
            ),
            const SizedBox(height: 12),
            _PlaylistCreationModeOption(
              icon: CupertinoIcons.lock,
              title: '神秘代码',
              description: '',
              onTap: () =>
                  Navigator.of(dialogContext).pop(LibraryMountMode.mystery),
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

Future<String?> showMysteryCodeDialog(BuildContext context) {
  final controller = TextEditingController();
  String? errorText;
  return showPlaylistModalDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setState(() => errorText = '请输入神秘代码');
              return;
            }
            Navigator.of(dialogContext).pop(value);
          }

          return _PlaylistModalScaffold(
            title: '输入神秘代码',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModalTextField(
                  controller: controller,
                  label: '神秘代码',
                  hintText: '',
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
                  Text(
                    errorText!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: MacosColors.systemRedColor),
                  ),
                ],
              ],
            ),
            actions: [
              _SheetActionButton.secondary(
                label: '取消',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              _SheetActionButton.primary(
                label: '确认挂载',
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
