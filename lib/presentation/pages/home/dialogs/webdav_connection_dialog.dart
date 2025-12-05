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


const List<String> _webDavStepTitles = [
  '填写服务器地址',
  '输入账号密码',
  '设置显示名称',
];

const List<String> _webDavStepDescriptions = [
  '请输入 WebDAV 服务的完整地址，并根据需要开启忽略 TLS 校验。',
  '如果服务器需要认证，请填写用户名和密码。',
  '为该连接设置一个显示名称，便于在音乐库中区分。',
];

class _WebDavConnectionDialog extends StatefulWidget {
  const _WebDavConnectionDialog({
    required this.testConnection,
  });

  final TestWebDavConnection testConnection;

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
  int _currentStep = 0;

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
    final theme = Theme.of(context);
    return _PlaylistModalScaffold(
      title: '连接到 WebDAV',
      maxWidth: 400,
      contentSpacing: 18,
      actionsSpacing: 16,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '步骤 ${_currentStep + 1} / ${_webDavStepTitles.length}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _webDavStepTitles[_currentStep],
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _webDavStepDescriptions[_currentStep],
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildStepContent(context),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _DialogErrorBanner(message: _error!),
          ],
        ],
      ),
      actions: [
        _SheetActionButton.secondary(
          label: '取消',
          onPressed: _testing ? null : () => Navigator.of(context).pop(),
        ),
        if (_currentStep > 0)
          _SheetActionButton.secondary(
            label: '上一步',
            onPressed: _testing ? null : _goBack,
          ),
        _SheetActionButton.primary(
          label: _isLastStep ? '连接' : '下一步',
          onPressed: _testing ? null : _handlePrimaryPressed,
          isBusy: _testing,
        ),
      ],
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey('webdav_step_server'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogFormField(
              label: '服务器地址',
              controller: _urlController,
              hintText: 'https://example.com/webdav',
              errorText: _urlError,
              enabled: !_testing,
              autofocus: true,
              onChanged: (_) {
                if (_urlError != null || _error != null) {
                  setState(() {
                    _urlError = null;
                    _error = null;
                  });
                }
              },
              onSubmitted: (_) {
                if (!_testing) {
                  _goForward();
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _ignoreTls,
                    onChanged: _testing
                        ? null
                        : (value) =>
                            setState(() => _ignoreTls = value ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '忽略 TLS 证书校验（仅在自签名或调试环境使用）',
                  ),
                ),
              ],
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey('webdav_step_credential'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogFormField(
              label: '用户名 (可选)',
              controller: _usernameController,
              enabled: !_testing,
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 12),
            _DialogFormField(
              label: '密码',
              controller: _passwordController,
              errorText: _passwordError,
              obscureText: true,
              enabled: !_testing,
              onChanged: (_) {
                if (_passwordError != null || _error != null) {
                  setState(() {
                    _passwordError = null;
                    _error = null;
                  });
                }
              },
              onSubmitted: (_) {
                if (!_testing) {
                  _goForward();
                }
              },
            ),
          ],
        );
      default:
        final previewName = _displayNameController.text.trim().isEmpty
            ? 'WebDAV'
            : _displayNameController.text.trim();
        return Column(
          key: const ValueKey('webdav_step_display'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogFormField(
              label: '自定义名称 (可选)',
              controller: _displayNameController,
              enabled: !_testing,
              onChanged: (_) {
                setState(() {
                  if (_error != null) {
                    _error = null;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _PreviewInfoCard(
              name: previewName,
              baseUrl: _urlController.text.trim(),
            ),
          ],
        );
    }
  }

  bool get _isLastStep => _currentStep >= _webDavStepTitles.length - 1;

  void _handlePrimaryPressed() {
    if (_isLastStep) {
      _onConnect();
      return;
    }
    _goForward();
  }

  void _goForward() {
    if (_currentStep == 0) {
      if (_validateServer()) {
        _goToStep(1);
      }
      return;
    }
    if (_currentStep == 1) {
      if (_validatePassword()) {
        _goToStep(2);
      }
    }
  }

  void _goBack() {
    if (_currentStep == 0) {
      return;
    }
    setState(() {
      _currentStep -= 1;
      _error = null;
    });
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step.clamp(0, _webDavStepTitles.length - 1);
      _error = null;
    });
  }

  bool _validateServer() {
    final rawUrl = _urlController.text.trim();
    String? error;
    if (rawUrl.isEmpty) {
      error = '请输入服务器地址';
    } else if (!rawUrl.startsWith('http://') &&
        !rawUrl.startsWith('https://')) {
      error = '地址必须以 http:// 或 https:// 开头';
    }
    setState(() {
      _urlError = error;
      if (error != null) {
        _error = null;
      }
    });
    return error == null;
  }

  bool _validatePassword() {
    final password = _passwordController.text;
    String? error;
    if (password.isEmpty) {
      error = '请输入密码';
    }
    setState(() {
      _passwordError = error;
      if (error != null) {
        _error = null;
      }
    });
    return error == null;
  }

  Future<void> _onConnect() async {
    final serverOk = _validateServer();
    final passwordOk = _validatePassword();
    if (!serverOk) {
      _goToStep(0);
      return;
    }
    if (!passwordOk) {
      _goToStep(1);
      return;
    }

    setState(() {
      _testing = true;
      _error = null;
    });

    final rawUrl = _urlController.text.trim();
    final baseUrl = rawUrl.endsWith('/')
        ? rawUrl.substring(0, rawUrl.length - 1)
        : rawUrl;
    final username = _usernameController.text.trim();
    final passwordValue = _passwordController.text;
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

class _DialogFormField extends StatelessWidget {
  const _DialogFormField({
    required this.label,
    required this.controller,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;
    final labelColor = isDark
        ? Colors.white.withOpacity(0.82)
        : Colors.black.withOpacity(0.78);
    final hintColor = isDark
        ? Colors.white.withOpacity(0.35)
        : Colors.black.withOpacity(0.4);
    final fillColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.035);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.16)
        : Colors.black.withOpacity(0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor),
            errorText: errorText,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withOpacity(
                  isDark ? 0.85 : 0.9,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogErrorBanner extends StatelessWidget {
  const _DialogErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? Colors.redAccent.withOpacity(0.15)
        : Colors.redAccent.withOpacity(0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.redAccent.withOpacity(isDark ? 0.9 : 0.8),
        ),
      ),
    );
  }
}

class _PreviewInfoCard extends StatelessWidget {
  const _PreviewInfoCard({
    required this.name,
    required this.baseUrl,
  });

  final String name;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macTheme = MacosTheme.maybeOf(context);
    final brightness = macTheme?.brightness ?? theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surface = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    final border = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.black.withOpacity(0.06);
    final caption = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '即将添加的音乐库',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text('显示名称: $name', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '服务器: ${baseUrl.isEmpty ? '未填写' : baseUrl}',
            style: theme.textTheme.bodySmall?.copyWith(color: caption),
          ),
        ],
      ),
    );
  }
}
