import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart' as macos_ui;

import '../../../core/utils/platform_utils.dart';
import '../dialogs/frosted_search_dropdown.dart';

enum LibrarySearchSuggestionType { track, artist, album }

class LibrarySearchSuggestion {
  const LibrarySearchSuggestion({
    required this.value,
    required this.label,
    this.description,
    this.type = LibrarySearchSuggestionType.track,
    this.payload,
  });

  final String value;
  final String label;
  final String? description;
  final LibrarySearchSuggestionType type;
  final Object? payload;

  IconData get icon {
    switch (type) {
      case LibrarySearchSuggestionType.track:
        return cupertino.CupertinoIcons.music_note;
      case LibrarySearchSuggestionType.artist:
        return cupertino.CupertinoIcons.person_crop_circle;
      case LibrarySearchSuggestionType.album:
        return cupertino.CupertinoIcons.square_stack_3d_up;
    }
  }
}

class LibrarySearchField extends StatefulWidget {
  const LibrarySearchField({
    super.key,
    required this.query,
    required this.onQueryChanged,
    this.placeholder = '搜索歌曲、艺术家或专辑...',
    this.onPreviewChanged,
    this.suggestions = const [],
    this.onSuggestionSelected,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final String placeholder;
  final ValueChanged<String>? onPreviewChanged;
  final List<LibrarySearchSuggestion> suggestions;
  final ValueChanged<LibrarySearchSuggestion>? onSuggestionSelected;

  @override
  State<LibrarySearchField> createState() => _LibrarySearchFieldState();
}

class _LibrarySearchFieldState extends State<LibrarySearchField>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ignoreNextChange = false;
  late final AnimationController _focusController;
  final LayerLink _overlayLink = LayerLink();
  OverlayEntry? _suggestionOverlay;
  final GlobalKey _fieldKey = GlobalKey();
  final GlobalKey _dropdownKey = GlobalKey();
  bool _pointerInsideDropdown = false;

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
    _scheduleOverlayUpdate();
  }

  @override
  void dispose() {
    _removeSuggestionOverlay();
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
      _scheduleOverlayUpdate();
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
    widget.onPreviewChanged?.call(value);
    if (value.isEmpty) {
      widget.onQueryChanged('');
    }
    _scheduleOverlayUpdate();
  }

  void _handleSubmitted(String value) {
    widget.onQueryChanged(value.trim());
    _removeSuggestionOverlay();
  }

  void _handleSuggestionSelected(LibrarySearchSuggestion suggestion) {
    _setControllerText(suggestion.value);
    debugPrint('[SearchField] Suggestion tapped: ${suggestion.type} -> ${suggestion.value}');
    widget.onSuggestionSelected?.call(suggestion);
    if (_pointerInsideDropdown) {
      setState(() => _pointerInsideDropdown = false);
    }
    _focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _removeSuggestionOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool useDesktopUi = prefersMacLikeUi();

    _scheduleOverlayUpdate();

    final searchField = LayoutBuilder(
      builder: (context, constraints) {
        final input = useDesktopUi
            ? _MacSearchField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: widget.placeholder,
                onChanged: _handleChanged,
                onSubmitted: _handleSubmitted,
                isFocused: _focusNode.hasFocus,
                focusProgress: _focusController.value,
              )
            : _MaterialSearchField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: widget.placeholder,
                onChanged: _handleChanged,
                onSubmitted: _handleSubmitted,
                isFocused: _focusNode.hasFocus,
                focusProgress: _focusController.value,
              );

        return CompositedTransformTarget(
          link: _overlayLink,
          child: ConstrainedBox(
            key: _fieldKey,
            constraints: const BoxConstraints(minHeight: 34, maxHeight: 40),
            child: input,
          ),
        );
      },
    );

    return searchField;
  }

  bool get _shouldShowSuggestions =>
      widget.suggestions.isNotEmpty &&
      (_focusNode.hasFocus || _pointerInsideDropdown) &&
      _controller.text.trim().isNotEmpty;

  void _scheduleOverlayUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateSuggestionOverlay(_shouldShowSuggestions);
    });
  }

  void _updateSuggestionOverlay(bool shouldShow) {
    if (!shouldShow) {
      _removeSuggestionOverlay();
      return;
    }
    if (_suggestionOverlay == null) {
      final overlay = Overlay.of(context, rootOverlay: true);
      if (overlay == null) {
        return;
      }
      _suggestionOverlay = _buildSuggestionOverlay();
      overlay.insert(_suggestionOverlay!);
    } else {
      _suggestionOverlay!.markNeedsBuild();
    }
  }

  void _removeSuggestionOverlay() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
    if (_pointerInsideDropdown) {
      _pointerInsideDropdown = false;
    }
  }

  OverlayEntry _buildSuggestionOverlay() {
    return OverlayEntry(
      builder: (context) {
        final useDesktopUi = prefersMacLikeUi();
        final fieldBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final width = fieldBox?.size.width ?? 260;
        final height = fieldBox?.size.height ?? 40;
        if (!_shouldShowSuggestions) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              final dropdownBox =
                  _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
              bool tappedInside = false;
              if (dropdownBox != null) {
                final localPosition = dropdownBox.globalToLocal(event.position);
                final localBounds = Offset.zero & dropdownBox.size;
                tappedInside = localBounds.contains(localPosition);
              }
              if (tappedInside) {
                if (!_pointerInsideDropdown) {
                  setState(() => _pointerInsideDropdown = true);
                }
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
                return;
              }
              if (_pointerInsideDropdown) {
                setState(() => _pointerInsideDropdown = false);
              }
              if (_focusNode.hasFocus) {
                _focusNode.unfocus();
              }
              _removeSuggestionOverlay();
            },
            onPointerUp: (_) {
              if (_pointerInsideDropdown) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _pointerInsideDropdown = false);
                });
              }
            },
            onPointerCancel: (_) {
              if (_pointerInsideDropdown) {
                setState(() => _pointerInsideDropdown = false);
              }
            },
            child: IgnorePointer(
              ignoring: false,
              child: CompositedTransformFollower(
                link: _overlayLink,
                showWhenUnlinked: false,
                offset: Offset(0, height + 6),
                targetAnchor: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: FrostedSearchDropdown(
                    key: _dropdownKey,
                    children: widget.suggestions
                        .map(
                          (suggestion) => FrostedSearchOption(
                            key: ValueKey(
                              'search_option_${suggestion.type.name}_${suggestion.value}',
                            ),
                            title: suggestion.label,
                            subtitle: suggestion.description,
                            icon: suggestion.icon,
                            onTap: () {
                              debugPrint('[SearchField] Option onTap -> ${suggestion.value}');
                              _handleSuggestionSelected(suggestion);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MacSearchField extends StatelessWidget {
  const _MacSearchField({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
    required this.onSubmitted,
    required this.isFocused,
    required this.focusProgress,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
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
      textInputAction: TextInputAction.search,
      keyboardType: TextInputType.text,
      maxLines: 1,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
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
    required this.onSubmitted,
    required this.isFocused,
    required this.focusProgress,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
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
              onSubmitted: onSubmitted,
              cursorColor: colorScheme.primary,
              cursorWidth: 2.4,
              textInputAction: TextInputAction.search,
              keyboardType: TextInputType.text,
              maxLines: 1,
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
