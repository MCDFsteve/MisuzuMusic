part of 'package:misuzu_music/presentation/pages/home_page.dart';

enum LibraryMountMode { local, mystery }

Future<LibraryMountMode?> showLibraryMountModeDialog(BuildContext context) {
  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  return showPlaylistModalDialog<LibraryMountMode>(
    context: context,
    builder: (dialogContext) {
      final bodyChildren = <Widget>[
        if (isIOS) ...[
          const _IOSAppFolderInfoCard(),
          const SizedBox(height: 12),
          _PlaylistCreationModeOption(
            icon: CupertinoIcons.folder_fill,
            title: 'MisuzuMusic 文件夹',
            description: '浏览 Files App 中的 MisuzuMusic 目录，避免重复占用空间。',
            onTap: () =>
                Navigator.of(dialogContext).pop(LibraryMountMode.local),
          ),
        ] else ...[
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
      ];

      return _PlaylistModalScaffold(
        title: '选择挂载方式',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: bodyChildren,
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

class _IOSAppFolderInfoCard extends StatelessWidget {
  const _IOSAppFolderInfoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle =
        theme.textTheme.titleMedium?.copyWith(
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
    final bodyStyle =
        theme.textTheme.bodyMedium?.copyWith(
          height: 1.35,
          color: isDark
              ? Colors.white.withOpacity(0.72)
              : Colors.black.withOpacity(0.72),
        ) ??
        TextStyle(
          fontSize: 13,
          height: 1.35,
          color: isDark
              ? Colors.white.withOpacity(0.72)
              : Colors.black.withOpacity(0.72),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.info_circle_fill,
                size: 20,
                color: isDark
                    ? Colors.white.withOpacity(0.95)
                    : Colors.black.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                locale: Locale("zh-Hans", "zh"),
                '通过 MisuzuMusic 文件夹导入',
                style: titleStyle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            locale: Locale("zh-Hans", "zh"),
            'iOS 会将外部文件复制到应用沙盒中，为避免空间占用，请按照以下步骤：\n'
            '1）在「文件」App 中进入「我的 iPhone」> Misuzu Music。\n'
            '2）打开 MisuzuMusic 文件夹，并将包含歌曲的文件夹拷贝进去。\n'
            '3）返回 Misuzu Music，选择 MisuzuMusic 文件夹开始扫描。',
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
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
                    locale: Locale("zh-Hans", "zh"),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MacosColors.systemRedColor,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              _SheetActionButton.secondary(
                label: '取消',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              _SheetActionButton.primary(label: '确认挂载', onPressed: submit),
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
