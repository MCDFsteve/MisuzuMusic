import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player_bloc.dart';
import '../../../domain/entities/lyrics_entities.dart';
import 'lyrics_line_image_cache.dart';

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
  static const double _pixelRatio = 2.0;
  static const EdgeInsets _linePadding = EdgeInsets.symmetric(
    vertical: 6,
    horizontal: 12,
  );
  static const double _listSidePadding = 4.0;
  static const Duration _animationDuration = Duration(milliseconds: 240);
  static const double _sharpRegionFraction = 0.38;
  static const double _fullBlurFraction = 0.96;

  final LyricsLineImageCache _imageCache = LyricsLineImageCache.instance;

  int _activeIndex = -1;
  late List<GlobalKey> _itemKeys;
  late final ValueNotifier<double> _scrollOffsetNotifier;

  double get _inactiveScale => _inactiveFontSize / _activeFontSize;

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
      alignment: 0.45,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutQuad,
    );
  }

  TextStyle _baseRenderStyle(BuildContext context) {
    final TextStyle fallback =
        Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    return fallback.copyWith(
      fontSize: _activeFontSize,
      fontWeight: FontWeight.w700,
      height: 1.6,
      letterSpacing: fallback.letterSpacing,
      fontFamily: fallback.fontFamily,
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
        final double verticalPadding = constraints.maxHeight.isFinite
            ? math.max(0.0, constraints.maxHeight * 0.22)
            : 120.0;
        final double lineMaxWidth = _computeLineMaxWidth(constraints.maxWidth);
        final LyricsImageRenderConfig renderConfig = LyricsImageRenderConfig(
          maxWidth: lineMaxWidth,
          pixelRatio: _pixelRatio,
          style: _baseRenderStyle(context),
        );

        final double halfViewport = viewportHeight / 2;
        final double sharpDistance = halfViewport * _sharpRegionFraction;
        final double blurMaxDistance = halfViewport * _fullBlurFraction;

        return BlocListener<PlayerBloc, PlayerBlocState>(
          listener: (context, state) {
            final Duration? position = _positionFromState(state);
            if (position != null) {
              _updateActiveIndex(position);
            }
          },
          child: ScrollConfiguration(
            behavior: behavior,
            child: ListView.builder(
              controller: widget.controller,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                vertical: verticalPadding,
                horizontal: _listSidePadding,
              ),
              itemCount: widget.lines.length,
              itemBuilder: (context, index) {
                final LyricsLine line = widget.lines[index];
                final bool isActive = index == _activeIndex;
                final String text = _lineText(line);

                return _LyricsLineImageTile(
                  key: _itemKeys[index],
                  text: text,
                  isActive: isActive,
                  isDarkMode: widget.isDarkMode,
                  cache: _imageCache,
                  renderConfig: renderConfig,
                  inactiveScale: _inactiveScale,
                  linePadding: _linePadding,
                  animationDuration: _animationDuration,
                  placeholderHeight: placeholderHeight,
                  scrollOffsetListenable: _scrollOffsetNotifier,
                  viewportHeight: viewportHeight,
                  sharpDistance: sharpDistance,
                  blurMaxDistance: blurMaxDistance,
                );
              },
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
    required this.isActive,
    required this.isDarkMode,
    required this.cache,
    required this.renderConfig,
    required this.inactiveScale,
    required this.linePadding,
    required this.animationDuration,
    required this.placeholderHeight,
    required this.scrollOffsetListenable,
    required this.viewportHeight,
    required this.sharpDistance,
    required this.blurMaxDistance,
  });

  final String text;
  final bool isActive;
  final bool isDarkMode;
  final LyricsLineImageCache cache;
  final LyricsImageRenderConfig renderConfig;
  final double inactiveScale;
  final EdgeInsets linePadding;
  final Duration animationDuration;
  final double placeholderHeight;
  final ValueListenable<double> scrollOffsetListenable;
  final double viewportHeight;
  final double sharpDistance;
  final double blurMaxDistance;

  @override
  State<_LyricsLineImageTile> createState() => _LyricsLineImageTileState();
}

class _LyricsLineImageTileState extends State<_LyricsLineImageTile> {
  static const double _maxSigma = 16.0;

  double _blurFactor = 0.0;
  late Future<_LyricsTileResources> _resourcesFuture;

  @override
  void initState() {
    super.initState();
    _resourcesFuture = _loadResources(widget.text, widget.renderConfig);
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

    if (oldWidget.text != widget.text ||
        oldWidget.renderConfig.maxWidth != widget.renderConfig.maxWidth ||
        oldWidget.renderConfig.pixelRatio != widget.renderConfig.pixelRatio ||
        oldWidget.renderConfig.style != widget.renderConfig.style) {
      _resourcesFuture = _loadResources(widget.text, widget.renderConfig);
    }

    if (oldWidget.isActive != widget.isActive) {
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

  Color _resolveBaseColor() {
    final Color activeColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final Color inactiveColor = widget.isDarkMode
        ? Colors.white60
        : Colors.black45;
    return widget.isActive ? activeColor : inactiveColor;
  }

  Future<_LyricsTileResources> _loadResources(
    String text,
    LyricsImageRenderConfig config,
  ) async {
    final RenderedLyricsLine data = await widget.cache.resolve(
      text: text.isEmpty ? ' ' : text,
      config: config,
    );
    final ui.FragmentProgram program = await _LyricsBlurProgram.instance();
    return _LyricsTileResources(data: data, program: program);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LyricsTileResources>(
      future: _resourcesFuture,
      builder: (context, snapshot) {
        final double scale = widget.isActive ? 1.0 : widget.inactiveScale;
        final double fallbackHeight = widget.placeholderHeight * scale;

        Widget child;
        if (!snapshot.hasData) {
          child = SizedBox(height: fallbackHeight);
        } else {
          final _LyricsTileResources resources = snapshot.data!;
          final RenderedLyricsLine data = resources.data;
          final Color baseColor = _resolveBaseColor();
          final double sigma = _blurFactor.clamp(0.0, 1.0) * _maxSigma;
          final Size outputSize = Size(
            data.logicalSize.width * scale,
            data.logicalSize.height * scale,
          );

          final Color color = baseColor;
          WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());

          child = AnimatedContainer(
            duration: widget.animationDuration,
            curve: Curves.easeInOut,
            width: outputSize.width,
            height: outputSize.height,
            child: CustomPaint(
              size: outputSize,
              painter: _LyricsImageShaderPainter(
                program: resources.program,
                image: data.image,
                outputSize: outputSize,
                sigma: sigma,
                color: color,
              ),
            ),
          );
        }

        return Padding(
          padding: widget.linePadding,
          child: SizedBox(
            width: double.infinity,
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _LyricsTileResources {
  const _LyricsTileResources({required this.data, required this.program});

  final RenderedLyricsLine data;
  final ui.FragmentProgram program;
}

class _LyricsBlurProgram {
  const _LyricsBlurProgram._();

  static ui.FragmentProgram? _cached;

  static Future<ui.FragmentProgram> instance() async {
    final ui.FragmentProgram? existing = _cached;
    if (existing != null) {
      return existing;
    }
    final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
      'shaders/lyrics_blur.frag',
    );
    _cached = program;
    return program;
  }
}

class _LyricsImageShaderPainter extends CustomPainter {
  _LyricsImageShaderPainter({
    required this.program,
    required this.image,
    required this.outputSize,
    required this.sigma,
    required this.color,
  });

  final ui.FragmentProgram program;
  final ui.Image image;
  final Size outputSize;
  final double sigma;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.FragmentShader shader = program.fragmentShader();
    shader.setImageSampler(0, image);
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, image.width.toDouble());
    shader.setFloat(3, image.height.toDouble());
    shader.setFloat(4, sigma);
    shader.setFloat(5, color.red / 255.0);
    shader.setFloat(6, color.green / 255.0);
    shader.setFloat(7, color.blue / 255.0);
    shader.setFloat(8, color.alpha / 255.0);

    final Paint paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _LyricsImageShaderPainter oldDelegate) {
    return identical(oldDelegate.program, program) == false ||
        oldDelegate.image != image ||
        oldDelegate.outputSize != outputSize ||
        (oldDelegate.sigma - sigma).abs() > 0.01 ||
        oldDelegate.color != color;
  }
}
