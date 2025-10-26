import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager_plus/window_manager_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/lyrics_entities.dart';
import '../widgets/common/furigana_text.dart';

Future<void> runDesktopLyricsWindow(
  int windowId,
  Map<String, dynamic> initialState,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManagerPlus.ensureInitialized(windowId);

  final windowOptions = WindowOptions(
    size: Size(560, 240),
    minimumSize: Size(320, 160),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: Platform.isWindows,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await WindowManagerPlus.current.waitUntilReadyToShow(windowOptions, () async {
    await WindowManagerPlus.current.setHasShadow(false);
    await WindowManagerPlus.current.setBackgroundColor(Colors.transparent);
    await WindowManagerPlus.current.show();
    await WindowManagerPlus.current.focus();
  });

  if (Platform.isWindows) {
    await WindowManagerPlus.current.setSkipTaskbar(true);
  } else {
    await WindowManagerPlus.current.setSkipTaskbar(false);
  }
  await WindowManagerPlus.current.setAlwaysOnTop(true);
  await WindowManagerPlus.current.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await WindowManagerPlus.current.setHasShadow(false);
  await WindowManagerPlus.current.setBackgroundColor(Colors.transparent);
  await WindowManagerPlus.current.setTitle('Misuzu 桌面歌词');

  runApp(_DesktopLyricsApp(initialState: initialState));
}

class _DesktopLyricsApp extends StatefulWidget {
  const _DesktopLyricsApp({required this.initialState});

  final Map<String, dynamic> initialState;

  @override
  State<_DesktopLyricsApp> createState() => _DesktopLyricsAppState();
}

class _DesktopLyricsAppState extends State<_DesktopLyricsApp>
    with WindowListener {
  List<LyricsLine> _lines = const [];
  LyricsStateDescriptor _lyricsDescriptor = LyricsStateDescriptor.loading;
  String? _lyricsErrorMessage;
  Duration _position = Duration.zero;
  bool _showTranslation = true;
  int _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    WindowManagerPlus.current.addListener(this);
    _applyInitialState(widget.initialState);
    scheduleMicrotask(() async {
      try {
        await WindowManagerPlus.current.invokeMethodToWindow(
          0,
          'desktop_lyrics_ready',
        );
      } catch (error, stackTrace) {
        debugPrintStack(stackTrace: stackTrace);
      }

      try {
        await WindowManagerPlus.current.invokeMethodToWindow(
          0,
          'desktop_lyrics_request_state',
        );
      } catch (error, stackTrace) {
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  @override
  void dispose() {
    WindowManagerPlus.current.removeListener(this);
    unawaited(
      WindowManagerPlus.current.invokeMethodToWindow(
        0,
        'desktop_lyrics_closed',
      ),
    );
    super.dispose();
  }

  @override
  Future<dynamic> onEventFromWindow(
    String eventName,
    int fromWindowId,
    dynamic arguments,
  ) async {
    if (fromWindowId != 0) {
      return null;
    }

    switch (eventName) {
      case 'desktop_lyrics_state':
        if (arguments is Map) {
          final map = Map<String, dynamic>.from(arguments as Map);
          _applyState(map);
        }
        break;
      case 'desktop_lyrics_position':
        _applyPosition(arguments);
        break;
      default:
    }
    return null;
  }

  void _applyInitialState(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      _lyricsDescriptor = LyricsStateDescriptor.loading;
      return;
    }
    _applyState(payload);
  }

  void _applyState(Map<String, dynamic> payload) {
    setState(() {
      _lines = _parseLines(payload['lyrics'] as Map?);
      _showTranslation = payload['showTranslation'] as bool? ?? true;
      final Duration? incomingPosition = _parseDurationMilliseconds(
        payload['position'],
      );
      if (incomingPosition != null) {
        _position = incomingPosition;
      }
      final int? activeIndexFromPayload = _parseIndex(
        payload['activeLineIndex'],
      );
      final Map<String, dynamic>? stateMap =
          payload['lyricsState'] as Map<String, dynamic>?;
      final String? status = stateMap?['status'] as String?;
      switch (status) {
        case 'initial':
          _lyricsDescriptor = LyricsStateDescriptor.initial;
          _lyricsErrorMessage = null;
          break;
        case 'loading':
          _lyricsDescriptor = LyricsStateDescriptor.loading;
          _lyricsErrorMessage = null;
          break;
        case 'loaded':
          _lyricsDescriptor = LyricsStateDescriptor.loaded;
          _lyricsErrorMessage = null;
          break;
        case 'empty':
          _lyricsDescriptor = LyricsStateDescriptor.empty;
          _lyricsErrorMessage = null;
          break;
        case 'error':
          _lyricsDescriptor = LyricsStateDescriptor.error;
          _lyricsErrorMessage = stateMap?['message'] as String? ?? '歌词加载失败';
          break;
        default:
          _lyricsDescriptor = LyricsStateDescriptor.initial;
          _lyricsErrorMessage = null;
      }
      _updateActiveIndex(preferredIndex: activeIndexFromPayload);
    });
  }

  void _applyPosition(dynamic payload) {
    Duration? nextPosition;
    int? preferredIndex;

    if (payload is int) {
      nextPosition = Duration(milliseconds: payload);
    } else if (payload is Map) {
      final map = Map<String, dynamic>.from(payload as Map);
      nextPosition = _parseDurationMilliseconds(map['position']);
      preferredIndex = _parseIndex(map['activeIndex']);
    }

    if (nextPosition == null) {
      return;
    }

    if (nextPosition == _position && preferredIndex == null) {
      return;
    }

    setState(() {
      _position = nextPosition!;
      _updateActiveIndex(preferredIndex: preferredIndex);
    });
  }

  void _updateActiveIndex({int? preferredIndex}) {
    if (_lines.isEmpty) {
      _activeIndex = -1;
      return;
    }

    if (preferredIndex != null &&
        preferredIndex >= 0 &&
        preferredIndex < _lines.length) {
      _activeIndex = preferredIndex;
      return;
    }

    _activeIndex = _findActiveIndex(_position) ?? -1;
  }

  int? _findActiveIndex(Duration position) {
    if (_lines.isEmpty) {
      return null;
    }

    int index = _lines.length - 1;
    for (int i = 0; i < _lines.length; i++) {
      final Duration current = _lines[i].timestamp;
      final Duration? next = i + 1 < _lines.length
          ? _lines[i + 1].timestamp
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
    return index;
  }

  List<LyricsLine> _parseLines(Map? raw) {
    if (raw == null) {
      return const [];
    }
    final List<dynamic>? rawLines = raw['lines'] as List<dynamic>?;
    if (rawLines == null || rawLines.isEmpty) {
      return const [];
    }
    return rawLines.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      final annotated = (map['annotatedTexts'] as List<dynamic>? ?? []).map((
        item,
      ) {
        final data = Map<String, dynamic>.from(item as Map);
        final typeName = data['type'] as String?;
        final TextType type = TextType.values.firstWhere(
          (value) => value.name == typeName,
          orElse: () => TextType.other,
        );
        return AnnotatedText(
          original: data['original'] as String? ?? '',
          annotation: data['annotation'] as String? ?? '',
          type: type,
        );
      }).toList();
      return LyricsLine(
        timestamp: Duration(milliseconds: map['timestamp'] as int? ?? 0),
        originalText: map['originalText'] as String? ?? '',
        translatedText: map['translatedText'] as String?,
        annotatedTexts: annotated,
      );
    }).toList();
  }

  Duration? _parseDurationMilliseconds(dynamic value) {
    if (value is int) {
      return Duration(milliseconds: value);
    }
    if (value is double) {
      return Duration(milliseconds: value.round());
    }
    if (value is num) {
      return Duration(milliseconds: value.toInt());
    }
    return null;
  }

  int? _parseIndex(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.isNaN ? null : value.round();
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = defaultTargetPlatform == TargetPlatform.windows
        ? 'Microsoft YaHei'
        : null;

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      fontFamily: fontFamily,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: theme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      builder: (context, child) {
        return ColoredBox(
          color: Colors.transparent,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: GestureDetector(
        onPanStart: (_) => WindowManagerPlus.current.startDragging(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    Widget content;
    switch (_lyricsDescriptor) {
      case LyricsStateDescriptor.initial:
      case LyricsStateDescriptor.loading:
        content = _buildMessage('歌词加载中…');
        break;
      case LyricsStateDescriptor.empty:
        content = _buildMessage('暂无歌词');
        break;
      case LyricsStateDescriptor.error:
        content = _buildMessage(_lyricsErrorMessage ?? '歌词加载失败');
        break;
      case LyricsStateDescriptor.loaded:
        content = _lines.isEmpty
            ? _buildMessage('暂无歌词')
            : _buildLyricsContent();
        break;
    }

    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: content,
    );
  }

  Widget _buildMessage(String text) {
    final LyricsLine messageLine = LyricsLine(
      timestamp: Duration.zero,
      originalText: text,
      translatedText: null,
      annotatedTexts: const [],
    );

    return _OutlinedLyricsLine(
      line: messageLine,
      highlighted: true,
      showTranslation: false,
    );
  }

  Widget _buildLyricsContent() {
    final LyricsLine? activeLine =
        _activeIndex >= 0 && _activeIndex < _lines.length
        ? _lines[_activeIndex]
        : null;

    return Center(
      child: _OutlinedLyricsLine(
        line: activeLine,
        highlighted: true,
        showTranslation: _showTranslation,
      ),
    );
  }
}

enum LyricsStateDescriptor { initial, loading, loaded, empty, error }

class _OutlinedLyricsLine extends StatelessWidget {
  const _OutlinedLyricsLine({
    required this.line,
    required this.highlighted,
    required this.showTranslation,
  });

  final LyricsLine? line;
  final bool highlighted;
  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    if (line == null) {
      return const SizedBox.shrink();
    }

    final String mainText = line!.originalText.isNotEmpty
        ? line!.originalText
        : line!.annotatedTexts.map((segment) => segment.original).join();

    final double fontSize = highlighted ? 34 : 24;
    final double strokeWidth = highlighted ? 4.5 : 3.0;
    final double annotationRatio = 0.42;

    final TextStyle fillStyle = TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.28,
      letterSpacing: 0.2,
    );

    final TextStyle strokeStyle = fillStyle.copyWith(
      color: null,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.black.withOpacity(0.75)
        ..strokeJoin = StrokeJoin.round,
    );

    final TextStyle annotationFillStyle = fillStyle.copyWith(
      fontSize: fontSize * annotationRatio,
      height: 1.0,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    final TextStyle annotationStrokeStyle = annotationFillStyle.copyWith(
      color: null,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, strokeWidth * 0.55)
        ..color = Colors.black.withOpacity(0.65)
        ..strokeJoin = StrokeJoin.round,
    );

    Widget original;
    if (line!.annotatedTexts.isNotEmpty) {
      original = Stack(
        alignment: Alignment.center,
        children: [
          FuriganaText(
            segments: line!.annotatedTexts,
            baseStyle: strokeStyle,
            annotationStyle: annotationStrokeStyle,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: highlighted ? 3 : 2,
            strutStyle: StrutStyle(
              forceStrutHeight: true,
              fontSize: fontSize,
              height: 1.28,
            ),
            annotationSpacing: -fontSize * 0.32,
          ),
          FuriganaText(
            segments: line!.annotatedTexts,
            baseStyle: fillStyle,
            annotationStyle: annotationFillStyle,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: highlighted ? 3 : 2,
            strutStyle: StrutStyle(
              forceStrutHeight: true,
              fontSize: fontSize,
              height: 1.28,
            ),
            annotationSpacing: -fontSize * 0.32,
          ),
        ],
      );
    } else {
      original = _OutlinedText(
        text: mainText,
        fillStyle: fillStyle,
        strokeWidth: strokeWidth,
        strokeColor: Colors.black.withOpacity(0.75),
        maxLines: highlighted ? 3 : 2,
      );
    }

    final String? translated = showTranslation
        ? line!.translatedText?.trim()
        : null;
    final bool hasTranslation = translated != null && translated!.isNotEmpty;

    final List<Widget> children = [original];
    if (hasTranslation) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _OutlinedText(
            text: translated!,
            fillStyle: TextStyle(
              color: Colors.white.withOpacity(highlighted ? 0.92 : 0.72),
              fontSize: highlighted ? 20 : 16,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
            strokeWidth: highlighted ? 3.4 : 2.4,
            strokeColor: Colors.black.withOpacity(0.5),
            maxLines: 3,
          ),
        ),
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: highlighted ? 1.0 : 0.78,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _OutlinedText extends StatelessWidget {
  const _OutlinedText({
    required this.text,
    required this.fillStyle,
    required this.strokeWidth,
    required this.maxLines,
    this.strokeColor,
  });

  final String text;
  final TextStyle fillStyle;
  final double strokeWidth;
  final int maxLines;
  final Color? strokeColor;

  @override
  Widget build(BuildContext context) {
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor ?? Colors.white
      ..strokeJoin = StrokeJoin.round;

    final TextStyle strokeStyle = fillStyle.copyWith(
      color: null,
      foreground: strokePaint,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text.isEmpty ? ' ' : text,
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: maxLines,
          style: strokeStyle,
        ),
        Text(
          text.isEmpty ? ' ' : text,
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: maxLines,
          style: fillStyle,
        ),
      ],
    );
  }
}
