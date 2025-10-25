import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/lyrics_entities.dart';
import '../widgets/common/furigana_text.dart';

void _log(String message) {
  debugPrint('🎛️ DesktopLyricsWindow: $message');
}

Future<void> runDesktopLyricsWindow(
  int windowId,
  Map<String, dynamic> initialArgs,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  _log('启动桌面歌词窗口 (id=$windowId)');

  try {
    await windowManager.ensureInitialized();
  } on MissingPluginException catch (error) {
    _log('❌ window_manager 未注册: $error');
    rethrow;
  }

  const windowOptions = WindowOptions(
    size: Size(560, 240),
    minimumSize: Size(320, 160),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
    _log('窗口创建并已显示');
  });

  runApp(_DesktopLyricsApp(
    windowId: windowId,
    initialArgs: initialArgs,
  ));
}

class _DesktopLyricsApp extends StatefulWidget {
  const _DesktopLyricsApp({
    required this.windowId,
    required this.initialArgs,
  });

  final int windowId;
  final Map<String, dynamic> initialArgs;

  @override
  State<_DesktopLyricsApp> createState() => _DesktopLyricsAppState();
}

class _DesktopLyricsAppState extends State<_DesktopLyricsApp>
    with WindowListener {
  _DesktopTrackInfo? _track;
  List<LyricsLine> _lines = const [];
  LyricsStateDescriptor _lyricsDescriptor = LyricsStateDescriptor.loading;
  String? _lyricsErrorMessage;
  Duration _position = Duration.zero;
  bool _showTranslation = true;
  int _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);
    _log('注册窗口事件监听');
    _applyInitialArgs(widget.initialArgs);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _log('通知主窗口子窗口已准备');
      DesktopMultiWindow.invokeMethod(
        0,
        'desktop_lyrics_ready',
        null,
      );
      DesktopMultiWindow.invokeMethod(
        0,
        'desktop_lyrics_request_state',
        null,
      );
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    DesktopMultiWindow.invokeMethod(0, 'desktop_lyrics_closed', null);
    DesktopMultiWindow.setMethodHandler(null);
    _log('注销窗口事件并关闭');
    super.dispose();
  }

  @override
  void onWindowClose() {
    DesktopMultiWindow.invokeMethod(0, 'desktop_lyrics_closed', null);
    _log('窗口关闭事件');
  }

  Future<dynamic> _handleMethodCall(
    MethodCall call,
    int fromWindowId,
  ) async {
    if (fromWindowId != 0) {
      return null;
    }

    switch (call.method) {
      case 'desktop_lyrics_state':
        if (call.arguments is Map) {
          _log('收到状态推送');
          _applyState(
            Map<String, dynamic>.from(call.arguments as Map),
          );
        }
        break;
      case 'desktop_lyrics_position':
        if (call.arguments is int) {
          _log('收到进度推送: ${call.arguments} ms');
          _applyPosition(Duration(milliseconds: call.arguments as int));
        }
        break;
      default:
        _log('收到未知方法: ${call.method}');
        break;
    }
    return null;
  }

  void _applyInitialArgs(Map<String, dynamic> args) {
    if (args.isEmpty) {
      return;
    }
    _log('应用初始参数');
    final Object? payload = args['initialState'];
    if (payload is String && payload.isNotEmpty) {
      try {
        _log('解析初始状态 JSON');
        _applyState(Map<String, dynamic>.from(jsonDecode(payload))); // ignore: avoid_catches_without_on_clauses
      } catch (_) {}
    } else if (payload is Map) {
      _applyState(Map<String, dynamic>.from(payload as Map));
    }
  }

  void _applyState(Map<String, dynamic> payload) {
    setState(() {
      _track = _parseTrack(payload['track'] as Map?);
      _lines = _parseLines(payload['lyrics'] as Map?);
      _showTranslation = payload['showTranslation'] as bool? ?? true;
      final Map<String, dynamic>? stateMap =
          payload['lyricsState'] as Map<String, dynamic>?;
      final status = stateMap?['status'] as String?;
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
          _lyricsErrorMessage =
              stateMap?['message'] as String? ?? '歌词加载失败';
          break;
        default:
          _lyricsDescriptor = LyricsStateDescriptor.initial;
          _lyricsErrorMessage = null;
      }
      _recomputeActiveIndex();
      _log('更新显示状态，当前激活行: $_activeIndex');
    });
  }

  void _applyPosition(Duration position) {
    if (position == _position) {
      return;
    }
    setState(() {
      _position = position;
      _recomputeActiveIndex();
      _log('刷新定位 -> ${position.inMilliseconds} ms, 激活行 $_activeIndex');
    });
  }

  void _recomputeActiveIndex() {
    if (_lines.isEmpty) {
      _activeIndex = -1;
      return;
    }

    final Duration position = _position;
    int index = 0;
    for (int i = 0; i < _lines.length; i++) {
      final Duration current = _lines[i].timestamp;
      final Duration? next =
          i + 1 < _lines.length ? _lines[i + 1].timestamp : null;
      if (position < current) {
        index = math.max(0, i - 1);
        break;
      }
      if (next == null || position < next) {
        index = i;
        break;
      }
      if (i == _lines.length - 1) {
        index = i;
      }
    }
    _activeIndex = index;
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
      final annotated = (map['annotatedTexts'] as List<dynamic>? ?? [])
          .map((item) {
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
          })
          .toList();
      return LyricsLine(
        timestamp: Duration(milliseconds: map['timestamp'] as int? ?? 0),
        originalText: map['originalText'] as String? ?? '',
        translatedText: map['translatedText'] as String?,
        annotatedTexts: annotated,
      );
    }).toList();
  }

  _DesktopTrackInfo? _parseTrack(Map? raw) {
    if (raw == null) {
      return null;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return _DesktopTrackInfo(
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
    );
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
      theme: theme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      home: GestureDetector(
        onPanStart: (_) => windowManager.startDragging(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final trackTitle = _track?.title ?? '';
    final artist = _track?.artist ?? '';

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
        if (_lines.isEmpty) {
          content = _buildMessage('暂无歌词');
        } else {
          content = _buildLyricsContent();
        }
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (trackTitle.isNotEmpty) ...[
            Opacity(
              opacity: 0.78,
              child: Text(
                trackTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (artist.isNotEmpty)
              Opacity(
                opacity: 0.62,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    artist,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildMessage(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsContent() {
    final LyricsLine? activeLine =
        _activeIndex >= 0 && _activeIndex < _lines.length
            ? _lines[_activeIndex]
            : null;
    final LyricsLine? nextLine =
        _activeIndex + 1 >= 0 && _activeIndex + 1 < _lines.length
            ? _lines[_activeIndex + 1]
            : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _OutlinedLyricsLine(
          line: activeLine,
          highlighted: true,
          showTranslation: _showTranslation,
        ),
        if (nextLine != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: _OutlinedLyricsLine(
              line: nextLine,
              highlighted: false,
              showTranslation: _showTranslation,
            ),
          ),
      ],
    );
  }
}

enum LyricsStateDescriptor { initial, loading, loaded, empty, error }

class _DesktopTrackInfo {
  const _DesktopTrackInfo({
    required this.title,
    required this.artist,
    required this.album,
  });

  final String title;
  final String artist;
  final String album;
}

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
      color: Colors.black,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.28,
      letterSpacing: 0.2,
    );

    final TextStyle strokeStyle = fillStyle.copyWith(
      color: Colors.white,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white
        ..strokeJoin = StrokeJoin.round,
    );

    final TextStyle annotationFillStyle = fillStyle.copyWith(
      fontSize: fontSize * annotationRatio,
      height: 1.0,
      fontWeight: FontWeight.w600,
    );

    final TextStyle annotationStrokeStyle = annotationFillStyle.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, strokeWidth * 0.55)
        ..color = Colors.white
        ..strokeJoin = StrokeJoin.round,
      color: Colors.white,
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
        maxLines: highlighted ? 3 : 2,
      );
    }

    final String? translated =
        showTranslation ? line!.translatedText?.trim() : null;
    final bool hasTranslation = translated != null && translated!.isNotEmpty;

    final List<Widget> children = [original];
    if (hasTranslation) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _OutlinedText(
            text: translated!,
            fillStyle: TextStyle(
              color: Colors.black.withOpacity(highlighted ? 0.85 : 0.6),
              fontSize: highlighted ? 20 : 16,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
            strokeWidth: highlighted ? 3.4 : 2.4,
            maxLines: 3,
          ),
        ),
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: highlighted ? 1.0 : 0.78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _OutlinedText extends StatelessWidget {
  const _OutlinedText({
    required this.text,
    required this.fillStyle,
    required this.strokeWidth,
    required this.maxLines,
  });

  final String text;
  final TextStyle fillStyle;
  final double strokeWidth;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white
      ..strokeJoin = StrokeJoin.round;

    final TextStyle strokeStyle = fillStyle.copyWith(
      color: Colors.white,
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
