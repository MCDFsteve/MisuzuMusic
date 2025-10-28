import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/services/desktop_lyrics_bridge.dart';
import 'desktop_lyrics_controller.dart';
import 'desktop_lyrics_parser.dart';
import 'outlined_text.dart';

Future<void> runDesktopLyricsWindow(
  WindowController controller,
  Map<String, dynamic> args,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  Future<void> configureWindow() async {
    const options = WindowOptions(
      size: Size(640, 240),
      minimumSize: Size(320, 160),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setResizable(false);
      await windowManager.show();
      await windowManager.focus();
    });

    unawaited(
      DesktopMultiWindow.invokeMethod(
        0,
        'lyrics_window_ready',
        controller.windowId,
      ),
    );
  }

  DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
    switch (call.method) {
      case 'configure_window':
        await configureWindow();
        break;
      case 'show_window':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'hide_window':
        await windowManager.hide();
        break;
      case 'focus_window':
        await windowManager.focus();
        break;
    }
    return null;
  });

  await configureWindow();

  runApp(
    LyricsWindowApp(
      windowId: controller.windowId,
    ),
  );
}

class LyricsWindowApp extends StatelessWidget {
  const LyricsWindowApp({super.key, required this.windowId});

  final int windowId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: LyricsWindowScreen(windowId: windowId),
    );
  }
}

class LyricsWindowScreen extends StatefulWidget {
  const LyricsWindowScreen({
    super.key,
    required this.windowId,
  });

  final int windowId;

  @override
  State<LyricsWindowScreen> createState() => _LyricsWindowScreenState();
}

class _LyricsWindowScreenState extends State<LyricsWindowScreen>
    with WindowListener {
  final DesktopLyricsStreamController _streamController =
      DesktopLyricsStreamController();
  final DesktopLyricsParser _parser = const DesktopLyricsParser();
  final GlobalKey _contentKey = GlobalKey();
  Size? _lastLogicalSize;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _streamController.initialize();
  }

  void _scheduleResize() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final context = _contentKey.currentContext;
      if (context == null) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final size = box.size;
      const padding = Size(32, 32);
      final targetSize = Size(
        (size.width + padding.width).clamp(280, 1400),
        (size.height + padding.height).clamp(160, 900),
      );

      final last = _lastLogicalSize;
      if (last != null) {
        final widthDiff = (last.width - targetSize.width).abs();
        final heightDiff = (last.height - targetSize.height).abs();
        if (widthDiff < 1 && heightDiff < 1) {
          return;
        }
      }

      _lastLogicalSize = targetSize;
      await windowManager.setSize(targetSize);
    });
  }

  @override
  Future<void> dispose() async {
    windowManager.removeListener(this);
    await _streamController.dispose();
    unawaited(
      DesktopMultiWindow.invokeMethod(
        0,
        'lyrics_window_disposed',
        widget.windowId,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => windowManager.startDragging(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ValueListenableBuilder<DesktopLyricsUpdate?>(
        valueListenable: _streamController.updateNotifier,
        builder: (context, update, _) {
          _scheduleResize();
          return _LyricsContent(
            key: _contentKey,
            update: update,
            parser: _parser,
          );
        },
        ),
      ),
    );
  }

  @override
  Future<bool> onWindowClose() async {
    unawaited(
      DesktopMultiWindow.invokeMethod(
        0,
        'lyrics_window_disposed',
        widget.windowId,
      ),
    );
    return true;
  }
}

class _LyricsContent extends StatelessWidget {
  const _LyricsContent({
    super.key,
    required this.update,
    required this.parser,
  });

  final DesktopLyricsUpdate? update;
  final DesktopLyricsParser parser;

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle = const TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w800,
      height: 1.12,
      color: Colors.white,
    );
    final TextStyle translationStyle = baseStyle.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w600,
    );

    final ParsedLyricsLine parsedActive =
        parser.parse(update?.activeLine ?? '');
    final ParsedLyricsLine parsedNext =
        parser.parse(update?.nextLine ?? '');

    final bool hasActive = parsedActive.hasContent;
    final bool hasNext = parsedNext.hasContent;

    if (!hasActive && !hasNext) {
      return const Center(
        child: OutlinedText(
          text: '歌词加载中',
          fillStyle: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          strokeColor: Colors.black,
          strokeWidth: 2.2,
        ),
      );
    }

    final children = <Widget>[];

    if (hasActive) {
      children.add(
        _buildLine(
          parsedActive,
          baseStyle,
          translationStyle,
        ),
      );
    }

    if (hasNext) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      final nextStyle = baseStyle.copyWith(
        fontSize: baseStyle.fontSize! * 0.68,
        color: Colors.white.withOpacity(0.78),
      );
      final nextTranslation = translationStyle.copyWith(
        fontSize: translationStyle.fontSize! * 0.8,
        color: Colors.white.withOpacity(0.78),
      );
      children.add(
        _buildLine(
          parsedNext,
          nextStyle,
          nextTranslation,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildLine(
    ParsedLyricsLine parsed,
    TextStyle baseStyle,
    TextStyle translationStyle,
  ) {
    final double annotationFontSize =
        (baseStyle.fontSize ?? 40) * 0.42;
    final TextStyle annotationStyle = baseStyle.copyWith(
      fontSize: annotationFontSize,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );

    final Widget lyricBody;
    if (parsed.segments.isEmpty ||
        parsed.segments.every((segment) => segment.annotation.isEmpty)) {
      lyricBody = OutlinedText(
        text: parsed.plain.isEmpty ? ' ' : parsed.plain,
        fillStyle: baseStyle,
        strokeColor: Colors.black,
        strokeWidth: 2.2,
        strutStyle: StrutStyle(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          forceStrutHeight: true,
        ),
      );
    } else {
      lyricBody = OutlinedFuriganaText(
        segments: parsed.segments,
        baseStyle: baseStyle,
        annotationStyle: annotationStyle,
        strokeColor: Colors.black,
        strokeWidth: 2.2,
        textAlign: TextAlign.center,
        maxLines: 3,
        softWrap: true,
        strutStyle: StrutStyle(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          forceStrutHeight: true,
        ),
        annotationSpacing: -math.max(
          (baseStyle.fontSize ?? 40) * 0.32,
          annotationFontSize * 0.6,
        ),
      );
    }

    final translation = parsed.translation;
    if (translation == null || translation.isEmpty) {
      return lyricBody;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        lyricBody,
        const SizedBox(height: 8),
        OutlinedText(
          text: translation,
          fillStyle: translationStyle,
          strokeColor: Colors.black,
          strokeWidth: 1.8,
          strutStyle: StrutStyle(
            fontSize: translationStyle.fontSize,
            height: translationStyle.height,
            forceStrutHeight: true,
          ),
        ),
      ],
    );
  }
}
