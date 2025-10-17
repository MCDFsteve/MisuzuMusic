import 'dart:async';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:rxdart/rxdart.dart';

import '../../domain/entities/music_entities.dart';
import '../../domain/services/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';

class AudioPlayerServiceImpl implements AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State streams
  final BehaviorSubject<PlayerState> _playerStateSubject =
      BehaviorSubject<PlayerState>.seeded(PlayerState.stopped);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);

  // Queue management
  final List<Track> _queue = [];
  int _currentIndex = 0;
  Track? _currentTrack;
  PlayMode _playMode = PlayMode.sequence;
  double _volume = 1.0;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  AudioPlayerServiceImpl() {
    _initializeStreams();
  }

  void _initializeStreams() {
    // Listen to player state changes
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      (playerState) {
        PlayerState state;
        switch (playerState.processingState) {
          case ProcessingState.idle:
            state = PlayerState.stopped;
            break;
          case ProcessingState.loading:
          case ProcessingState.buffering:
            state = PlayerState.loading;
            break;
          case ProcessingState.ready:
            state = playerState.playing ? PlayerState.playing : PlayerState.paused;
            break;
          case ProcessingState.completed:
            state = PlayerState.stopped;
            _handleTrackCompleted();
            break;
        }
        _playerStateSubject.add(state);
      },
      onError: (error) {
        _playerStateSubject.addError(AudioPlaybackException(error.toString()));
      },
    );

    // Listen to position changes
    _positionSubscription = _audioPlayer.positionStream.listen(
      (position) {
        _positionSubject.add(position);
      },
      onError: (error) {
        _positionSubject.addError(AudioPlaybackException(error.toString()));
      },
    );

    // Listen to duration changes
    _durationSubscription = _audioPlayer.durationStream.listen(
      (duration) {
        if (duration != null) {
          _durationSubject.add(duration);
        }
      },
      onError: (error) {
        _durationSubject.addError(AudioPlaybackException(error.toString()));
      },
    );
  }

  @override
  Future<void> play(Track track) async {
    try {
      print('🎵 AudioService: 开始播放 - ${track.title}');
      print('🎵 AudioService: 文件路径 - ${track.filePath}');

      _currentTrack = track;
      await _audioPlayer.setFilePath(track.filePath);
      await _audioPlayer.play();

      print('🎵 AudioService: 播放命令执行完成');
    } catch (e) {
      print('❌ AudioService: 播放失败 - $e');
      throw AudioPlaybackException('Failed to play track: ${e.toString()}');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      throw AudioPlaybackException('Failed to pause: ${e.toString()}');
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      throw AudioPlaybackException('Failed to resume: ${e.toString()}');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _currentTrack = null;
    } catch (e) {
      throw AudioPlaybackException('Failed to stop: ${e.toString()}');
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      throw AudioPlaybackException('Failed to seek: ${e.toString()}');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(_volume);
    } catch (e) {
      throw AudioPlaybackException('Failed to set volume: ${e.toString()}');
    }
  }

  @override
  double get volume => _volume;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;

  @override
  Stream<Duration> get positionStream => _positionSubject.stream;

  @override
  Stream<Duration> get durationStream => _durationSubject.stream;

  @override
  Track? get currentTrack => _currentTrack;

  @override
  Duration get currentPosition => _positionSubject.value;

  @override
  Duration get duration => _durationSubject.value;

  @override
  bool get isPlaying => _playerStateSubject.value == PlayerState.playing;

  @override
  Future<void> setQueue(List<Track> tracks) async {
    print('🎵 AudioService: 设置队列 - ${tracks.length} 首歌曲');
    _queue.clear();
    _queue.addAll(tracks);
    _currentIndex = 0;
    print('🎵 AudioService: 队列设置完成');
  }

  @override
  Future<void> addToQueue(Track track) async {
    _queue.add(track);
  }

  @override
  Future<void> removeFromQueue(int index) async {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
    }
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
    _currentIndex = 0;
  }

  @override
  List<Track> get queue => List.unmodifiable(_queue);

  @override
  int get currentIndex => _currentIndex;

  @override
  Future<void> setPlayMode(PlayMode mode) async {
    _playMode = mode;
  }

  @override
  PlayMode get playMode => _playMode;

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    switch (_playMode) {
      case PlayMode.sequence:
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
          await play(_queue[_currentIndex]);
        } else {
          await stop();
        }
        break;
      case PlayMode.repeatAll:
        _currentIndex = (_currentIndex + 1) % _queue.length;
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.repeatOne:
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.shuffle:
        _currentIndex = _getRandomIndex();
        await play(_queue[_currentIndex]);
        break;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    switch (_playMode) {
      case PlayMode.sequence:
      case PlayMode.repeatAll:
        if (_currentIndex > 0) {
          _currentIndex--;
          await play(_queue[_currentIndex]);
        }
        break;
      case PlayMode.repeatOne:
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.shuffle:
        _currentIndex = _getRandomIndex();
        await play(_queue[_currentIndex]);
        break;
    }
  }

  void _handleTrackCompleted() {
    switch (_playMode) {
      case PlayMode.sequence:
        if (_currentIndex < _queue.length - 1) {
          skipToNext();
        }
        break;
      case PlayMode.repeatAll:
      case PlayMode.repeatOne:
      case PlayMode.shuffle:
        skipToNext();
        break;
    }
  }

  int _getRandomIndex() {
    if (_queue.length <= 1) return 0;

    int newIndex;
    do {
      newIndex = DateTime.now().millisecondsSinceEpoch % _queue.length;
    } while (newIndex == _currentIndex);

    return newIndex;
  }

  @override
  Future<void> dispose() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _audioPlayer.dispose();
  }
}