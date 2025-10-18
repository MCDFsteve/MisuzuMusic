import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart' as macos_ui;

class LibrarySearchField extends StatefulWidget {
  const LibrarySearchField({
    super.key,
    required this.query,
    required this.onQueryChanged,
    this.placeholder = '搜索歌曲、艺术家或专辑...',
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final String placeholder;

  @override
  State<LibrarySearchField> createState() => _LibrarySearchFieldState();
}

class _LibrarySearchFieldState extends State<LibrarySearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ignoreNextChange = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant LibrarySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && widget.query != _controller.text) {
      _setControllerText(widget.query);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setControllerText(String value) {
    _ignoreNextChange = true;
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _handleChanged(String value) {
    if (_ignoreNextChange) {
      _ignoreNextChange = false;
      return;
    }
    widget.onQueryChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMac = defaultTargetPlatform == TargetPlatform.macOS;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34, maxHeight: 40),
      child: isMac
          ? _MacSearchField(
              controller: _controller,
              focusNode: _focusNode,
              placeholder: widget.placeholder,
              onChanged: _handleChanged,
              isFocused: _focusNode.hasFocus,
            )
          : _MaterialSearchField(
              controller: _controller,
              focusNode: _focusNode,
              placeholder: widget.placeholder,
              onChanged: _handleChanged,
              isFocused: _focusNode.hasFocus,
            ),
    );
  }
}

class _MacSearchField extends StatelessWidget {
  const _MacSearchField({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
    required this.isFocused,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final bool isFocused;

  static const Color _accentColor = Color(0xFF1B66FF);

  @override
  Widget build(BuildContext context) {
    final theme = macos_ui.MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2C2C2E) : Colors.white.withOpacity(0.92);
    final borderColor = isFocused
        ? _accentColor
        : theme.dividerColor.withOpacity(isDark ? 0.35 : 0.22);
    final iconColor = isFocused
        ? _accentColor
        : (isDark ? Colors.white.withOpacity(0.75) : macos_ui.MacosColors.systemGrayColor);

    return cupertino.CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      placeholderStyle: theme.typography.body.copyWith(
        color: (isDark ? Colors.white : macos_ui.MacosColors.systemGrayColor).withOpacity(0.6),
      ),
      style: theme.typography.body.copyWith(
        color: isDark ? Colors.white : macos_ui.MacosColors.labelColor,
      ),
      cursorColor: _accentColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      prefix: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          cupertino.CupertinoIcons.search,
          size: 16,
          color: iconColor,
        ),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isFocused ? 1.2 : 0.8),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.28) : Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      onChanged: onChanged,
      clearButtonMode: cupertino.OverlayVisibilityMode.editing,
    );
  }
}

class _MaterialSearchField extends StatelessWidget {
  const _MaterialSearchField({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
    required this.isFocused,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = isFocused
        ? colorScheme.primary
        : theme.dividerColor.withOpacity(0.6);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isFocused ? 1.2 : 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            cursorColor: colorScheme.primary,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              icon: Icon(Icons.search, color: isFocused ? colorScheme.primary : theme.iconTheme.color),
              hintText: placeholder,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ),
    );
  }
}
