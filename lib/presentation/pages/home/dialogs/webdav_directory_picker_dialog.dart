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
    if (!prefersMacLikeUi()) {
      return _buildMaterialDialog(context);
    }
    return _buildFrostedDialog(context);
  }

  Widget _buildFrostedDialog(BuildContext context) {
    final canConfirm = !_loading && _error == null;

    return FrostedSelectionModal(
      title: '选择 WebDAV 文件夹',
      maxWidth: 460,
      contentSpacing: 14,
      actionsSpacing: 18,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '当前路径: $_currentPath',
            locale: const Locale('zh-Hans', 'zh'),
            style: MacosTheme.of(context)
                .typography
                .body
                .copyWith(fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: FrostedSelectionContainer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildContent(),
              ),
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

  Widget _buildMaterialDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('选择 WebDAV 文件夹', locale: Locale('zh-Hans', 'zh')),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('当前路径: $_currentPath', style: const TextStyle(fontSize: 13), locale: const Locale('zh-Hans', 'zh')),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                            locale: const Locale('zh-Hans', 'zh'),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length + (_currentPath == '/' ? 0 : 1),
                          itemBuilder: (context, index) {
                            if (_currentPath != '/' && index == 0) {
                              return ListTile(
                                leading: const Icon(Icons.arrow_upward),
                                title: const Text('..'),
                                onTap: () => _load(_parentPath(_currentPath)),
                              );
                            }
                            final entryIndex = _currentPath == '/' ? index : index - 1;
                            final entry = _entries[entryIndex];
                            return ListTile(
                              leading: Icon(entry.isDirectory ? Icons.folder : Icons.audiotrack),
                              title: Text(entry.name, locale: const Locale('zh-Hans', 'zh')),
                              onTap: entry.isDirectory ? () => _load(entry.path) : null,
                              subtitle: Text(
                                entry.path,
                                maxLines: 1,
                                locale: const Locale('zh-Hans', 'zh'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', locale: Locale('zh-Hans', 'zh')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_currentPath),
          child: const Text('选择此文件夹', locale: Locale('zh-Hans', 'zh')),
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
    return const Center(
      child: CupertinoActivityIndicator(radius: 12),
    );
  }
}

class _DirectoryErrorView extends StatelessWidget {
  const _DirectoryErrorView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          locale: const Locale('zh-Hans', 'zh'),
          style: macTheme.typography.body.copyWith(
            color: MacosColors.systemRedColor,
            height: 1.42,
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
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.62);

    return Center(
      child: Text(
        '该目录为空，尝试返回上一层或选择其它路径。',
        locale: const Locale('zh-Hans', 'zh'),
        style: macTheme.typography.caption1.copyWith(
          color: color,
          height: 1.42,
        ),
        textAlign: TextAlign.center,
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
    final macTheme = MacosTheme.of(context);
    final isDark = macTheme.brightness == Brightness.dark;
    final dividerColor = macTheme.dividerColor.withOpacity(isDark ? 0.35 : 0.28);

    final totalCount = entries.length + (currentPath == '/' ? 0 : 1);

    return MacosScrollbar(
      controller: controller,
      child: ListView.separated(
        controller: controller,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        itemCount: totalCount,
        separatorBuilder: (_, __) => SizedBox(
          height: 4,
          child: Divider(
            height: 1,
            thickness: 0.6,
            color: dividerColor,
          ),
        ),
        itemBuilder: (context, index) {
          if (currentPath != '/' && index == 0) {
            return FrostedOptionTile(
              leading: Icon(
                CupertinoIcons.arrow_uturn_left,
                size: 16,
                color: isDark
                    ? Colors.white.withOpacity(0.75)
                    : Colors.black.withOpacity(0.66),
              ),
              title: '..',
              subtitle: '返回上一层',
              onPressed: onNavigateUp,
            );
          }

          final entryIndex = currentPath == '/' ? index : index - 1;
          final entry = entries[entryIndex];
          final leading = Icon(
            entry.isDirectory
                ? CupertinoIcons.folder_fill
                : CupertinoIcons.music_note,
            size: 16,
            color: entry.isDirectory
                ? (isDark
                    ? Colors.white.withOpacity(0.82)
                    : Colors.black.withOpacity(0.72))
                : (isDark
                    ? Colors.white.withOpacity(0.68)
                    : Colors.black.withOpacity(0.6)),
          );

          return FrostedOptionTile(
            leading: leading,
            title: entry.name,
            subtitle: entry.path,
            enabled: entry.isDirectory,
            onPressed: entry.isDirectory ? () => onOpenEntry(entry) : null,
          );
        },
      ),
    );
  }
}
