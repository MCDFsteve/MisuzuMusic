import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  final ValueNotifier<bool> isWindowOpenNotifier = ValueNotifier<bool>(false);

  WindowController? _windowController;
  int? _windowId;
  bool _windowReady = false;
  bool _windowOpening = false;
  bool _stateDirty = false;
  bool _positionDirty = false;

  Track? _currentTrack;
  Lyrics? _currentLyrics;
  Duration _currentPosition = Duration.zero;
  LyricsState _lyricsState = const LyricsInitial();
  bool _showTranslation = true;

  StreamSubscription<Track?>? _trackSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<LyricsState>? _lyricsSubscription;

  Timer? _positionUpdateTimer;
  bool _initialized = false;

  bool get isWindowOpen => _windowController != null;
  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  void _log(String message) {
    debugPrint('🪟 DesktopLyricsController: $message');
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!_isDesktop) {
      _log('当前平台不是桌面平台，忽略桌面歌词初始化');
      return;
    }

    _log('初始化桌面歌词控制器');
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);

    _trackSubscription =
        _audioPlayerService.currentTrackStream.listen(_handleTrackChanged);
    _positionSubscription =
        _audioPlayerService.positionStream.listen(_handlePositionChanged);
    _lyricsSubscription = _lyricsCubit.stream.listen((state) {
      _lyricsState = state;
      if (state is LyricsLoaded) {
        _currentLyrics = state.lyrics;
      } else if (state is LyricsEmpty || state is LyricsError) {
        _currentLyrics = null;
      }
      _pushState();
    });

    final Track? initialTrack = _audioPlayerService.currentTrack;
    if (initialTrack != null) {
      _log('捕获初始曲目 ${initialTrack.title}');
      _handleTrackChanged(initialTrack);
      final Duration initialPosition = _audioPlayerService.currentPosition;
      if (initialPosition > Duration.zero) {
        _log('同步初始播放进度 ${initialPosition.inMilliseconds} ms');
        _handlePositionChanged(initialPosition);
      }
    }
  }

  Future<void> toggleWindow() async {
    if (!_isDesktop) {
      return;
    }
    if (isWindowOpen) {
      _log('尝试关闭桌面歌词窗口');
      await closeWindow();
    } else {
      _log('尝试打开桌面歌词窗口');
      await showWindow();
    }
  }

  Future<void> showWindow() async {
    if (!_isDesktop) {
      return;
    }
    if (_windowOpening || isWindowOpen) {
      return;
    }
    _windowOpening = true;
    try {
      _log('创建桌面歌词子窗口 (platform=${Platform.operatingSystem})');
      final String initialState = jsonEncode(_buildStatePayload());
      final WindowController controller =
          await DesktopMultiWindow.createWindow(
        jsonEncode(<String, dynamic>{
          'entry': 'desktop_lyrics',
          'platform': Platform.operatingSystem,
          'initialState': initialState,
        }),
      );
      _windowController = controller;
      _windowId = controller.windowId;
      _windowReady = false;
      _stateDirty = true;
      _positionDirty = true;
      isWindowOpenNotifier.value = true;
      await controller.setTitle('Misuzu 桌面歌词');
      await controller.show();
      _log('桌面歌词窗口已创建 (id=$_windowId)');
    } on PlatformException catch (error) {
      _log('❌ 无法创建桌面歌词窗口: $error');
      _resetWindowState();
    } finally {
      _windowOpening = false;
    }
  }

  Future<void> closeWindow() async {
    final WindowController? controller = _windowController;
    if (controller == null) {
      return;
    }
    try {
      await controller.close();
    } catch (_) {
      _log('⚠️ 关闭桌面歌词窗口时出现异常，已忽略');
    } finally {
      _resetWindowState();
    }
  }

  void updateShowTranslation(bool show) {
    if (_showTranslation == show) {
      return;
    }
    _showTranslation = show;
    _log('更新翻译显示状态: ${show ? '显示' : '隐藏'}');
    _pushState();
  }

  Future<void> dispose() async {
    _log('销毁桌面歌词控制器');
    await closeWindow();
    await _trackSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _lyricsSubscription?.cancel();
    _positionUpdateTimer?.cancel();
    await _lyricsCubit.close();
    if (_initialized && _isDesktop) {
      DesktopMultiWindow.setMethodHandler(null);
    }
    isWindowOpenNotifier.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int fromWindowId) async {
    if (_windowId == null || fromWindowId != _windowId) {
      return null;
    }

    switch (call.method) {
      case 'desktop_lyrics_ready':
        _log('收到窗口就绪事件');
        _windowReady = true;
        if (_stateDirty) {
          _pushState(force: true);
        }
        if (_positionDirty) {
          _pushPosition(force: true);
        }
        break;
      case 'desktop_lyrics_closed':
        _log('收到窗口关闭事件');
        _resetWindowState();
        break;
      case 'desktop_lyrics_request_state':
        _log('窗口请求同步状态');
        _pushState(force: true);
        _pushPosition(force: true);
        break;
      default:
        _log('收到未知方法: ${call.method}');
        break;
    }

    return null;
  }

  void _handleTrackChanged(Track? track) {
    if (track == null) {
      _log('播放器无曲目，清空歌词状态');
      _currentTrack = null;
      _currentLyrics = null;
      _lyricsState = const LyricsEmpty();
      _pushState();
      return;
    }

    if (_currentTrack == track) {
      return;
    }

    _log('检测到曲目切换 -> ${track.title}');
    _currentTrack = track;
    _currentLyrics = null;
    _lyricsState = const LyricsLoading();
    _pushState();
    _lyricsCubit.loadLyricsForTrack(track);
  }

  void _handlePositionChanged(Duration position) {
    _currentPosition = position;
    if (!isWindowOpen) {
      return;
    }

    _positionDirty = !_windowReady;
    if (_positionUpdateTimer == null) {
      _positionUpdateTimer = Timer(const Duration(milliseconds: 120), () {
        _positionUpdateTimer?.cancel();
        _positionUpdateTimer = null;
        _pushPosition();
      });
    }
  }

  void _pushState({bool force = false}) {
    if (!isWindowOpen || _windowId == null) {
      return;
    }

    if (!_windowReady && !force) {
      _stateDirty = true;
      return;
    }

    _stateDirty = false;
    final payload = _buildStatePayload();
    _log('推送歌词状态到窗口 (lines=${_currentLyrics?.lines.length ?? 0})');
    try {
      DesktopMultiWindow.invokeMethod(
        _windowId!,
        'desktop_lyrics_state',
        payload,
      );
    } catch (error) {
      _log('❌ 推送歌词状态失败: $error');
    }
  }

  void _pushPosition({bool force = false}) {
    if (!isWindowOpen || _windowId == null) {
      return;
    }
    if (!_windowReady && !force) {
      _positionDirty = true;
      return;
    }
    _positionDirty = false;
    try {
      DesktopMultiWindow.invokeMethod(
        _windowId!,
        'desktop_lyrics_position',
        _currentPosition.inMilliseconds,
      );
    } catch (error) {
      _log('❌ 推送播放进度失败: $error');
    }
  }

  void _resetWindowState() {
    _windowController = null;
    _windowId = null;
    _windowReady = false;
    _stateDirty = false;
    _positionDirty = false;
    if (isWindowOpenNotifier.value) {
      isWindowOpenNotifier.value = false;
    }
    _log('重置窗口状态');
  }

  Map<String, dynamic> _buildStatePayload() {
    return <String, dynamic>{
      'track': _serializeTrack(_currentTrack),
      'lyrics': _serializeLyrics(_currentLyrics),
      'lyricsState': _serializeLyricsState(_lyricsState),
      'showTranslation': _showTranslation,
    };
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
}
