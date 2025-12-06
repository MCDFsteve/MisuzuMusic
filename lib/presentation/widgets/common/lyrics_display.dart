import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
  late final ValueNotifier<double> _scrollOffsetNotifier;

  @override
  void initState() {
    super.initState();
    _itemKeys = _generateKeys(widget.lines.length);
    _scrollOffsetNotifier = ValueNotifier<double>(0);
    widget.controller.addListener(_handlePrimaryScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final PlayerBlocState state = context.read<PlayerBloc>().state;
      final Duration? position = _positionFromState(state);
      if (position != null) {
        _updateActiveIndex(position);
      }
      _scrollOffsetNotifier.value = widget.controller.hasClients
          ? widget.controller.offset
          : 0;
    });
  }

  void _handlePrimaryScroll() {
    if (!widget.controller.hasClients) {
      return;
    }
    _scrollOffsetNotifier.value = widget.controller.offset;
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
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePrimaryScroll);
      widget.controller.addListener(_handlePrimaryScroll);
      _scrollOffsetNotifier.value = widget.controller.hasClients
          ? widget.controller.offset
          : 0;
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
    widget.controller.removeListener(_handlePrimaryScroll);
    _scrollOffsetNotifier.dispose();
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
                    scrollOffsetListenable: _scrollOffsetNotifier,
                    viewportHeight: viewportHeight,
                    lineExtentEstimate:
                        placeholderHeight +
                        _LyricsLineImageTile._itemSpacingPadding * 2,
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

class _LyricsLineImageTile extends StatefulWidget {
  const _LyricsLineImageTile({
    super.key,
    required this.text,
    required this.annotatedTexts,
    required this.translatedText,
    required this.isActive,
    required this.linePadding,
    required this.animationDuration,
    required this.scrollOffsetListenable,
    required this.viewportHeight,
    required this.lineExtentEstimate,
    required this.activeStyle,
    required this.inactiveStyle,
    required this.maxWidth,
  });

  static const List<double> _blurSigmaLevels = <double>[0.0, 1.0, 2.0, 3.0];
  static const double _lineHeightCompressionFactor = 0.75;
  static const double _itemSpacingPadding = 8.0;
  static const double _transitionExtraSigma = 3.5;

  final String text;
  final List<AnnotatedText> annotatedTexts;
  final String? translatedText;
  final bool isActive;
  final EdgeInsets linePadding;
  final Duration animationDuration;
  final ValueListenable<double> scrollOffsetListenable;
  final double viewportHeight;
  final double lineExtentEstimate;
  final TextStyle activeStyle;
  final TextStyle inactiveStyle;
  final double maxWidth;

  @override
  State<_LyricsLineImageTile> createState() => _LyricsLineImageTileState();
}

class _LyricsLineImageTileState extends State<_LyricsLineImageTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _transitionController;
  int _blurLevel = _LyricsLineImageTile._blurSigmaLevels.length - 1;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )
      ..value = 1.0
      ..addListener(_handleTransitionTick);
    widget.scrollOffsetListenable.addListener(_handleScrollChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScrollChange());
  }

  @override
  void didUpdateWidget(covariant _LyricsLineImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _transitionController.duration = widget.animationDuration;
    }
    if (oldWidget.scrollOffsetListenable != widget.scrollOffsetListenable) {
      oldWidget.scrollOffsetListenable.removeListener(_handleScrollChange);
      widget.scrollOffsetListenable.addListener(_handleScrollChange);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleScrollChange());
    }
    if (oldWidget.viewportHeight != widget.viewportHeight ||
        oldWidget.lineExtentEstimate != widget.lineExtentEstimate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleScrollChange());
    }
  }

  @override
  void dispose() {
    _transitionController.removeListener(_handleTransitionTick);
    _transitionController.dispose();
    widget.scrollOffsetListenable.removeListener(_handleScrollChange);
    super.dispose();
  }

  void _handleTransitionTick() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleScrollChange() {
    if (!mounted) {
      return;
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final ScrollableState? scrollable = Scrollable.of(context);
    if (scrollable == null) {
      return;
    }
    final RenderObject? scrollRenderObject = scrollable.context.findRenderObject();
    if (scrollRenderObject is! RenderBox || !scrollRenderObject.hasSize) {
      return;
    }

    final Offset itemCenterGlobal = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
      ancestor: scrollRenderObject,
    );
    final double centerY = itemCenterGlobal.dy;
    final double halfViewport = widget.viewportHeight / 2;
    final double distance = (centerY - halfViewport).abs();

    final double lineExtent = widget.lineExtentEstimate;
    if (lineExtent <= 0) {
      return;
    }

    final double normalized = distance / lineExtent;
    final int maxLevel = _LyricsLineImageTile._blurSigmaLevels.length - 1;
    final int nextLevel = normalized.floor().clamp(0, maxLevel);
    if (nextLevel != _blurLevel) {
      setState(() {
        _blurLevel = nextLevel;
      });
      _triggerBlurTransition();
    }
  }

  double _resolveBlurSigma() {
    final double baseSigma = _LyricsLineImageTile._blurSigmaLevels[_blurLevel];
    final double transitionProgress =
        1.0 - _transitionController.value.clamp(0.0, 1.0);
    if (transitionProgress <= 0.0) {
      return baseSigma;
    }
    final double eased = Curves.easeOut.transform(transitionProgress);
    return baseSigma +
        eased * _LyricsLineImageTile._transitionExtraSigma;
  }

  void _triggerBlurTransition() {
    _transitionController
      ..value = 0.0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final double sigma = _resolveBlurSigma();
    final TextStyle targetStyle =
        widget.isActive ? widget.activeStyle : widget.inactiveStyle;
    final String displayText = widget.text.isEmpty ? ' ' : widget.text;
    final double fontSize = targetStyle.fontSize ?? 16.0;
    final double baseLineHeight = targetStyle.height ?? 1.6;
    final double compressedLineHeight = math.max(
      0.9,
      baseLineHeight * _LyricsLineImageTile._lineHeightCompressionFactor,
    );

    Widget layeredContent = _buildLyricsContent(
      baseStyle: targetStyle,
      overrideStyle: null,
      fontSize: fontSize,
      compressedLineHeight: compressedLineHeight,
      displayText: displayText,
    );

    if (sigma >= 0.01) {
      layeredContent = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: layeredContent,
      );
    }

    return Padding(
      padding: widget.linePadding +
          const EdgeInsets.symmetric(
            vertical: _LyricsLineImageTile._itemSpacingPadding,
          ),
      child: AnimatedDefaultTextStyle(
        style: targetStyle,
        duration: widget.animationDuration,
        curve: Curves.easeInOut,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: Align(alignment: Alignment.center, child: layeredContent),
        ),
      ),
    );
  }

  Widget _buildLyricsContent({
    required TextStyle baseStyle,
    required TextStyle? overrideStyle,
    required double fontSize,
    required double compressedLineHeight,
    required String displayText,
  }) {
    final TextStyle styleForChildren = overrideStyle ?? baseStyle;
    final StrutStyle strutStyle = StrutStyle(
      fontSize: fontSize,
      height: compressedLineHeight,
      forceStrutHeight: true,
      leading: 0,
    );

    Widget originalContent;

    if (widget.annotatedTexts.isNotEmpty) {
      final double annotationFontSize = math.max(8.0, fontSize * 0.4);
      final double annotationBaseOpacity = widget.isActive ? 0.9 : 0.7;
      final double annotationOpacity = overrideStyle != null
          ? math.min(1.0, annotationBaseOpacity * 0.8)
          : annotationBaseOpacity;
      final TextStyle annotationStyle = styleForChildren.copyWith(
        fontSize: annotationFontSize,
        fontWeight: FontWeight.w500,
        height: 1.0,
        color: styleForChildren.color?.withOpacity(annotationOpacity) ??
            styleForChildren.color,
      );

      final double spacing = -math.max(
        fontSize * 0.32,
        annotationFontSize * 0.55,
      );

      originalContent = FuriganaText(
        segments: widget.annotatedTexts,
        baseStyle: overrideStyle,
        annotationStyle: annotationStyle,
        textAlign: TextAlign.center,
        maxLines: 4,
        softWrap: true,
        strutStyle: strutStyle,
        annotationSpacing: spacing,
      );
    } else {
      originalContent = Text(
        displayText,
        style: overrideStyle,
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 4,
        locale: Locale("zh-Hans", "zh"),
        strutStyle: strutStyle,
      );
    }

    final String? translated = widget.translatedText;
    if (translated == null || translated.trim().isEmpty) {
      return originalContent;
    }

    final TextStyle translationStyle = styleForChildren.copyWith(
      height: compressedLineHeight,
    );
    final Widget translationWidget = AnimatedDefaultTextStyle(
      style: translationStyle,
      duration: widget.animationDuration,
      curve: Curves.easeInOut,
      child: Text(
        translated.trim(),
        style: overrideStyle,
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 4,
        locale: Locale("zh-Hans", "zh"),
        strutStyle: strutStyle,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        originalContent,
        const SizedBox(height: 4),
        translationWidget,
      ],
    );
  }
}
