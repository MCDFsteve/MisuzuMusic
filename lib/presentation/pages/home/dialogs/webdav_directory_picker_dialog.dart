part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _WebDavDirectoryPickerDialog extends StatefulWidget {
  const _WebDavDirectoryPickerDialog({
    required this.listDirectory,
    required this.source,
    required this.password,
  });

  final ListWebDavDirectory listDirectory;
  final WebDavSource source;
  final String password;

  @override
  State<_WebDavDirectoryPickerDialog> createState() =>
      _WebDavDirectoryPickerDialogState();
}

class _WebDavDirectoryPickerDialogState
    extends State<_WebDavDirectoryPickerDialog> {
  late String _currentPath;
  bool _loading = true;
  String? _error;
  List<WebDavEntry> _entries = const [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPath = widget.source.rootPath;
    _load(_currentPath);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
    });
    try {
      final entries = await widget.listDirectory(
        source: widget.source,
        password: widget.password,
        path: path,
      );
      if (mounted) {
        setState(() => _entries = entries);
      }
    } catch (e) {
      debugPrint('❌ WebDAV: 目录读取失败 ($path) -> $e');
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _parentPath(String path) {
    final normalized = _normalize(path);
    if (normalized == '/') {
      return '/';
    }
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length <= 1) {
      return '/';
    }
    segments.removeLast();
    return '/${segments.join('/')}';
  }

  String _normalize(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) return '/';
    if (!normalized.startsWith('/')) normalized = '/$normalized';
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = !_loading && _error == null;

    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;

    final breadcrumbs = _currentPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    return FrostedSelectionModal(
      title: '选择 WebDAV 文件夹',
      maxWidth: 480,
      contentSpacing: 14,
      actionsSpacing: 18,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PathChip(
                label: '/',
                isActive: breadcrumbs.isEmpty,
                onTap:
                    _currentPath == '/' ? null : () => _load('/'),
              ),
              ...List.generate(breadcrumbs.length, (index) {
                final partialPath = '/${breadcrumbs.sublist(0, index + 1).join('/')}';
                final isLast = index == breadcrumbs.length - 1;
                return _PathChip(
                  label: breadcrumbs[index],
                  isActive: isLast,
                  onTap: isLast ? null : () => _load(partialPath),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(maxHeight: 320),
            child: FrostedSelectionContainer(
              child: _buildContent(),
            ),
          ),
        ],
      ),
      actions: [
        SheetActionButton.secondary(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        SheetActionButton.primary(
          label: '选择此文件夹',
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_currentPath)
              : null,
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const _DirectoryLoadingView(key: ValueKey('webdav-loading'));
    }
    if (_error != null) {
      return _DirectoryErrorView(
        key: const ValueKey('webdav-error'),
        message: _error!,
      );
    }

    final entriesCount = _entries.length + (_currentPath == '/' ? 0 : 1);

    if (entriesCount == 0) {
      return const _DirectoryEmptyView(key: ValueKey('webdav-empty'));
    }

    return _DirectoryEntriesView(
      key: ValueKey('webdav-list-$_currentPath'),
      controller: _scrollController,
      currentPath: _currentPath,
      entries: _entries,
      onNavigateUp: () => _load(_parentPath(_currentPath)),
      onOpenEntry: (entry) => _load(entry.path),
    );
  }
}

class _DirectoryLoadingView extends StatelessWidget {
  const _DirectoryLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(
        child: CupertinoActivityIndicator(radius: 12),
      ),
    );
  }
}

class _DirectoryErrorView extends StatelessWidget {
  const _DirectoryErrorView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surface = isDark
        ? Colors.redAccent.withOpacity(0.12)
        : Colors.redAccent.withOpacity(0.08);

    return SizedBox(
      height: 220,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: surface,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            locale: const Locale('zh-Hans', 'zh'),
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.redAccent.withOpacity(isDark ? 0.95 : 0.8),
                  height: 1.4,
                ) ??
                TextStyle(
                  color: Colors.redAccent.withOpacity(isDark ? 0.95 : 0.8),
                  height: 1.4,
                ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryEmptyView extends StatelessWidget {
  const _DirectoryEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.65);

    return SizedBox(
      height: 220,
      child: Center(
        child: Text(
          '该目录为空，尝试返回上一层或选择其它路径。',
          locale: const Locale('zh-Hans', 'zh'),
          style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                height: 1.4,
              ) ??
              TextStyle(color: color, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DirectoryEntriesView extends StatelessWidget {
  const _DirectoryEntriesView({
    super.key,
    required this.controller,
    required this.currentPath,
    required this.entries,
    required this.onNavigateUp,
    required this.onOpenEntry,
  });

  final ScrollController controller;
  final String currentPath;
  final List<WebDavEntry> entries;
  final VoidCallback onNavigateUp;
  final ValueChanged<WebDavEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;
    final dividerColor = (macTheme?.dividerColor ?? Colors.black12)
        .withOpacity(isDark ? 0.35 : 0.28);

    final itemList = <WebDavEntry?>[
      if (currentPath != '/') null,
      ...entries,
    ];

    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: ListView.separated(
        controller: controller,
        itemCount: itemList.length,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        separatorBuilder: (_, __) => SizedBox(
          height: 4,
          child: Divider(height: 1, thickness: 0.6, color: dividerColor),
        ),
        itemBuilder: (context, index) {
          final entry = itemList[index];
          return _DirectoryEntryTile(
            entry: entry,
            isDark: isDark,
            onNavigateUp: onNavigateUp,
            onOpenEntry: onOpenEntry,
          );
        },
      ),
    );
  }
}

class _PathChip extends StatelessWidget {
  const _PathChip({
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;
    final background = isActive
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.12)
        : (isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.05));
    final borderColor = isActive
        ? theme.colorScheme.primary.withOpacity(isDark ? 0.5 : 0.35)
        : Colors.transparent;
    final textColor = isActive
        ? theme.colorScheme.primary
        : (isDark
            ? Colors.white.withOpacity(0.8)
            : Colors.black.withOpacity(0.75));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor, width: isActive ? 1 : 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          locale: const Locale('zh-Hans', 'zh'),
          style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ) ??
              TextStyle(
                color: textColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
        ),
      ),
    );
  }
}

class _DirectoryEntryTile extends StatelessWidget {
  const _DirectoryEntryTile({
    required this.entry,
    required this.isDark,
    required this.onNavigateUp,
    required this.onOpenEntry,
  });

  final WebDavEntry? entry;
  final bool isDark;
  final VoidCallback onNavigateUp;
  final ValueChanged<WebDavEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return FrostedOptionTile(
        leading: Icon(
          CupertinoIcons.arrow_uturn_left,
          size: 16,
          color:
              isDark ? Colors.white.withOpacity(0.75) : Colors.black.withOpacity(0.66),
        ),
        title: '..',
        subtitle: '返回上一层',
        onPressed: onNavigateUp,
      );
    }

    final leading = Icon(
      entry!.isDirectory ? CupertinoIcons.folder_fill : CupertinoIcons.music_note,
      size: 16,
      color: entry!.isDirectory
          ? (isDark ? Colors.white.withOpacity(0.82) : Colors.black.withOpacity(0.72))
          : (isDark ? Colors.white.withOpacity(0.68) : Colors.black.withOpacity(0.6)),
    );

    return FrostedOptionTile(
      leading: leading,
      title: entry!.name,
      subtitle: entry!.path,
      enabled: entry!.isDirectory,
      onPressed: entry!.isDirectory ? () => onOpenEntry(entry!) : null,
    );
  }
}
