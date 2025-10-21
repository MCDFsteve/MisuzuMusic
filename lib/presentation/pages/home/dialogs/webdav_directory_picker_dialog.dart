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

  @override
  void initState() {
    super.initState();
    _currentPath = widget.source.rootPath;
    _load(_currentPath);
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
    return AlertDialog(
      title: const Text('选择 WebDAV 文件夹'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('当前路径: $_currentPath', style: const TextStyle(fontSize: 13)),
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
                      ),
                    )
                  : ListView.builder(
                      itemCount:
                          _entries.length + (_currentPath == '/' ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (_currentPath != '/' && index == 0) {
                          return ListTile(
                            leading: const Icon(Icons.arrow_upward),
                            title: const Text('..'),
                            onTap: () => _load(_parentPath(_currentPath)),
                          );
                        }
                        final entryIndex = _currentPath == '/'
                            ? index
                            : index - 1;
                        final entry = _entries[entryIndex];
                        return ListTile(
                          leading: Icon(
                            entry.isDirectory ? Icons.folder : Icons.audiotrack,
                          ),
                          title: Text(entry.name),
                          onTap: entry.isDirectory
                              ? () => _load(entry.path)
                              : null,
                          subtitle: Text(entry.path, maxLines: 1),
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
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_currentPath),
          child: const Text('选择此文件夹'),
        ),
      ],
    );
  }
}
