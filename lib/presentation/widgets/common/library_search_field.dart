import 'dart:math' as math;
import 'dart:ui' as ui;

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
    this.onInteract,
    this.useFrostedStyle = false,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final String placeholder;
  final ValueChanged<String>? onPreviewChanged;
  final List<LibrarySearchSuggestion> suggestions;
  final ValueChanged<LibrarySearchSuggestion>? onSuggestionSelected;
  final VoidCallback? onInteract;
  final bool useFrostedStyle;

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
        widget.onInteract?.call();
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
    widget.onInteract?.call();
    widget.onPreviewChanged?.call(value);
    if (value.isEmpty) {
      widget.onQueryChanged('');
    }
    _scheduleOverlayUpdate();
  }

  void _handleSubmitted(String value) {
    widget.onInteract?.call();
    widget.onQueryChanged(value.trim());
    _removeSuggestionOverlay();
  }

  void _handleSuggestionSelected(LibrarySearchSuggestion suggestion) {
    widget.onInteract?.call();
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
                useFrostedStyle: widget.useFrostedStyle,
              )
            : _MaterialSearchField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: widget.placeholder,
                onChanged: _handleChanged,
                onSubmitted: _handleSubmitted,
                isFocused: _focusNode.hasFocus,
                focusProgress: _focusController.value,
                useFrostedStyle: widget.useFrostedStyle,
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
        final fieldBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final overlayBox =
            Overlay.of(context, rootOverlay: true)?.context.findRenderObject()
                as RenderBox?;
        final Size overlaySize = overlayBox?.size ??
            MediaQuery.maybeOf(context)?.size ??
            Size.zero;
        const double screenPadding = 12.0;
        const double verticalGap = 6.0;
        const double defaultDropdownMaxHeight = 280.0;

        final Size fieldSize = fieldBox?.size ?? const Size(260, 40);
        final double fieldHeight = fieldSize.height;

        double dropdownWidth = fieldSize.width;
        double horizontalOffset = 0;
        double dropdownMaxHeight = defaultDropdownMaxHeight;
        bool showBelow = true;

        Offset fieldTopLeft = Offset.zero;
        if (fieldBox != null) {
          fieldTopLeft = overlayBox != null
              ? fieldBox.localToGlobal(Offset.zero, ancestor: overlayBox)
              : fieldBox.localToGlobal(Offset.zero);
        }

        final bool canMeasureOverlay = fieldBox != null &&
            overlaySize.width.isFinite &&
            overlaySize.height.isFinite &&
            overlaySize.width > 0 &&
            overlaySize.height > 0;

        if (canMeasureOverlay) {
          final double maxAllowedWidth =
              overlaySize.width - screenPadding * 2;

          if (maxAllowedWidth.isFinite && maxAllowedWidth > 0) {
            dropdownWidth = math.min(dropdownWidth, maxAllowedWidth);
            if (dropdownWidth <= 0) {
              dropdownWidth = maxAllowedWidth;
            }
          }

          if (overlaySize.width > screenPadding * 2) {
            final double minLeft = screenPadding;
            final double maxRight = overlaySize.width - screenPadding;

            double dropdownLeft = fieldTopLeft.dx + horizontalOffset;
            double dropdownRight = dropdownLeft + dropdownWidth;

            if (dropdownRight > maxRight) {
              final double overflow = dropdownRight - maxRight;
              horizontalOffset -= overflow;
              dropdownLeft -= overflow;
              dropdownRight -= overflow;
            }

            if (dropdownLeft < minLeft) {
              final double overflow = minLeft - dropdownLeft;
              horizontalOffset += overflow;
              dropdownLeft += overflow;
              dropdownRight += overflow;

              if (dropdownRight > maxRight) {
                final double availableWidth = maxRight - minLeft;
                if (availableWidth > 0) {
                  dropdownWidth = math.min(dropdownWidth, availableWidth);
                  horizontalOffset = minLeft - fieldTopLeft.dx;
                }
              }
            }
          }

          final double availableBelow = overlaySize.height -
              (fieldTopLeft.dy + fieldHeight + verticalGap + screenPadding);
          final double availableAbove =
              fieldTopLeft.dy - verticalGap - screenPadding;
          final double clampedBelow = math.max(availableBelow, 0);
          final double clampedAbove = math.max(availableAbove, 0);

          if (clampedBelow >= clampedAbove) {
            dropdownMaxHeight =
                math.min(defaultDropdownMaxHeight, clampedBelow);
            showBelow = true;
          } else {
            dropdownMaxHeight =
                math.min(defaultDropdownMaxHeight, clampedAbove);
            showBelow = false;
          }
        }

        if (!_shouldShowSuggestions ||
            !dropdownWidth.isFinite ||
            dropdownWidth <= 0 ||
            !dropdownMaxHeight.isFinite ||
            dropdownMaxHeight <= 0) {
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
            child: CustomSingleChildLayout(
              delegate: _SearchDropdownLayoutDelegate(
                fieldTopLeft: fieldTopLeft,
                horizontalOffset: horizontalOffset,
                fieldHeight: fieldHeight,
                dropdownWidth: dropdownWidth,
                dropdownMaxHeight: dropdownMaxHeight,
                showBelow: showBelow,
                verticalGap: verticalGap,
                screenPadding: screenPadding,
              ),
              child: SizedBox(
                width: dropdownWidth,
                child: FrostedSearchDropdown(
                  key: _dropdownKey,
                  maxHeight: dropdownMaxHeight,
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
        );
      },
    );
  }
}

class _SearchDropdownLayoutDelegate extends SingleChildLayoutDelegate {
  const _SearchDropdownLayoutDelegate({
    required this.fieldTopLeft,
    required this.horizontalOffset,
    required this.fieldHeight,
    required this.dropdownWidth,
    required this.dropdownMaxHeight,
    required this.showBelow,
    required this.verticalGap,
    required this.screenPadding,
  });

  final Offset fieldTopLeft;
  final double horizontalOffset;
  final double fieldHeight;
  final double dropdownWidth;
  final double dropdownMaxHeight;
  final bool showBelow;
  final double verticalGap;
  final double screenPadding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    double resolvedWidth = dropdownWidth;
    if (!resolvedWidth.isFinite || resolvedWidth <= 0) {
      final double fallback = constraints.maxWidth.isFinite &&
              constraints.maxWidth > 0
          ? constraints.maxWidth
          : 260.0;
      resolvedWidth = math.max(fallback, 1.0);
    } else if (constraints.maxWidth.isFinite &&
        constraints.maxWidth > 0 &&
        resolvedWidth > constraints.maxWidth) {
      resolvedWidth = constraints.maxWidth;
    }

    double resolvedMaxHeight = dropdownMaxHeight;
    if (!resolvedMaxHeight.isFinite || resolvedMaxHeight <= 0) {
      resolvedMaxHeight = constraints.maxHeight.isFinite &&
              constraints.maxHeight > 0
          ? constraints.maxHeight
          : 280.0;
    } else if (constraints.maxHeight.isFinite &&
        constraints.maxHeight > 0 &&
        resolvedMaxHeight > constraints.maxHeight) {
      resolvedMaxHeight = constraints.maxHeight;
    }

    resolvedMaxHeight = math.max(resolvedMaxHeight, 1.0);

    return BoxConstraints(
      minWidth: resolvedWidth,
      maxWidth: resolvedWidth,
      minHeight: 0,
      maxHeight: resolvedMaxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double left = fieldTopLeft.dx + horizontalOffset;
    if (size.width.isFinite && size.width > 0) {
      final double minLeft = screenPadding;
      final double maxLeft = size.width - screenPadding - childSize.width;
      if (maxLeft >= minLeft) {
        left = left.clamp(minLeft, maxLeft);
      } else {
        left = minLeft;
      }
    }

    double top;
    if (showBelow) {
      top = fieldTopLeft.dy + fieldHeight + verticalGap;
      if (size.height.isFinite && size.height > 0) {
        final double maxTop = size.height - screenPadding - childSize.height;
        top = math.min(top, maxTop);
      }
    } else {
      top = fieldTopLeft.dy - verticalGap - childSize.height;
      if (size.height.isFinite && size.height > 0) {
        top = math.max(top, screenPadding);
      }
    }

    if (!left.isFinite) {
      left = 0;
    }
    if (!top.isFinite) {
      top = 0;
    }

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _SearchDropdownLayoutDelegate oldDelegate) {
    return fieldTopLeft != oldDelegate.fieldTopLeft ||
        horizontalOffset != oldDelegate.horizontalOffset ||
        fieldHeight != oldDelegate.fieldHeight ||
        dropdownWidth != oldDelegate.dropdownWidth ||
        dropdownMaxHeight != oldDelegate.dropdownMaxHeight ||
        showBelow != oldDelegate.showBelow ||
        verticalGap != oldDelegate.verticalGap ||
        screenPadding != oldDelegate.screenPadding;
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
    required this.useFrostedStyle,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool isFocused;
  final double focusProgress;
  final bool useFrostedStyle;

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
      decoration: useFrostedStyle
          ? BoxDecoration(
              color: Colors.transparent,
              borderRadius: baseRadius,
              border: Border.all(color: Colors.transparent, width: 0.9),
            )
          : BoxDecoration(
              color: backgroundColor,
              borderRadius: baseRadius,
              border: Border.all(color: baseBorderColor, width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.28)
                      : Colors.black.withOpacity(0.08),
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

    Widget fieldStack = Stack(
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

    if (useFrostedStyle) {
      final Color frostedFill =
          isDark ? Colors.black.withOpacity(0.28) : Colors.white.withOpacity(0.55);
      final Color frostedBorder =
          Colors.white.withOpacity(isDark ? 0.18 : 0.28);

      fieldStack = ClipRRect(
        borderRadius: baseRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: frostedFill,
              borderRadius: baseRadius,
              border: Border.all(color: frostedBorder, width: 0.9),
            ),
            child: fieldStack,
          ),
        ),
      );
    }

    return fieldStack;
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
    required this.useFrostedStyle,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool isFocused;
  final double focusProgress;
  final bool useFrostedStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseBorderColor = theme.dividerColor.withOpacity(0.6);
    final double highlightScale = 1.07 - (0.07 * focusProgress);
    final double highlightOpacity = focusProgress.clamp(0.0, 1.0);
    final double highlightWidth = 1.9 * focusProgress;

    final BorderRadius baseRadius = BorderRadius.circular(18);

    final Widget textFieldBody = Padding(
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
    );

    Widget baseField;

    if (useFrostedStyle) {
      final bool isDarkMode = theme.brightness == Brightness.dark;
      final Color frostedFill =
          isDarkMode ? Colors.black.withOpacity(0.28) : Colors.white.withOpacity(0.55);
      final Color frostedBorder =
          Colors.white.withOpacity(isDarkMode ? 0.16 : 0.26);

      baseField = ClipRRect(
        borderRadius: baseRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: frostedFill,
              borderRadius: baseRadius,
              border: Border.all(color: frostedBorder, width: 0.9),
            ),
            child: textFieldBody,
          ),
        ),
      );
    } else {
      baseField = DecoratedBox(
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
        child: textFieldBody,
      );
    }

    Widget fieldStack = Stack(
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

    return fieldStack;
  }
}
