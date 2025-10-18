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

class _LibrarySearchFieldState extends State<LibrarySearchField>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ignoreNextChange = false;
  late final AnimationController _focusController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: _focusNode.hasFocus ? 1.0 : 0.0,
    );
    _focusController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
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
    _focusController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      if (_focusNode.hasFocus) {
        _focusController.forward();
      } else {
        _focusController.reverse();
      }
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
              focusProgress: _focusController.value,
            )
          : _MaterialSearchField(
              controller: _controller,
              focusNode: _focusNode,
              placeholder: widget.placeholder,
              onChanged: _handleChanged,
              isFocused: _focusNode.hasFocus,
              focusProgress: _focusController.value,
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
    required this.focusProgress,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final bool isFocused;
  final double focusProgress;

  static const Color _accentColor = Color(0xFF1B66FF);

  @override
  Widget build(BuildContext context) {
    final theme = macos_ui.MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2C2C2E) : Colors.white.withOpacity(0.92);
    final baseBorderColor = theme.dividerColor.withOpacity(isDark ? 0.35 : 0.22);
    final iconColor = isFocused
        ? _accentColor
        : (isDark ? Colors.white.withOpacity(0.75) : macos_ui.MacosColors.systemGrayColor);
    final double highlightScale = 1.08 - (0.08 * focusProgress);
    final double highlightOpacity = focusProgress.clamp(0.0, 1.0);
    final double highlightWidth = 1.8 * focusProgress;

    final BorderRadius baseRadius = BorderRadius.circular(12);

    final textField = cupertino.CupertinoTextField(
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
        cursorWidth: 2.4,
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
          borderRadius: baseRadius,
          border: Border.all(color: baseBorderColor, width: 0.9),
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        textField,
        if (highlightOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.scale(
                scale: highlightScale,
                child: Opacity(
                  opacity: highlightOpacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: baseRadius,
                      border: Border.all(
                        color: _accentColor,
                        width: highlightWidth.clamp(0.0, 2.0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
    required this.focusProgress,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final bool isFocused;
  final double focusProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseBorderColor = theme.dividerColor.withOpacity(0.6);
    final double highlightScale = 1.07 - (0.07 * focusProgress);
    final double highlightOpacity = focusProgress.clamp(0.0, 1.0);
    final double highlightWidth = 1.9 * focusProgress;

    final BorderRadius baseRadius = BorderRadius.circular(18);

    final baseField = DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.85),
          borderRadius: baseRadius,
          border: Border.all(color: baseBorderColor, width: 0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              cursorColor: colorScheme.primary,
              cursorWidth: 2.4,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                icon: Icon(
                  Icons.search,
                  color: isFocused ? colorScheme.primary : theme.iconTheme.color,
                ),
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseField,
        if (highlightOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.scale(
                scale: highlightScale,
                child: Opacity(
                  opacity: highlightOpacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: baseRadius,
                      border: Border.all(
                        color: colorScheme.primary,
                        width: highlightWidth.clamp(0.0, 2.2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
