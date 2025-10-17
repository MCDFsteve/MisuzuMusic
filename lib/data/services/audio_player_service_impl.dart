import 'dart:async';
import 'dart:convert';

import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/music_entities.dart';
import '../../domain/services/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';

class AudioPlayerServiceImpl implements AudioPlayerService {
  AudioPlayerServiceImpl(this._preferences) {
    _initializeStreams();
    _restoreVolume();
    _restorePlayMode();
  }

  final SharedPreferences _preferences;
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
  DateTime _lastPositionPersistTime = DateTime.fromMillisecondsSinceEpoch(0);

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

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
        unawaited(_persistPosition(position));
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

  void _restoreVolume() {
    final savedVolume = _preferences.getDouble(AppConstants.settingsVolume);
    if (savedVolume != null) {
      _volume = savedVolume.clamp(0.0, 1.0);
      unawaited(_audioPlayer.setVolume(_volume));
    }
  }

  void _restorePlayMode() {
    final savedMode = _preferences.getString(AppConstants.settingsPlayMode);
    if (savedMode == null) {
      return;
    }

    try {
      _playMode = PlayMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => PlayMode.sequence,
      );
    } catch (_) {
      _playMode = PlayMode.sequence;
    }
  }

  Future<void> _persistVolume() async {
    await _preferences.setDouble(AppConstants.settingsVolume, _volume);
  }

  Future<void> _persistPlayMode() async {
    await _preferences.setString(AppConstants.settingsPlayMode, _playMode.name);
  }

  Future<void> _persistQueueState() async {
    if (_queue.isEmpty) {
      await _clearPersistedQueue();
      return;
    }

    final queueJson = jsonEncode(_queue.map(_trackToJson).toList());
    await _preferences.setString(AppConstants.settingsPlaybackQueue, queueJson);
    await _preferences.setInt(AppConstants.settingsPlaybackIndex, _currentIndex);
  }

  Future<void> _persistPosition(Duration position) async {
    final now = DateTime.now();
    if (now.difference(_lastPositionPersistTime).inMilliseconds < 500) {
      return;
    }
    _lastPositionPersistTime = now;
    await _preferences.setInt(
      AppConstants.settingsPlaybackPosition,
      position.inMilliseconds,
    );
  }

  Future<void> _clearPersistedQueue() async {
    await _preferences.remove(AppConstants.settingsPlaybackQueue);
    await _preferences.remove(AppConstants.settingsPlaybackIndex);
    await _preferences.remove(AppConstants.settingsPlaybackPosition);
  }

  Map<String, dynamic> _trackToJson(Track track) {
    return {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'filePath': track.filePath,
      'durationMs': track.duration.inMilliseconds,
      'dateAdded': track.dateAdded.toIso8601String(),
      'artworkPath': track.artworkPath,
      'trackNumber': track.trackNumber,
      'year': track.year,
      'genre': track.genre,
    };
  }

  Track _trackFromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      dateAdded: DateTime.tryParse(json['dateAdded'] as String? ?? '') ?? DateTime.now(),
      artworkPath: json['artworkPath'] as String?,
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
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

      final index = _queue.indexWhere((item) => item.id == track.id);
      if (index != -1) {
        _currentIndex = index;
      }
      await _persistQueueState();
      await _persistPosition(Duration.zero);

      print('🎵 AudioService: 播放命令执行完成');
    } catch (e) {
      print('❌ AudioService: 播放失败 - $e');
      throw AudioPlaybackException('Failed to play track: ${e.toString()}');
    }
  }

  @override
  Future<void> loadTrack(Track track) async {
    try {
      print('🎵 AudioService: 预加载音轨 - ${track.title}');
      _currentTrack = track;
      await _audioPlayer.setFilePath(track.filePath);

      final index = _queue.indexWhere((item) => item.id == track.id);
      if (index != -1) {
        _currentIndex = index;
      }
      await _persistQueueState();
      await _persistPosition(Duration.zero);
    } catch (e) {
      print('❌ AudioService: 预加载音轨失败 - $e');
      throw AudioPlaybackException('Failed to load track: ${e.toString()}');
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
      await _persistPosition(Duration.zero);
    } catch (e) {
      throw AudioPlaybackException('Failed to stop: ${e.toString()}');
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      await _persistPosition(position);
    } catch (e) {
      throw AudioPlaybackException('Failed to seek: ${e.toString()}');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(_volume);
      await _persistVolume();
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
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    print('🎵 AudioService: 设置队列 - ${tracks.length} 首歌曲');
    _queue
      ..clear()
      ..addAll(tracks);

    if (_queue.isEmpty) {
      _currentIndex = 0;
      await _clearPersistedQueue();
      print('🎵 AudioService: 队列已清空');
      return;
    }

    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    await _persistQueueState();
    print('🎵 AudioService: 队列设置完成，当前索引: $_currentIndex');
  }

  @override
  Future<void> addToQueue(Track track) async {
    _queue.add(track);
    await _persistQueueState();
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
      await _persistQueueState();
    }
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
    _currentIndex = 0;
    await _clearPersistedQueue();
  }

  @override
  List<Track> get queue => List.unmodifiable(_queue);

  @override
  int get currentIndex => _currentIndex;

  @override
  Future<void> setPlayMode(PlayMode mode) async {
    _playMode = mode;
    await _persistPlayMode();
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
          await _persistQueueState();
          await play(_queue[_currentIndex]);
        } else {
          await stop();
        }
        break;
      case PlayMode.repeatAll:
        _currentIndex = (_currentIndex + 1) % _queue.length;
        await _persistQueueState();
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.repeatOne:
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.shuffle:
        _currentIndex = _getRandomIndex();
        await _persistQueueState();
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
          await _persistQueueState();
          await play(_queue[_currentIndex]);
        }
        break;
      case PlayMode.repeatOne:
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.shuffle:
        _currentIndex = _getRandomIndex();
        await _persistQueueState();
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
  Future<PlaybackSession?> loadLastSession() async {
    try {
      final queueJson = _preferences.getString(AppConstants.settingsPlaybackQueue);
      if (queueJson == null || queueJson.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(queueJson);
      if (decoded is! List) {
        return null;
      }

      final queue = <Track>[];
      for (final item in decoded) {
        if (item is Map) {
          queue.add(_trackFromJson(Map<String, dynamic>.from(item)));
        }
      }

      if (queue.isEmpty) {
        return null;
      }

      final savedIndex = _preferences.getInt(AppConstants.settingsPlaybackIndex) ?? 0;
      final positionMs =
          _preferences.getInt(AppConstants.settingsPlaybackPosition) ?? 0;
      final savedMode = _preferences.getString(AppConstants.settingsPlayMode);
      final playMode = savedMode != null
          ? () {
              try {
                return PlayMode.values.firstWhere(
                  (mode) => mode.name == savedMode,
                  orElse: () => PlayMode.sequence,
                );
              } catch (_) {
                return PlayMode.sequence;
              }
            }()
          : _playMode;

      final savedVolume =
          (_preferences.getDouble(AppConstants.settingsVolume) ?? _volume)
              .clamp(0.0, 1.0);

      final clampedIndex = queue.isEmpty
          ? 0
          : savedIndex.clamp(0, queue.length - 1);

      final safePositionMs = positionMs < 0 ? 0 : positionMs;

      return PlaybackSession(
        queue: queue,
        currentIndex: clampedIndex,
        position: Duration(milliseconds: safePositionMs),
        playMode: playMode,
        volume: savedVolume,
      );
    } catch (e) {
      print('❌ AudioService: 加载上次播放状态失败 - $e');
      return null;
    }
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
