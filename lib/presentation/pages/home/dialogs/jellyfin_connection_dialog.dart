part of 'package:misuzu_music/presentation/pages/home_page.dart';

class _JellyfinConnectionFormResult {
  const _JellyfinConnectionFormResult({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.ignoreTls,
  });

  final String baseUrl;
  final String username;
  final String password;
  final bool ignoreTls;
}

const List<String> _jellyfinStepTitles = [
  '填写服务器地址',
  '输入账号密码',
];

const List<String> _jellyfinStepDescriptions = [
  '请输入 Jellyfin 服务器的完整地址，并根据需要开启忽略 TLS 校验。',
  '输入 Jellyfin 账号与密码以完成连接。',
];

class _JellyfinConnectionDialog extends StatefulWidget {
  const _JellyfinConnectionDialog();

  @override
  State<_JellyfinConnectionDialog> createState() =>
      _JellyfinConnectionDialogState();
}

class _JellyfinConnectionDialogState extends State<_JellyfinConnectionDialog> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _ignoreTls = false;
  String? _error;
  String? _urlError;
  String? _usernameError;
  String? _passwordError;
  int _currentStep = 0;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PlaylistModalScaffold(
      title: '连接到 Jellyfin',
      maxWidth: 400,
      contentSpacing: 18,
      actionsSpacing: 16,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '步骤 ${_currentStep + 1} / ${_jellyfinStepTitles.length}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _jellyfinStepTitles[_currentStep],
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _jellyfinStepDescriptions[_currentStep],
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (_currentStep > 0)
          _SheetActionButton.secondary(
            label: '上一步',
            onPressed: _goBack,
          ),
        _SheetActionButton.primary(
          label: _isLastStep ? '连接' : '下一步',
          onPressed: _handlePrimaryPressed,
        ),
      ],
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey('jellyfin_step_server'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogFormField(
              label: '服务器地址',
              controller: _urlController,
              hintText: 'https://example.com',
              errorText: _urlError,
              autofocus: true,
              onChanged: (_) {
                if (_urlError != null || _error != null) {
                  setState(() {
                    _urlError = null;
                    _error = null;
                  });
                }
              },
              onSubmitted: (_) => _goForward(),
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
                    onChanged: (value) =>
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
      default:
        return Column(
          key: const ValueKey('jellyfin_step_credential'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogFormField(
              label: '用户名',
              controller: _usernameController,
              errorText: _usernameError,
              onChanged: (_) {
                if (_usernameError != null || _error != null) {
                  setState(() {
                    _usernameError = null;
                    _error = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            _DialogFormField(
              label: '密码',
              controller: _passwordController,
              errorText: _passwordError,
              obscureText: true,
              onChanged: (_) {
                if (_passwordError != null || _error != null) {
                  setState(() {
                    _passwordError = null;
                    _error = null;
                  });
                }
              },
              onSubmitted: (_) => _onConnect(),
            ),
          ],
        );
    }
  }

  bool get _isLastStep => _currentStep >= _jellyfinStepTitles.length - 1;

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
      _currentStep = step.clamp(0, _jellyfinStepTitles.length - 1);
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

  bool _validateCredentials() {
    String? userError;
    String? passError;

    if (_usernameController.text.trim().isEmpty) {
      userError = '请输入用户名';
    }
    if (_passwordController.text.isEmpty) {
      passError = '请输入密码';
    }

    setState(() {
      _usernameError = userError;
      _passwordError = passError;
      if (userError != null || passError != null) {
        _error = null;
      }
    });
    return userError == null && passError == null;
  }

  void _onConnect() {
    final serverOk = _validateServer();
    if (!serverOk) {
      _goToStep(0);
      return;
    }
    final credentialsOk = _validateCredentials();
    if (!credentialsOk) {
      _goToStep(1);
      return;
    }

    final rawUrl = _urlController.text.trim();
    final baseUrl = rawUrl.endsWith('/')
        ? rawUrl.substring(0, rawUrl.length - 1)
        : rawUrl;

    Navigator.of(context).pop(
      _JellyfinConnectionFormResult(
        baseUrl: baseUrl,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        ignoreTls: _ignoreTls,
      ),
    );
  }
}
