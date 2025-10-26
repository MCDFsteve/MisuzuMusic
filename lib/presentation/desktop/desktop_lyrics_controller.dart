import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager_plus/window_manager_plus.dart';

import '../../domain/entities/lyrics_entities.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/usecases/lyrics_usecases.dart';
import '../blocs/lyrics/lyrics_cubit.dart';

class DesktopLyricsController {
  DesktopLyricsController({
    required AudioPlayerService audioPlayerService,
    required FindLyricsFile findLyricsFile,
    required LoadLyricsFromFile loadLyricsFromFile,
    required FetchOnlineLyrics fetchOnlineLyrics,
    required GetLyrics getLyrics,
  })  : _audioPlayerService = audioPlayerService,
        _lyricsCubit = LyricsCubit(
          findLyricsFile: findLyricsFile,
          loadLyricsFromFile: loadLyricsFromFile,
          fetchOnlineLyrics: fetchOnlineLyrics,
          getLyrics: getLyrics,
        );

  final AudioPlayerService _audioPlayerService;
  final LyricsCubit _lyricsCubit;
  static const MethodChannel _macosWindowChannel =
      MethodChannel('com.aimessoft.misuzumusic/macos_window');

  final ValueNotifier<bool> isWindowOpenNotifier = ValueNotifier<bool>(false);

  WindowManagerPlus? _lyricsWindow;
  int? _lyricsWindowId;
  bool _windowReady = false;
  bool _windowOpening = false;
  bool _stateDirty = false;
  bool _positionDirty = false;
  bool _windowTransparencySet = false;

  Track? _currentTrack;
  Lyrics? _currentLyrics;
  Duration _currentPosition = Duration.zero;
  LyricsState _lyricsState = const LyricsInitial();
  bool _showTranslation = true;

  StreamSubscription<Track?>? _trackSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<LyricsState>? _lyricsSubscription;

  bool _initialized = false;

  late final _LyricsWindowListener _windowListener;
  bool _listenerRegistered = false;

  bool get isWindowOpen => _lyricsWindowId != null;
  bool get _isDesktopPlatform => Platform.isMacOS || Platform.isWindows;

  void _log(String message) {
    debugPrint('🪟 DesktopLyricsController: $message');
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!_isDesktopPlatform) {
      //_log('当前平台不是桌面平台，忽略桌面歌词初始化');
      return;
    }

    //_log('初始化桌面歌词控制器');

    _windowListener = _LyricsWindowListener(
      handleEventFromWindow: _handleRemoteEvent,
      onWindowClosed: _handleWindowClosed,
    );
    try {
      WindowManagerPlus.current.addListener(_windowListener);
      _listenerRegistered = true;
      //_log('已注册主窗口监听器 (id=${WindowManagerPlus.current.id})');
    } catch (error) {
      //_log('⚠️ 无法注册监听器: $error');
    }

    _trackSubscription = _audioPlayerService.currentTrackStream.listen((track) {
      //_log('Track stream event: ${track?.title}');
      _handleTrackChanged(track);
    });
    _positionSubscription =
        _audioPlayerService.positionStream.listen((position) {
      //_log('Position stream event: ${position.inMilliseconds}ms');
      _handlePositionChanged(position);
    });
    _lyricsSubscription = _lyricsCubit.stream.listen((state) {
      _lyricsState = state;
      if (state is LyricsLoaded) {
        _currentLyrics = state.lyrics;
      } else if (state is LyricsEmpty || state is LyricsError) {
        _currentLyrics = null;
      }
      unawaited(_pushState());
    });

    final Track? initialTrack = _audioPlayerService.currentTrack;
    if (initialTrack != null) {
      //_log('捕获初始曲目 ${initialTrack.title}');
      _handleTrackChanged(initialTrack);
      final Duration initialPosition = _audioPlayerService.currentPosition;
      if (initialPosition > Duration.zero) {
        //_log('同步初始播放进度 ${initialPosition.inMilliseconds} ms');
        _handlePositionChanged(initialPosition);
      }
    }
  }

  Future<void> toggleWindow() async {
    if (!_isDesktopPlatform) {
      return;
    }
    if (isWindowOpen) {
      //_log('尝试关闭桌面歌词窗口');
      await closeWindow();
    } else {
      //_log('尝试打开桌面歌词窗口');
      await showWindow();
    }
  }

  Future<void> showWindow() async {
    if (!_isDesktopPlatform) {
      return;
    }
    if (_windowOpening || isWindowOpen) {
      return;
    }
    _windowOpening = true;
    try {
      final String initialState = jsonEncode(_buildStatePayload());
      final List<String> args = <String>['desktop_lyrics', initialState];
      final WindowManagerPlus? createdWindow =
          await WindowManagerPlus.createWindow(args);
      if (createdWindow == null) {
        //_log('❌ 无法创建桌面歌词窗口: 返回 null');
        return;
      }
      _lyricsWindow = createdWindow;
      _lyricsWindowId = createdWindow.id;
      _windowReady = false;
      _stateDirty = true;
      _positionDirty = true;
      isWindowOpenNotifier.value = true;
      //_log('桌面歌词窗口已创建 (id=$_lyricsWindowId)');
    } on PlatformException catch (error) {
      //_log('❌ 无法创建桌面歌词窗口: $error');
      _resetWindowState();
    } finally {
      _windowOpening = false;
    }
  }

  Future<void> closeWindow() async {
    final WindowManagerPlus? window = _lyricsWindow;
    if (window == null) {
      return;
    }
    try {
      await window.close();
    } catch (error) {
      //_log('⚠️ 关闭桌面歌词窗口时出现异常: $error');
    } finally {
      _resetWindowState();
    }
  }

  void updateShowTranslation(bool show) {
    if (_showTranslation == show) {
      return;
    }
    _showTranslation = show;
    //_log('更新翻译显示状态: ${show ? '显示' : '隐藏'}');
    unawaited(_pushState());
  }

  Future<void> dispose() async {
    //_log('销毁桌面歌词控制器');
    await closeWindow();
    await _trackSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _lyricsSubscription?.cancel();
    await _lyricsCubit.close();
    if (_listenerRegistered) {
      WindowManagerPlus.current.removeListener(_windowListener);
      _listenerRegistered = false;
    }
    isWindowOpenNotifier.dispose();
  }

  Future<void> _handleRemoteEvent(
    String method,
    int fromWindowId,
    dynamic arguments,
  ) async {
    if (_lyricsWindowId == null || fromWindowId != _lyricsWindowId) {
      return;
    }

    switch (method) {
      case 'desktop_lyrics_ready':
        //_log('收到子窗口就绪事件');
        _windowReady = true;
        await _ensureWindowTransparency();
        if (_stateDirty) {
          await _pushState(force: true);
        }
        if (_positionDirty) {
          await _pushPosition(force: true);
        }
        break;
      case 'desktop_lyrics_request_state':
        //_log('子窗口请求状态同步');
        await _ensureWindowTransparency();
        await _pushState(force: true);
        await _pushPosition(force: true);
        break;
      case 'desktop_lyrics_closed':
        //_log('子窗口主动关闭');
        _resetWindowState();
        break;
      default:
        //_log('收到未知子窗口事件: $method');
    }
  }

  void _handleWindowClosed(int windowId) {
    if (_lyricsWindowId == null || windowId != _lyricsWindowId) {
      return;
    }
    //_log('收到窗口关闭事件 (id=$windowId)');
    _resetWindowState();
  }

  void _handleTrackChanged(Track? track) {
    if (track == null) {
      //_log('播放器无曲目，清空歌词状态');
      _currentTrack = null;
      _currentLyrics = null;
      _lyricsState = const LyricsEmpty();
      unawaited(_pushState());
      return;
    }

    if (_currentTrack == track) {
      return;
    }

    //_log('检测到曲目切换 -> ${track.title}');
    _currentTrack = track;
    _currentLyrics = null;
    _lyricsState = const LyricsLoading();
    unawaited(_pushState());
    _lyricsCubit.loadLyricsForTrack(track);
  }

  void _handlePositionChanged(Duration position) {
    _currentPosition = position;
    if (!isWindowOpen) {
      return;
    }

    if (_windowReady) {
      unawaited(_pushPosition());
    } else {
      _positionDirty = true;
    }
  }

  Future<void> _pushState({bool force = false}) async {
    if (!isWindowOpen || _lyricsWindowId == null) {
      return;
    }

    if (!_windowReady && !force) {
      _stateDirty = true;
      return;
    }

    _stateDirty = false;
    final Map<String, dynamic> payload = _buildStatePayload();
    //_log('推送歌词状态到窗口 (lines=${_currentLyrics?.lines.length ?? 0})');
    try {
      await WindowManagerPlus.current.invokeMethodToWindow(
        _lyricsWindowId!,
        'desktop_lyrics_state',
        payload,
      );
    } catch (error) {
      //_log('❌ 推送歌词状态失败: $error');
    }
  }

  Future<void> _pushPosition({bool force = false}) async {
    if (!isWindowOpen || _lyricsWindowId == null) {
      return;
    }
    if (!_windowReady && !force) {
      _positionDirty = true;
      return;
    }
    _positionDirty = false;

    final Duration position = _currentPosition;
    final int positionMs = position.inMilliseconds;
    final int? activeIndex = _computeActiveLineIndex(position);
    //_log('推送播放进度: ${positionMs}ms (index=${activeIndex ?? '-'})');
    try {
      await WindowManagerPlus.current.invokeMethodToWindow(
        _lyricsWindowId!,
        'desktop_lyrics_position',
        activeIndex == null
            ? positionMs
            : <String, dynamic>{
                'position': positionMs,
                'activeIndex': activeIndex,
              },
      );
    } catch (error) {
      //_log('❌ 推送播放进度失败: $error');
    }
  }

  Future<void> _ensureWindowTransparency() async {
    if (!Platform.isMacOS) {
      return;
    }
    if (_lyricsWindowId == null || !_windowReady || _windowTransparencySet) {
      return;
    }
    try {
      debugPrint('🪟 DesktopLyricsController: invoking setTransparent for windowId=$_lyricsWindowId');
      await _macosWindowChannel.invokeMethod(
        'setTransparent',
        <String, dynamic>{'windowId': _lyricsWindowId},
      );
      _windowTransparencySet = true;
      debugPrint('🪟 DesktopLyricsController: setTransparent ok for windowId=$_lyricsWindowId');
    } catch (error, stackTrace) {
      debugPrint('🪟 DesktopLyricsController: setTransparent failed -> $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _resetWindowState() {
    _lyricsWindow = null;
    _lyricsWindowId = null;
    _windowReady = false;
    _stateDirty = false;
    _positionDirty = false;
    _windowTransparencySet = false;
    if (isWindowOpenNotifier.value) {
      isWindowOpenNotifier.value = false;
    }
  }

  Map<String, dynamic>? _serializeTrack(Track? track) {
    if (track == null) {
      return null;
    }
    return <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'duration': track.duration.inMilliseconds,
    };
  }

  Map<String, dynamic>? _serializeLyrics(Lyrics? lyrics) {
    if (lyrics == null) {
      return null;
    }
    return <String, dynamic>{
      'trackId': lyrics.trackId,
      'format': lyrics.format.name,
      'source': lyrics.source.name,
      'lines': lyrics.lines
          .map((line) => <String, dynamic>{
                'timestamp': line.timestamp.inMilliseconds,
                'originalText': line.originalText,
                'translatedText': line.translatedText,
                'annotatedTexts': line.annotatedTexts
                    .map((annotated) => <String, dynamic>{
                          'original': annotated.original,
                          'annotation': annotated.annotation,
                          'type': annotated.type.name,
                        })
                    .toList(),
              })
          .toList(),
    };
  }

  Map<String, dynamic> _serializeLyricsState(LyricsState state) {
    if (state is LyricsInitial) {
      return <String, dynamic>{'status': 'initial'};
    }
    if (state is LyricsLoading) {
      return <String, dynamic>{'status': 'loading'};
    }
    if (state is LyricsLoaded) {
      return <String, dynamic>{'status': 'loaded'};
    }
    if (state is LyricsEmpty) {
      return <String, dynamic>{'status': 'empty'};
    }
    if (state is LyricsError) {
      return <String, dynamic>{
        'status': 'error',
        'message': state.message,
      };
    }
    return <String, dynamic>{'status': 'unknown'};
  }

  Map<String, dynamic> _buildStatePayload() {
    final int? activeLineIndex = _computeActiveLineIndex(_currentPosition);
    return <String, dynamic>{
      'track': _serializeTrack(_currentTrack),
      'lyrics': _serializeLyrics(_currentLyrics),
      'lyricsState': _serializeLyricsState(_lyricsState),
      'showTranslation': _showTranslation,
      'position': _currentPosition.inMilliseconds,
      'activeLineIndex': activeLineIndex,
    };
  }

  int? _computeActiveLineIndex(Duration position) {
    final lyrics = _currentLyrics;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return null;
    }

    int index = lyrics.lines.length - 1;
    for (int i = 0; i < lyrics.lines.length; i++) {
      final current = lyrics.lines[i].timestamp;
      final Duration? next =
          i + 1 < lyrics.lines.length ? lyrics.lines[i + 1].timestamp : null;
      if (position < current) {
        index = i == 0 ? 0 : i - 1;
        break;
      }
      if (next == null || position < next) {
        index = i;
        break;
      }
    }
    return index;
  }
}

class _LyricsWindowListener with WindowListener {
  _LyricsWindowListener({
    required this.handleEventFromWindow,
    required this.onWindowClosed,
  });

  final Future<void> Function(String method, int fromWindowId, dynamic arguments)
      handleEventFromWindow;
  final void Function(int windowId) onWindowClosed;

  @override
  Future<dynamic> onEventFromWindow(
    String eventName,
    int fromWindowId,
    dynamic arguments,
  ) async {
    debugPrint('🪟 DesktopLyricsController: Listener 捕获事件 method=$eventName from=$fromWindowId args=$arguments');
    await handleEventFromWindow(eventName, fromWindowId, arguments);
    return null;
  }

  @override
  void onWindowClose([int? windowId]) {
    if (windowId != null) {
      onWindowClosed(windowId);
    }
  }
}
