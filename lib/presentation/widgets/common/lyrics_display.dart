import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';

import '../../blocs/player/player_bloc.dart';
import '../../../domain/entities/lyrics_entities.dart';
import 'furigana_text.dart';

class LyricsDisplay extends StatefulWidget {
  const LyricsDisplay({
    super.key,
    required this.lines,
    required this.controller,
    required this.isDarkMode,
    this.showTranslation = true,
    this.onActiveLineChanged,
    this.onActiveIndexChanged,
  });

  final List<LyricsLine> lines;
  final ScrollController controller;
  final bool isDarkMode;
  final bool showTranslation;
  final ValueChanged<LyricsLine?>? onActiveLineChanged;
  final ValueChanged<int>? onActiveIndexChanged;

  @override
  State<LyricsDisplay> createState() => _LyricsDisplayState();
}

class _LyricsDisplayState extends State<LyricsDisplay> {
  static const double _activeFontSize = 26.0;
  static const double _inactiveFontSize = 16.0;
  static const EdgeInsets _linePadding = EdgeInsets.symmetric(
    vertical: 0,
    horizontal: 12,
  );
  static const double _listSidePadding = 4.0;
  static const Duration _animationDuration = Duration(milliseconds: 240);

  int _activeIndex = -1;
  late List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = _generateKeys(widget.lines.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final PlayerBlocState state = context.read<PlayerBloc>().state;
      final Duration? position = _positionFromState(state);
      if (position != null) {
        _updateActiveIndex(position);
      }
    });
  }

  @override
  void didUpdateWidget(covariant LyricsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.length != widget.lines.length) {
      _itemKeys = _generateKeys(widget.lines.length);
      if (widget.lines.isEmpty) {
        widget.onActiveIndexChanged?.call(-1);
        widget.onActiveLineChanged?.call(null);
      }
    }
    if (oldWidget.showTranslation != widget.showTranslation &&
        _activeIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToIndex(_activeIndex);
      });
    }

    if (_activeIndex >= 0 &&
        oldWidget.lines.length == widget.lines.length &&
        oldWidget.lines[_activeIndex] != widget.lines[_activeIndex]) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToIndex(_activeIndex);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<GlobalKey> _generateKeys(int length) {
    return List<GlobalKey>.generate(length, (_) => GlobalKey());
  }

  Duration? _positionFromState(PlayerBlocState state) {
    if (state is PlayerPlaying) {
      return state.position;
    }
    if (state is PlayerPaused) {
      return state.position;
    }
    if (state is PlayerLoading) {
      return state.position;
    }
    return null;
  }

  void _updateActiveIndex(Duration position) {
    final lines = widget.lines;
    if (lines.isEmpty) {
      if (_activeIndex != -1) {
        widget.onActiveIndexChanged?.call(-1);
        widget.onActiveLineChanged?.call(null);
      }
      return;
    }

    int index = 0;
    for (int i = 0; i < lines.length; i++) {
      final current = lines[i].timestamp;
      final Duration? next = i + 1 < lines.length
          ? lines[i + 1].timestamp
          : null;
      if (position < current) {
        index = math.max(0, i - 1);
        break;
      }
      if (next == null || position < next) {
        index = i;
        break;
      }
    }

    if (index != _activeIndex) {
      final LyricsLine activeLine = lines[index];
      _activeIndex = index;
      widget.onActiveIndexChanged?.call(index);
      widget.onActiveLineChanged?.call(activeLine);
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToIndex(index);
        });
      }
    }
  }

  void _scrollToIndex(int index, {int attempt = 0}) {
    if (!widget.controller.hasClients) {
      _scheduleRetry(index, attempt);
      return;
    }
    if (index < 0 || index >= _itemKeys.length) {
      return;
    }

    final BuildContext? targetContext = _itemKeys[index].currentContext;
    if (targetContext == null) {
      _scrollWithEstimate(index, attempt + 1);
      return;
    }

    final RenderObject? renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _scrollWithEstimate(index, attempt + 1);
      return;
    }

    final ScrollPosition position = widget.controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      _scheduleRetry(index, attempt + 1);
      return;
    }

    final RenderAbstractViewport? viewport = RenderAbstractViewport.of(
      renderObject,
    );
    if (viewport == null) {
      _scrollWithEstimate(index, attempt + 1);
      return;
    }

    final double targetOffset = viewport
        .getOffsetToReveal(renderObject, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((targetOffset - position.pixels).abs() <= 0.5) {
      _verifyCentered(index, attempt + 1);
      return;
    }

    widget.controller
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutQuad,
        )
        .then((_) => _verifyCentered(index, attempt + 1));
  }

  void _scheduleRetry(int index, int attempt) {
    if (attempt > 8) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToIndex(index, attempt: attempt + 1);
    });
  }

  void _verifyCentered(int index, int attempt) {
    if (!mounted || attempt > 8) {
      return;
    }
    if (!widget.controller.hasClients) {
      _scheduleRetry(index, attempt + 1);
      return;
    }
    if (index < 0 || index >= _itemKeys.length) {
      return;
    }

    final BuildContext? targetContext = _itemKeys[index].currentContext;
    if (targetContext == null) {
      _scrollWithEstimate(index, attempt + 1);
      return;
    }

    final RenderObject? renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _scrollWithEstimate(index, attempt + 1);
      return;
    }

    final ScrollPosition position = widget.controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      _scheduleRetry(index, attempt + 1);
      return;
    }

    final RenderAbstractViewport? viewport = RenderAbstractViewport.of(
      renderObject,
    );
    if (viewport == null) {
      _scrollWithEstimate(index, attempt + 1);
      return;
    }

    final double targetOffset = viewport
        .getOffsetToReveal(renderObject, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((targetOffset - position.pixels).abs() <= 0.5) {
      return;
    }

    widget.controller
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutQuad,
        )
        .then((_) => _verifyCentered(index, attempt + 1));
  }

  void _scrollWithEstimate(int index, int attempt) {
    if (!widget.controller.hasClients) {
      _scheduleRetry(index, attempt);
      return;
    }

    final ScrollPosition position = widget.controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      _scheduleRetry(index, attempt);
      return;
    }

    final double viewportHeight = position.viewportDimension;
    if (!viewportHeight.isFinite || viewportHeight <= 0) {
      _scheduleRetry(index, attempt);
      return;
    }

    final double lineExtent =
        _approxLineHeight(context) + _linePadding.vertical;
    final double roughOffset = (viewportHeight / 2) + lineExtent * index;
    final double targetOffset =
        roughOffset - (viewportHeight / 2) + lineExtent / 2;
    final double clamped = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    widget.controller
        .animateTo(
          clamped,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        )
        .then((_) => _verifyCentered(index, attempt + 1));
  }

  TextStyle _baseRenderStyle(BuildContext context) {
    final TextStyle fallback =
        Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    return TextStyle(
      inherit: false,
      fontSize: _activeFontSize,
      fontWeight: FontWeight.w700,
      height: 1.6,
      letterSpacing: fallback.letterSpacing,
      fontFamily: fallback.fontFamily,
    );
  }

  TextStyle _activeTextStyle(BuildContext context) {
    final TextStyle base = _baseRenderStyle(context);
    final Color color = widget.isDarkMode ? Colors.white : Colors.black87;
    return base.copyWith(color: color);
  }

  TextStyle _inactiveTextStyle(BuildContext context) {
    final TextStyle base = _baseRenderStyle(context);
    final Color color = widget.isDarkMode ? Colors.white60 : Colors.black45;
    return base.copyWith(
      fontSize: _inactiveFontSize,
      fontWeight: FontWeight.w400,
      height: 1.55,
      color: color,
    );
  }

  double _computeLineMaxWidth(double maxWidth) {
    final double horizontal = _linePadding.horizontal + _listSidePadding * 2;
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return 540.0;
    }
    return math.max(180.0, maxWidth - horizontal);
  }

  double _approxLineHeight(BuildContext context) {
    final TextStyle style = _baseRenderStyle(context);
    final double fontSize = style.fontSize ?? _activeFontSize;
    final double height = style.height ?? 1.6;
    return fontSize * height;
  }

  String _lineText(LyricsLine line) {
    if (line.originalText.trim().isNotEmpty) {
      return line.originalText.trim();
    }
    if (line.annotatedTexts.isNotEmpty) {
      final StringBuffer buffer = StringBuffer();
      for (final annotated in line.annotatedTexts) {
        buffer.write(annotated.original);
      }
      return buffer.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final double placeholderHeight =
        _approxLineHeight(context) + _linePadding.vertical;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ScrollBehavior behavior = ScrollConfiguration.of(
          context,
        ).copyWith(scrollbars: false);
        final double viewportHeight = constraints.maxHeight.isFinite
            ? math.max(constraints.maxHeight, 1.0)
            : 600.0;
        final double verticalPadding = 0;
        final double lineMaxWidth = _computeLineMaxWidth(constraints.maxWidth);

        final double halfViewport = viewportHeight / 2;
        final double edgeSpacer = halfViewport;

        return BlocListener<PlayerBloc, PlayerBlocState>(
          listener: (context, state) {
            final Duration? position = _positionFromState(state);
            if (position != null) {
              _updateActiveIndex(position);
            }
          },
          child: ScrollConfiguration(
            behavior: behavior,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: ListView.builder(
                controller: widget.controller,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  vertical: verticalPadding,
                  horizontal: _listSidePadding,
                ),
                itemCount: widget.lines.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0 || index == widget.lines.length + 1) {
                    return SizedBox(height: edgeSpacer);
                  }

                  final int lineIndex = index - 1;
                  final LyricsLine line = widget.lines[lineIndex];
                  final bool isActive = lineIndex == _activeIndex;
                  final String text = _lineText(line);
                  final int? relativeIndex =
                      _activeIndex >= 0 ? lineIndex - _activeIndex : null;
                  return _LyricsLineImageTile(
                    key: _itemKeys[lineIndex],
                    text: text,
                    annotatedTexts: line.annotatedTexts,
                    translatedText: widget.showTranslation
                        ? line.translatedText
                        : null,
                    isActive: isActive,
                    linePadding: _linePadding,
                    animationDuration: _animationDuration,
                    lineOffsetFromActive: relativeIndex,
                    activeStyle: _activeTextStyle(context),
                    inactiveStyle: _inactiveTextStyle(context),
                    maxWidth: lineMaxWidth,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LyricsLineImageTile extends StatelessWidget {
  const _LyricsLineImageTile({
    super.key,
    required this.text,
    required this.annotatedTexts,
    required this.translatedText,
    required this.isActive,
    required this.linePadding,
    required this.animationDuration,
    required this.lineOffsetFromActive,
    required this.activeStyle,
    required this.inactiveStyle,
    required this.maxWidth,
  });

  static const List<double> _blurSigmaLevels = <double>[0.0, 1.0, 2.0, 3.0];
  static const double _lineHeightCompressionFactor = 0.75;
  static const double _itemSpacingPadding = 8.0;

  final String text;
  final List<AnnotatedText> annotatedTexts;
  final String? translatedText;
  final bool isActive;
  final EdgeInsets linePadding;
  final Duration animationDuration;
  final int? lineOffsetFromActive;
  final TextStyle activeStyle;
  final TextStyle inactiveStyle;
  final double maxWidth;

  double _resolveBlurSigma() {
    final int? relative = lineOffsetFromActive;
    final int desiredIndex;
    if (relative == null) {
      desiredIndex = _blurSigmaLevels.length - 1;
    } else {
      desiredIndex = relative.abs().clamp(
        0,
        _blurSigmaLevels.length - 1,
      );
    }
    return _blurSigmaLevels[desiredIndex];
  }

  @override
  Widget build(BuildContext context) {
    final double sigma = _resolveBlurSigma();
    final TextStyle targetStyle = isActive ? activeStyle : inactiveStyle;
    final String displayText = text.isEmpty ? ' ' : text;
    final double fontSize = targetStyle.fontSize ?? 16.0;
    final double baseLineHeight = targetStyle.height ?? 1.6;
    final double compressedLineHeight = math.max(
      0.9,
      baseLineHeight * _lineHeightCompressionFactor,
    );

    Widget originalContent;

    if (annotatedTexts.isNotEmpty) {
      final double annotationFontSize = math.max(8.0, fontSize * 0.4);
      final TextStyle annotationStyle = targetStyle.copyWith(
        fontSize: annotationFontSize,
        fontWeight: FontWeight.w500,
        height: 1.0,
        color:
            targetStyle.color?.withOpacity(isActive ? 0.9 : 0.7) ??
            targetStyle.color,
      );

      final double spacing = -math.max(fontSize * 0.32, annotationFontSize * 0.55);

      originalContent = FuriganaText(
        segments: annotatedTexts,
        annotationStyle: annotationStyle,
        textAlign: TextAlign.center,
        maxLines: 4,
        softWrap: true,
        strutStyle: StrutStyle(
          fontSize: fontSize,
          height: compressedLineHeight,
          forceStrutHeight: true,
          leading: 0,
        ),
        annotationSpacing: spacing,
      );
    } else {
      originalContent = Text(
        displayText,
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 4,
        locale: Locale("zh-Hans", "zh"),
        strutStyle: StrutStyle(
          fontSize: fontSize,
          height: compressedLineHeight,
          forceStrutHeight: true,
          leading: 0,
        ),
      );
    }

    Widget composedContent = originalContent;

    final String? translated = translatedText;
    if (translated != null && translated.trim().isNotEmpty) {
      final TextStyle translationStyle = targetStyle.copyWith(
        height: compressedLineHeight,
      );
      final Widget translationWidget = AnimatedDefaultTextStyle(
        style: translationStyle,
        duration: animationDuration,
        curve: Curves.easeInOut,
        child: Text(
          translated.trim(),
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 4,
          locale: Locale("zh-Hans", "zh"),
          strutStyle: StrutStyle(
            fontSize: fontSize,
            height: compressedLineHeight,
            forceStrutHeight: true,
            leading: 0,
          ),
        ),
      );

      composedContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          originalContent,
          const SizedBox(height: 4),
          translationWidget,
        ],
      );
    }

    if (sigma >= 0.01) {
      composedContent = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: composedContent,
      );
    }

    return Padding(
      padding:
          linePadding +
          const EdgeInsets.symmetric(vertical: _itemSpacingPadding),
      child: AnimatedDefaultTextStyle(
        style: targetStyle,
        duration: animationDuration,
        curve: Curves.easeInOut,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Align(alignment: Alignment.center, child: composedContent),
        ),
      ),
    );
  }
}
