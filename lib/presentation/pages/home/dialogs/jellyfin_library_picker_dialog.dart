part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _JellyfinLibraryPickerDialog extends StatelessWidget {
  const _JellyfinLibraryPickerDialog({required this.libraries});

  final List<JellyfinLibrary> libraries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _PlaylistModalScaffold(
      title: '选择 Jellyfin 音乐库',
      maxWidth: 420,
      contentSpacing: 16,
      actionsSpacing: 14,
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: libraries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final library = libraries[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: theme.colorScheme.surfaceContainerHighest.withOpacity(
                theme.brightness == Brightness.dark ? 0.4 : 0.5,
              ),
              title: Text(
                library.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: library.collectionType == null
                  ? null
                  : Text(
                      library.collectionType!,
                      style: theme.textTheme.bodySmall,
                    ),
              trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
              onTap: () => Navigator.of(context).pop(library),
            );
          },
        ),
      ),
      actions: [
        _SheetActionButton.secondary(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
