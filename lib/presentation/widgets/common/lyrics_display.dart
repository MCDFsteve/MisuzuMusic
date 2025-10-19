import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player_bloc.dart';
import '../../../domain/entities/lyrics_entities.dart';
import 'furigana_text.dart';

class LyricsDisplay extends StatefulWidget {
  const LyricsDisplay({
    super.key,
    required this.lines,
    required this.controller,
    required this.isDarkMode,
  });

  final List<LyricsLine> lines;
  final ScrollController controller;
  final bool isDarkMode;

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
  static const double _maxBlurLines = 4.0;

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
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePrimaryScroll);
      widget.controller.addListener(_handlePrimaryScroll);
      _scrollOffsetNotifier.value = widget.controller.hasClients
          ? widget.controller.offset
          : 0;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _activeIndex = index;
        });
        _scrollToIndex(index);
      });
    }
  }

  void _scrollToIndex(int index) {
    if (!widget.controller.hasClients) {
      return;
    }
    if (index < 0 || index >= _itemKeys.length) {
      return;
    }

    final BuildContext? targetContext = _itemKeys[index].currentContext;
    if (targetContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      targetContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutQuad,
    );
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
        final double blurBand = math.min(
          halfViewport,
          placeholderHeight * _maxBlurLines,
        );
        final double sharpDistance = math.max(0.0, halfViewport - blurBand);
        final double blurMaxDistance = halfViewport;
        final double edgeSpacer = math.max(
          0.0,
          halfViewport - placeholderHeight * 0.5,
        );

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
                    isActive: isActive,
                    linePadding: _linePadding,
                    animationDuration: _animationDuration,
                    scrollOffsetListenable: _scrollOffsetNotifier,
                    viewportHeight: viewportHeight,
                    sharpDistance: sharpDistance,
                    blurMaxDistance: blurMaxDistance,
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
    required this.isActive,
    required this.linePadding,
    required this.animationDuration,
    required this.scrollOffsetListenable,
    required this.viewportHeight,
    required this.sharpDistance,
    required this.blurMaxDistance,
    required this.activeStyle,
    required this.inactiveStyle,
    required this.maxWidth,
  });

  final String text;
  final List<AnnotatedText> annotatedTexts;
  final bool isActive;
  final EdgeInsets linePadding;
  final Duration animationDuration;
  final ValueListenable<double> scrollOffsetListenable;
  final double viewportHeight;
  final double sharpDistance;
  final double blurMaxDistance;
  final TextStyle activeStyle;
  final TextStyle inactiveStyle;
  final double maxWidth;

  @override
  State<_LyricsLineImageTile> createState() => _LyricsLineImageTileState();
}

class _LyricsLineImageTileState extends State<_LyricsLineImageTile> {
  static const double _maxSigma = 18.0;

  double _blurFactor = 0.0;

  @override
  void initState() {
    super.initState();
    widget.scrollOffsetListenable.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void didUpdateWidget(covariant _LyricsLineImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollOffsetListenable != widget.scrollOffsetListenable) {
      oldWidget.scrollOffsetListenable.removeListener(_handleScroll);
      widget.scrollOffsetListenable.addListener(_handleScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
    }

    if (oldWidget.isActive != widget.isActive ||
        oldWidget.text != widget.text ||
        oldWidget.viewportHeight != widget.viewportHeight ||
        oldWidget.sharpDistance != widget.sharpDistance ||
        oldWidget.blurMaxDistance != widget.blurMaxDistance) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
    }
  }

  @override
  void dispose() {
    widget.scrollOffsetListenable.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
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
    final RenderObject? scrollRenderObject = scrollable.context
        .findRenderObject();
    if (scrollRenderObject is! RenderBox || !scrollRenderObject.hasSize) {
      return;
    }

    final Offset itemCenterGlobal = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
      ancestor: scrollRenderObject,
    );
    final double centerY = itemCenterGlobal.dy;

    final double halfViewport = widget.viewportHeight / 2;
    final double distanceToCenter = (centerY - halfViewport).abs();

    final double sharp = widget.sharpDistance;
    final double full = widget.blurMaxDistance;

    double nextBlur;
    if (full <= sharp) {
      nextBlur = distanceToCenter > sharp ? 1.0 : 0.0;
    } else if (distanceToCenter <= sharp) {
      nextBlur = 0.0;
    } else if (distanceToCenter >= full) {
      nextBlur = 1.0;
    } else {
      nextBlur = (distanceToCenter - sharp) / (full - sharp);
    }

    nextBlur = nextBlur.clamp(0.0, 1.0);

    if ((nextBlur - _blurFactor).abs() > 0.01) {
      setState(() {
        _blurFactor = nextBlur;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double factor = _blurFactor.clamp(0.0, 1.0);
    final double sigma = math.pow(factor, 1.35).toDouble() * _maxSigma;
    final TextStyle targetStyle = widget.isActive
        ? widget.activeStyle
        : widget.inactiveStyle;
    final String displayText = widget.text.isEmpty ? ' ' : widget.text;
    final double fontSize = targetStyle.fontSize ?? 16.0;
    final double lineHeight = targetStyle.height ?? 1.6;

    Widget content;

    if (widget.annotatedTexts.isNotEmpty) {
      final double annotationFontSize = math.max(8.0, fontSize * 0.4);
      final TextStyle annotationStyle = targetStyle.copyWith(
        fontSize: annotationFontSize,
        fontWeight: FontWeight.w500,
        height: 1.0,
        color:
            targetStyle.color?.withOpacity(widget.isActive ? 0.9 : 0.7) ??
            targetStyle.color,
      );

      final double spacing = -math.max(2.0, annotationFontSize * 0.35);

      content = FuriganaText(
        segments: widget.annotatedTexts,
        annotationStyle: annotationStyle,
        textAlign: TextAlign.center,
        maxLines: 4,
        softWrap: true,
        strutStyle: StrutStyle(
          fontSize: fontSize,
          height: lineHeight,
          forceStrutHeight: true,
          leading: 0,
        ),
        annotationSpacing: spacing,
      );
    } else {
      content = Text(
        displayText,
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 4,
        strutStyle: StrutStyle(
          fontSize: fontSize,
          height: lineHeight,
          forceStrutHeight: true,
          leading: 0,
        ),
      );
    }

    if (sigma >= 0.01) {
      content = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }

    return Padding(
      padding: widget.linePadding,
      child: AnimatedDefaultTextStyle(
        style: targetStyle,
        duration: widget.animationDuration,
        curve: Curves.easeInOut,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: Align(alignment: Alignment.center, child: content),
        ),
      ),
    );
  }
}
