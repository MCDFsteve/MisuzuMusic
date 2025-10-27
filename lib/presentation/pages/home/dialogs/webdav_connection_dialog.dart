part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _WebDavConnectionFormResult {
  const _WebDavConnectionFormResult({
    required this.baseUrl,
    this.username,
    required this.password,
    required this.ignoreTls,
    this.displayName,
  });

  final String baseUrl;
  final String? username;
  final String password;
  final bool ignoreTls;
  final String? displayName;
}


class _WebDavConnectionDialog extends StatefulWidget {
  const _WebDavConnectionDialog({
    required this.testConnection,
    required this.useModalScaffold,
  });

  final TestWebDavConnection testConnection;
  final bool useModalScaffold;

  @override
  State<_WebDavConnectionDialog> createState() =>
      _WebDavConnectionDialogState();
}

class _WebDavConnectionDialogState extends State<_WebDavConnectionDialog> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _ignoreTls = false;
  bool _testing = false;
  String? _error;
  String? _urlError;
  String? _passwordError;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useModalScaffold) {
      return _PlaylistModalScaffold(
        title: '连接到 WebDAV',
        maxWidth: 380,
        contentSpacing: 18,
        actionsSpacing: 16,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MacosField(
              label: '服务器地址',
              placeholder: 'https://example.com/webdav',
              controller: _urlController,
              errorText: _urlError,
              enabled: !_testing,
            ),
            const SizedBox(height: 12),
            _MacosField(
              label: '用户名 (可选)',
              controller: _usernameController,
              enabled: !_testing,
            ),
            const SizedBox(height: 12),
            _MacosField(
              label: '密码',
              controller: _passwordController,
              errorText: _passwordError,
              obscureText: true,
              enabled: !_testing,
            ),
            const SizedBox(height: 12),
            _MacosField(
              label: '自定义名称 (可选)',
              controller: _displayNameController,
              enabled: !_testing,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                MacosCheckbox(
                  value: _ignoreTls,
                  onChanged: _testing
                      ? null
                      : (value) =>
                            setState(() => _ignoreTls = value ?? false),
                ),
                const SizedBox(width: 8),
                const Flexible(child: Text('忽略 TLS 证书校验')),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: MacosTheme.of(context)
                    .typography
                    .body
                    .copyWith(color: MacosColors.systemRedColor),
              ),
            ],
          ],
        ),
        actions: [
          _SheetActionButton.secondary(
            label: '取消',
            onPressed: _testing ? null : () => Navigator.of(context).pop(),
          ),
          _SheetActionButton.primary(
            label: '连接',
            onPressed: _testing ? null : _onConnect,
            isBusy: _testing,
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('连接到 WebDAV'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://example.com/webdav',
              errorText: _urlError,
            ),
            enabled: !_testing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: '用户名 (可选)'),
            enabled: !_testing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: '密码',
              errorText: _passwordError,
            ),
            obscureText: true,
            enabled: !_testing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(labelText: '自定义名称 (可选)'),
            enabled: !_testing,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _ignoreTls,
            onChanged: (value) => setState(() => _ignoreTls = value ?? false),
            title: const Text('忽略 TLS 证书校验'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _testing ? null : _onConnect,
          child: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('连接'),
        ),
      ],
    );
  }

  Future<void> _onConnect() async {
    final rawUrl = _urlController.text.trim();
    String? urlError;
    if (rawUrl.isEmpty) {
      urlError = '请输入服务器地址';
    } else if (!rawUrl.startsWith('http://') &&
        !rawUrl.startsWith('https://')) {
      urlError = '地址必须以 http:// 或 https:// 开头';
    }

    final password = _passwordController.text;
    String? passwordError;
    if (password.isEmpty) {
      passwordError = '请输入密码';
    }

    if (urlError != null || passwordError != null) {
      setState(() {
        _urlError = urlError;
        _passwordError = passwordError;
        _error = null;
      });
      return;
    }

    setState(() {
      _testing = true;
      _error = null;
      _urlError = null;
      _passwordError = null;
    });

    final baseUrl = rawUrl.endsWith('/')
        ? rawUrl.substring(0, rawUrl.length - 1)
        : rawUrl;
    final username = _usernameController.text.trim();
    final passwordValue = password;
    final displayName = _displayNameController.text.trim();

    final tempSource = WebDavSource(
      id: 'preview',
      name: displayName.isEmpty ? 'WebDAV' : displayName,
      baseUrl: baseUrl,
      rootPath: '/',
      username: username.isEmpty ? null : username,
      ignoreTls: _ignoreTls,
    );

    try {
      await widget.testConnection(source: tempSource, password: passwordValue);

      if (!mounted) return;
      Navigator.of(context).pop(
        _WebDavConnectionFormResult(
          baseUrl: baseUrl,
          username: username.isEmpty ? null : username,
          password: passwordValue,
          ignoreTls: _ignoreTls,
          displayName: displayName.isEmpty ? null : displayName,
        ),
      );
    } catch (e) {
      debugPrint('❌ WebDAV: 连接测试失败 -> $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }
}

class _MacosField extends StatelessWidget {
  const _MacosField({
    required this.label,
    required this.controller,
    this.placeholder,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final String? errorText;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: typography.body),
        const SizedBox(height: 6),
        MacosTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          enabled: enabled,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: typography.caption1.copyWith(
              color: MacosColors.systemRedColor,
            ),
          ),
        ],
      ],
    );
  }
}
