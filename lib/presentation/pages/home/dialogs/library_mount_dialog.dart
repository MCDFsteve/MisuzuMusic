part of 'package:misuzu_music/presentation/pages/home_page.dart';

enum LibraryMountMode { local, mystery }

Future<LibraryMountMode?> showLibraryMountModeDialog(BuildContext context) {
  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  return showPlaylistModalDialog<LibraryMountMode>(
    context: context,
    builder: (dialogContext) {
      final dialogL10n = dialogContext.l10n;
      final bodyChildren = <Widget>[
        if (isIOS) ...[
          const _IOSAppFolderInfoCard(),
          const SizedBox(height: 12),
          _PlaylistCreationModeOption(
            icon: CupertinoIcons.folder_fill,
            title: dialogL10n.libraryMountOptionAppFolderTitle,
            description: dialogL10n.libraryMountOptionAppFolderDescription,
            onTap: () =>
                Navigator.of(dialogContext).pop(LibraryMountMode.local),
          ),
        ] else ...[
          _PlaylistCreationModeOption(
            icon: CupertinoIcons.folder_solid,
            title: dialogL10n.libraryMountOptionLocalTitle,
            description: dialogL10n.libraryMountOptionLocalDescription,
            onTap: () =>
                Navigator.of(dialogContext).pop(LibraryMountMode.local),
          ),
          const SizedBox(height: 12),
          _PlaylistCreationModeOption(
            icon: CupertinoIcons.lock,
            title: dialogL10n.libraryMountOptionMysteryTitle,
            description: '',
            onTap: () =>
                Navigator.of(dialogContext).pop(LibraryMountMode.mystery),
          ),
        ],
      ];

      return _PlaylistModalScaffold(
        title: dialogL10n.libraryMountDialogTitle,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: bodyChildren,
        ),
        actions: [
          _SheetActionButton.secondary(
            label: dialogL10n.actionCancel,
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
    final l10n = context.l10n;
    final filesRootLabel = _filesAppRootLabel(context, l10n);
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
              Text(l10n.libraryMountInfoCardTitle, style: titleStyle),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.libraryMountInfoCardDescription(filesRootLabel),
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
      final dialogL10n = dialogContext.l10n;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setState(() =>
                  errorText = dialogL10n.libraryMountMysteryCodeEmptyError);
              return;
            }
            Navigator.of(dialogContext).pop(value);
          }

          return _PlaylistModalScaffold(
            title: dialogL10n.libraryMountMysteryDialogTitle,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModalTextField(
                  controller: controller,
                  label: dialogL10n.libraryMountMysteryCodeFieldLabel,
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MacosColors.systemRedColor,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              _SheetActionButton.secondary(
                label: dialogL10n.actionCancel,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              _SheetActionButton.primary(
                label: dialogL10n.libraryMountConfirmButton,
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
