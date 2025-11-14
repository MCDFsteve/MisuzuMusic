import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:rxdart/rxdart.dart';
import 'package:crypto/crypto.dart';

import '../../core/constants/mystery_library_constants.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/entities/webdav_entities.dart';
import '../../domain/repositories/playback_history_repository.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../../domain/repositories/netease_repository.dart';
import '../../domain/services/audio_player_service.dart';
import '../../core/error/exceptions.dart';
import '../../core/storage/binary_config_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../core/constants/app_constants.dart' show PlayMode, PlayerState;

class AudioPlayerServiceImpl implements AudioPlayerService {
  AudioPlayerServiceImpl(
    this._configStore,
    this._playbackHistoryRepository,
    this._musicLibraryRepository,
    this._neteaseRepository,
  ) {
    _initializeStreams();
    _restoreVolume();
    _restorePlayMode();
  }

  final BinaryConfigStore _configStore;
  final PlaybackHistoryRepository _playbackHistoryRepository;
  final MusicLibraryRepository _musicLibraryRepository;
  final NeteaseRepository _neteaseRepository;
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const List<Duration> _windowsPlaybackRetryDelays = <Duration>[
    Duration(milliseconds: 24),
    Duration(milliseconds: 80),
  ];

  // State streams
  final BehaviorSubject<PlayerState> _playerStateSubject =
      BehaviorSubject<PlayerState>.seeded(PlayerState.stopped);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Track?> _currentTrackSubject =
      BehaviorSubject<Track?>.seeded(null);
  final BehaviorSubject<List<Track>> _queueSubject =
      BehaviorSubject<List<Track>>.seeded(const []);
  final BehaviorSubject<PlayMode> _playModeSubject =
      BehaviorSubject<PlayMode>.seeded(PlayMode.repeatAll);

  // Queue management
  final List<Track> _queue = [];
  int _currentIndex = 0;
  Track? _currentTrack;
  PlayMode _playMode = PlayMode.repeatAll;
  double _volume = 1.0;
  DateTime _lastPositionPersistTime = DateTime.fromMillisecondsSinceEpoch(0);
  Duration? _pendingRestorePosition;
  bool _restoringSession = false;
  int _activePlayTransitions = 0;

  bool get _hasPendingRestorePosition =>
      _restoringSession && _pendingRestorePosition != null;

  // Shuffle management
  List<int> _shuffleIndexes = []; // 洗牌后的索引列表
  int _shufflePosition = 0; // 当前在洗牌列表中的位置

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  static const bool _enableShuffleDebugLogs = false;

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
            state = playerState.playing
                ? PlayerState.playing
                : PlayerState.paused;
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
        if (_shouldIgnorePositionDuringRestore(position)) {
          return;
        }
        _positionSubject.add(position);
        if (_currentTrack == null) {
          return;
        }
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

  void _updateCurrentTrack(Track? track) {
    _currentTrack = track;
    if (!_currentTrackSubject.isClosed) {
      _currentTrackSubject.add(track);
    }
  }

  void _notifyQueueChanged() {
    if (!_queueSubject.isClosed) {
      _queueSubject.add(List.unmodifiable(_queue));
    }
  }

  void _restoreVolume() {
    final raw = _configStore.getValue<dynamic>(StorageKeys.volume);
    final savedVolume = raw is num ? raw.toDouble() : null;
    if (savedVolume != null) {
      _volume = savedVolume.clamp(0.0, 1.0);
      unawaited(_audioPlayer.setVolume(_volume));
    }
  }

  void _restorePlayMode() {
    final savedMode = _configStore.getValue<String>(StorageKeys.playMode);
    if (savedMode == null) {
      _playModeSubject.add(_playMode);
      return;
    }

    try {
      _playMode = PlayMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => PlayMode.repeatAll,
      );
    } catch (_) {
      _playMode = PlayMode.repeatAll;
    }
    _playModeSubject.add(_playMode);
  }

  Future<void> _persistVolume() async {
    await _configStore.setValue(StorageKeys.volume, _volume);
  }

  Future<void> _persistPlayMode() async {
    await _configStore.setValue(StorageKeys.playMode, _playMode.name);
  }

  Future<void> _persistQueueState() async {
    if (_queue.isEmpty) {
      await _clearPersistedQueue();
      return;
    }

    final queueJson = jsonEncode(_queue.map(_trackToJson).toList());
    await _configStore.setValue(StorageKeys.playbackQueue, queueJson);
    await _configStore.setValue(StorageKeys.playbackQueueIndex, _currentIndex);
  }

  Future<void> _persistPosition(Duration position, {bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _restoringSession &&
        _pendingRestorePosition != null &&
        position.inMilliseconds == 0) {
      return;
    }
    if (!force &&
        now.difference(_lastPositionPersistTime).inMilliseconds < 500) {
      return;
    }
    _lastPositionPersistTime = now;
    await _configStore.setValue(
      StorageKeys.playbackPosition,
      position.inMilliseconds,
    );
  }

  bool _shouldIgnorePositionDuringRestore(Duration position) {
    if (!_hasPendingRestorePosition) {
      return false;
    }

    final pending = _pendingRestorePosition!;
    final diff = (position - pending).inMilliseconds.abs();
    if (diff <= 750) {
      _restoringSession = false;
      _pendingRestorePosition = null;
      return false;
    }

    final pendingMillis = pending.inMilliseconds;
    final looksLikeReset = pendingMillis > 0 && position.inMilliseconds == 0;
    return looksLikeReset;
  }

  Future<void> _clearPersistedQueue() async {
    await _configStore.remove(StorageKeys.playbackQueue);
    await _configStore.remove(StorageKeys.playbackQueueIndex);
    await _configStore.remove(StorageKeys.playbackPosition);
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
      'sourceType': track.sourceType.name,
      'sourceId': track.sourceId,
      'remotePath': track.remotePath,
      'httpHeaders': track.httpHeaders,
      'contentHash': track.contentHash,
    };
  }

  Track _trackFromJson(Map<String, dynamic> json) {
    final sourceTypeRaw = json['sourceType'] as String?;
    final sourceType = sourceTypeRaw == null
        ? TrackSourceType.local
        : TrackSourceType.values.firstWhere(
            (value) => value.name == sourceTypeRaw,
            orElse: () => TrackSourceType.local,
          );
    Map<String, String>? headers;
    final headerRaw = json['httpHeaders'];
    if (headerRaw is Map) {
      headers = headerRaw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(
        milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
      ),
      dateAdded:
          DateTime.tryParse(json['dateAdded'] as String? ?? '') ??
          DateTime.now(),
      artworkPath: json['artworkPath'] as String?,
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      sourceType: sourceType,
      sourceId: json['sourceId'] as String?,
      remotePath: json['remotePath'] as String?,
      httpHeaders: headers,
      contentHash: json['contentHash'] as String?,
    );
  }

  @override
  Future<void> play(Track track, {String? fingerprint}) async {
    _activePlayTransitions++;
    try {
      _restoringSession = false;
      _pendingRestorePosition = null;
      final playableTrack = await _resolvePlayableTrack(
        track,
        fingerprint: fingerprint,
      );

      print('🎵 AudioService: 开始播放 - ${playableTrack.title}');
      print('🎵 AudioService: 文件路径 - ${playableTrack.filePath}');

      _updateCurrentTrack(playableTrack);
      if (!_hasPendingRestorePosition) {
        _positionSubject.add(Duration.zero);
      }
      await _setAudioSource(playableTrack);
      final playFuture = _audioPlayer.play();
      if (Platform.isWindows) {
        unawaited(_ensureWindowsPlaybackStarted(playFuture));
      }
      await playFuture;

      if (playableTrack.sourceType == TrackSourceType.webdav &&
          playableTrack.sourceId != null &&
          playableTrack.remotePath != null) {
        unawaited(
          _musicLibraryRepository.uploadWebDavPlayLog(
            sourceId: playableTrack.sourceId!,
            remotePath: playableTrack.remotePath!,
            trackId: playableTrack.id,
            playedAt: DateTime.now(),
          ),
        );
      }

      final index = _queue.indexWhere(
        (item) => _isSameTrack(item, playableTrack),
      );
      if (index != -1) {
        _currentIndex = index;
      }
      await _persistQueueState();
      if (_restoringSession && _pendingRestorePosition != null) {
      } else {
        await _persistPosition(Duration.zero, force: true);
      }

      print('🎵 AudioService: 播放命令执行完成');
      unawaited(_recordPlayback(playableTrack));
    } catch (e) {
      print('❌ AudioService: 播放失败 - $e');
      if (e is AudioPlaybackException) {
        rethrow;
      }
      throw AudioPlaybackException('Failed to play track: ${e.toString()}');
    } finally {
      if (_activePlayTransitions > 0) {
        _activePlayTransitions--;
      } else {
        _activePlayTransitions = 0;
      }
    }
  }

  @override
  Future<void> loadTrack(Track track, {String? fingerprint}) async {
    try {
      final playableTrack = await _resolvePlayableTrack(
        track,
        fingerprint: fingerprint,
      );

      print('🎵 AudioService: 预加载音轨 - ${playableTrack.title}');
      _updateCurrentTrack(playableTrack);
      if (!_hasPendingRestorePosition) {
        _positionSubject.add(Duration.zero);
      }
      await _setAudioSource(playableTrack);

      final index = _queue.indexWhere(
        (item) => _isSameTrack(item, playableTrack),
      );
      if (index != -1) {
        _currentIndex = index;
      }
      await _persistQueueState();
      if (_restoringSession && _pendingRestorePosition != null) {
      } else {
        await _persistPosition(Duration.zero, force: true);
      }
    } catch (e) {
      print('❌ AudioService: 预加载音轨失败 - $e');
      if (e is AudioPlaybackException) {
        rethrow;
      }
      throw AudioPlaybackException('Failed to load track: ${e.toString()}');
    }
  }

  Future<void> _recordPlayback(Track track) async {
    try {
      final fingerprint = await _computeFingerprint(track);
      await _playbackHistoryRepository.recordPlay(
        track,
        DateTime.now(),
        fingerprint: fingerprint,
      );
    } catch (e) {
      print('⚠️ AudioService: 记录播放历史失败 - $e');
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
      final playFuture = _audioPlayer.play();
      if (Platform.isWindows) {
        unawaited(_ensureWindowsPlaybackStarted(playFuture));
      }
      await playFuture;
    } catch (e) {
      throw AudioPlaybackException('Failed to resume: ${e.toString()}');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _updateCurrentTrack(null);
      _positionSubject.add(Duration.zero);
      await _persistPosition(Duration.zero, force: true);
    } catch (e) {
      throw AudioPlaybackException('Failed to stop: ${e.toString()}');
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      _positionSubject.add(position);
      await _persistPosition(position, force: true);
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
  Stream<Track?> get currentTrackStream => _currentTrackSubject.stream;

  @override
  Stream<List<Track>> get queueStream => _queueSubject.stream;

  @override
  Stream<PlayMode> get playModeStream => _playModeSubject.stream;

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
    _notifyQueueChanged();

    // 重置洗牌状态
    _shuffleIndexes.clear();
    _shufflePosition = 0;

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
    _notifyQueueChanged();
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
      _notifyQueueChanged();
      await _persistQueueState();
    }
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
    _currentIndex = 0;
    _notifyQueueChanged();
    await _clearPersistedQueue();
  }

  @override
  List<Track> get queue => List.unmodifiable(_queue);

  @override
  int get currentIndex => _currentIndex;

  @override
  Future<void> setPlayMode(PlayMode mode) async {
    _playMode = mode;
    _playModeSubject.add(_playMode);
    await _persistPlayMode();
  }

  @override
  PlayMode get playMode => _playMode;

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    switch (_playMode) {
      case PlayMode.repeatAll:
        _currentIndex = (_currentIndex + 1) % _queue.length;
        await _persistQueueState();
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.repeatOne:
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.shuffle:
        _logShuffle('skipToNext()');
        _currentIndex = _getRandomIndex();
        _logShuffle('skipToNext() -> $_currentIndex');
        await _persistQueueState();
        await play(_queue[_currentIndex]);
        break;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    switch (_playMode) {
      case PlayMode.repeatAll:
        if (_queue.length > 1) {
          _currentIndex = (_currentIndex - 1) < 0
              ? _queue.length - 1
              : _currentIndex - 1;
        }
        await _persistQueueState();
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.repeatOne:
        await play(_queue[_currentIndex]);
        break;
      case PlayMode.shuffle:
        _logShuffle('skipToPrevious()');
        _currentIndex = _getPreviousShuffleIndex();
        _logShuffle('skipToPrevious() -> $_currentIndex');
        await _persistQueueState();
        await play(_queue[_currentIndex]);
        break;
    }
  }

  void _handleTrackCompleted() {
    if (_activePlayTransitions > 0) {
      print('⏭️ AudioService: 忽略自动切歌事件（手动切换进行中）');
      return;
    }
    switch (_playMode) {
      case PlayMode.repeatAll:
      case PlayMode.repeatOne:
      case PlayMode.shuffle:
        skipToNext();
        break;
    }
  }

  int _getRandomIndex() {
    if (_queue.length <= 1) return 0;

    _logShuffle(
      '_getRandomIndex() position=$_shufflePosition length=${_shuffleIndexes.length}',
    );

    // 如果洗牌列表为空，重新生成洗牌列表
    if (_shuffleIndexes.isEmpty) {
      _logShuffle('order empty; regenerate');
      _generateShuffleOrder();
    }

    // 如果已播放完，重新生成洗牌列表
    if (_shufflePosition >= _shuffleIndexes.length) {
      _logShuffle('order exhausted; regenerate');
      _generateShuffleOrder();
    }

    // 从洗牌列表中获取下一个索引
    final nextIndex = _shuffleIndexes[_shufflePosition];
    _logShuffle('next index=$nextIndex position=$_shufflePosition');
    _shufflePosition++;
    _logShuffle('advance to $_shufflePosition');

    return nextIndex;
  }

  int _getPreviousShuffleIndex() {
    if (_queue.length <= 1) return 0;

    _logShuffle(
      '_getPreviousShuffleIndex() position=$_shufflePosition length=${_shuffleIndexes.length}',
    );

    // 如果洗牌列表为空，先生成洗牌列表
    if (_shuffleIndexes.isEmpty) {
      _logShuffle('order empty; regenerate');
      _generateShuffleOrder();
      _shufflePosition = _shuffleIndexes.length; // 设置到末尾
      _logShuffle('position set to end $_shufflePosition');
    }

    // 如果可以回退
    if (_shufflePosition > 1) {
      _logShuffle('rewind from $_shufflePosition');
      _shufflePosition -= 2; // 回退到上一个位置
      final prevIndex = _shuffleIndexes[_shufflePosition];
      _logShuffle('previous index=$prevIndex position=$_shufflePosition');
      _shufflePosition++; // 恢复位置，为下次前进做准备
      _logShuffle('restore pointer $_shufflePosition');
      return prevIndex;
    } else {
      _logShuffle('cannot rewind at $_shufflePosition; regenerate');
      // 如果已经是第一首，重新生成洗牌列表并从最后开始
      _generateShuffleOrder();
      _shufflePosition = _shuffleIndexes.length - 1;
      final lastIndex = _shuffleIndexes[_shufflePosition];
      _logShuffle('fallback index=$lastIndex position=$_shufflePosition');
      _shufflePosition++; // 设置为下一个位置
      _logShuffle('advance to $_shufflePosition');
      return lastIndex;
    }
  }

  // 生成洗牌顺序的函数
  void _generateShuffleOrder() {
    if (_queue.isEmpty) return;

    _logShuffle(
      'regenerate order queue=${_queue.length} current=$_currentIndex',
    );

    // 创建索引列表，但排除当前正在播放的歌曲
    _shuffleIndexes = <int>[];
    for (int i = 0; i < _queue.length; i++) {
      if (i != _currentIndex) {
        _shuffleIndexes.add(i);
      }
    }

    // Fisher-Yates 洗牌算法
    final random = Random();
    for (int i = _shuffleIndexes.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = _shuffleIndexes[i];
      _shuffleIndexes[i] = _shuffleIndexes[j];
      _shuffleIndexes[j] = temp;
    }

    _shufflePosition = 0;
    final preview = _shuffleIndexes.take(5).toList();
    _logShuffle(
      'order ready length=${_shuffleIndexes.length} preview=$preview',
    );
  }

  void _logShuffle(String message) {
    if (!_enableShuffleDebugLogs) {
      return;
    }
    // ignore: avoid_print
    print('🔀 Shuffle: $message');
  }

  @override
  Future<PlaybackSession?> loadLastSession() async {
    try {
      await _configStore.init();
      final queueJson = _configStore.getValue<String>(
        StorageKeys.playbackQueue,
      );
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

      final savedIndex =
          (_configStore.getValue<dynamic>(StorageKeys.playbackQueueIndex)
                  as num?)
              ?.toInt() ??
          0;
      final positionMs =
          (_configStore.getValue<dynamic>(StorageKeys.playbackPosition) as num?)
              ?.toInt() ??
          0;
      final savedMode = _configStore.getValue<String>(StorageKeys.playMode);
      final playMode = savedMode != null
          ? () {
              try {
                return PlayMode.values.firstWhere(
                  (mode) => mode.name == savedMode,
                  orElse: () => PlayMode.repeatAll,
                );
              } catch (_) {
                return PlayMode.repeatAll;
              }
            }()
          : _playMode;

      final rawVolume = _configStore.getValue<dynamic>(StorageKeys.volume);
      final savedVolume = (rawVolume is num ? rawVolume.toDouble() : _volume)
          .clamp(0.0, 1.0);

      final clampedIndex = queue.isEmpty
          ? 0
          : savedIndex.clamp(0, queue.length - 1);

      final safePositionMs = positionMs < 0 ? 0 : positionMs;

      if (safePositionMs > 0) {
        _restoringSession = true;
        _pendingRestorePosition = Duration(milliseconds: safePositionMs);
      } else {
        _restoringSession = false;
        _pendingRestorePosition = null;
      }

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
    await _currentTrackSubject.close();
    await _queueSubject.close();
    await _playModeSubject.close();
    await _audioPlayer.dispose();
  }

  Future<Track> _resolvePlayableTrack(
    Track track, {
    String? fingerprint,
  }) async {
    if (track.sourceType == TrackSourceType.webdav ||
        track.filePath.startsWith('webdav://')) {
      var normalized = track;
      if (track.sourceType != TrackSourceType.webdav) {
        normalized = track.copyWith(sourceType: TrackSourceType.webdav);
        await _replaceTrackInQueue(track, normalized);
      }

      final enriched = await _musicLibraryRepository.ensureWebDavTrackMetadata(
        normalized,
      );
      if (enriched != null) {
        await _replaceTrackInQueue(normalized, enriched);
        unawaited(_playbackHistoryRepository.updateTrackMetadata(enriched));
        return enriched;
      }

      return normalized;
    }

    if (track.sourceType == TrackSourceType.mystery ||
        track.filePath.startsWith('mystery://')) {
      var normalized = track;
      if (track.sourceType != TrackSourceType.mystery) {
        normalized = track.copyWith(sourceType: TrackSourceType.mystery);
        await _replaceTrackInQueue(track, normalized);
      }
      return normalized;
    }

    if (track.sourceType == TrackSourceType.netease ||
        track.filePath.startsWith('netease://')) {
      var normalized = track;
      if (track.sourceType != TrackSourceType.netease) {
        normalized = track.copyWith(sourceType: TrackSourceType.netease);
        await _replaceTrackInQueue(track, normalized);
      }
      return normalized;
    }

    final originalFile = File(track.filePath);
    if (await originalFile.exists()) {
      return await _ensureLocalArtwork(track);
    }

    print('⚠️ AudioService: 找不到原音频，尝试定位新的文件 -> ${track.filePath}');

    final candidates = <Track?>[];

    try {
      candidates.add(await _musicLibraryRepository.getTrackById(track.id));
    } catch (e) {
      print('⚠️ AudioService: 通过 ID 查找音轨失败 - $e');
    }

    try {
      candidates.add(await _musicLibraryRepository.findMatchingTrack(track));
    } catch (e) {
      print('⚠️ AudioService: 查找匹配音轨失败 - $e');
    }

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final file = File(candidate.filePath);
      if (await file.exists()) {
        if (fingerprint != null) {
          final candidateFingerprint = await _computeFingerprint(candidate);
          if (candidateFingerprint != null &&
              candidateFingerprint == fingerprint) {
            await _replaceTrackInQueue(track, candidate);
            print('✅ AudioService: 使用指纹匹配音频路径 ${candidate.filePath}');
            return await _ensureLocalArtwork(candidate);
          }
        } else {
          await _replaceTrackInQueue(track, candidate);
          print('✅ AudioService: 使用新的音频路径 ${candidate.filePath}');
          return await _ensureLocalArtwork(candidate);
        }
      }
    }

    if (fingerprint != null) {
      for (final candidate in candidates) {
        if (candidate == null) continue;
        final file = File(candidate.filePath);
        if (!await file.exists()) continue;
        final candidateFingerprint = await _computeFingerprint(candidate);
        if (candidateFingerprint != null &&
            candidateFingerprint == fingerprint) {
          await _replaceTrackInQueue(track, candidate);
          print('✅ AudioService: 使用指纹匹配音频路径 ${candidate.filePath}');
          return await _ensureLocalArtwork(candidate);
        }
      }
    }

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final file = File(candidate.filePath);
      if (await file.exists()) {
        await _replaceTrackInQueue(track, candidate);
        print('✅ AudioService: 使用新的音频路径 ${candidate.filePath}');
        return await _ensureLocalArtwork(candidate);
      }
    }

    throw AudioPlaybackException('Audio file missing: ${track.filePath}');
  }

  Future<void> _replaceTrackInQueue(Track original, Track replacement) async {
    bool changed = false;
    for (int i = 0; i < _queue.length; i++) {
      final candidate = _queue[i];
      if (_isSameTrack(candidate, original)) {
        _queue[i] = replacement;
        if (_currentIndex == i) {
          _updateCurrentTrack(replacement);
        }
        changed = true;
      }
    }

    if (changed) {
      await _persistQueueState();
      _notifyQueueChanged();
    }
  }

  Future<Track> _ensureLocalArtwork(Track track) async {
    if (track.sourceType != TrackSourceType.local) {
      return track;
    }
    if ((track.artworkPath ?? '').isNotEmpty) {
      return track;
    }

    unawaited(_fetchLocalArtworkAsync(track));
    return track;
  }

  Future<void> _fetchLocalArtworkAsync(Track track) async {
    try {
      final updated = await _musicLibraryRepository.fetchArtworkForTrack(track);
      if (updated != null && (updated.artworkPath ?? '').isNotEmpty) {
        await _replaceTrackInQueue(track, updated);
        if (_currentTrack != null && _isSameTrack(_currentTrack!, track)) {
          _updateCurrentTrack(updated);
          _emitPlayerStateSnapshot();
        }
        unawaited(_playbackHistoryRepository.updateTrackMetadata(updated));
      }
    } catch (e) {
      print('⚠️ AudioService: 获取网络歌曲封面失败 -> $e');
    }
  }

  Future<void> _ensureWindowsPlaybackStarted(Future<void> playFuture) async {
    if (!Platform.isWindows) {
      return;
    }

    var playbackCompleted = false;
    playFuture.whenComplete(() {
      playbackCompleted = true;
    });

    for (final delay in _windowsPlaybackRetryDelays) {
      if (playbackCompleted) {
        return;
      }

      await Future<void>.delayed(delay);
      if (playbackCompleted || _audioPlayer.playing) {
        return;
      }

      print('🎧 AudioService: Windows 播放未启动，尝试重新开始');
      unawaited(
        _audioPlayer.play().catchError(
          (error, stackTrace) =>
              print('⚠️ AudioService: Windows 重新播放失败 -> $error'),
        ),
      );
    }

    if (!playbackCompleted && !_audioPlayer.playing) {
      print('⚠️ AudioService: Windows 播放仍未开始，已超过重试次数');
    }
  }

  void _emitPlayerStateSnapshot() {
    if (_playerStateSubject.isClosed) {
      return;
    }
    _playerStateSubject.add(_playerStateSubject.value);
  }

  bool _isSameTrack(Track a, Track b) {
    if (a.id == b.id) return true;
    if (a.sourceType != b.sourceType) return false;
    if (a.sourceType == TrackSourceType.webdav) {
      if (a.sourceId != null &&
          b.sourceId != null &&
          a.sourceId == b.sourceId) {
        if (a.remotePath != null &&
            b.remotePath != null &&
            a.remotePath == b.remotePath) {
          return true;
        }
      }
    }
    if (a.sourceType == TrackSourceType.mystery) {
      if (a.sourceId != null &&
          b.sourceId != null &&
          a.sourceId == b.sourceId) {
        if (a.remotePath != null &&
            b.remotePath != null &&
            a.remotePath == b.remotePath) {
          return true;
        }
      }
    }
    if (a.sourceType == TrackSourceType.netease) {
      if (a.sourceId != null &&
          b.sourceId != null &&
          a.sourceId == b.sourceId) {
        return true;
      }
    }
    if (a.filePath == b.filePath) return true;
    if (a.title.toLowerCase() != b.title.toLowerCase()) return false;
    if (a.artist.toLowerCase() != b.artist.toLowerCase()) return false;
    if (a.album.toLowerCase() != b.album.toLowerCase()) return false;
    return (a.duration - b.duration).inMilliseconds.abs() <= 2000;
  }

  Future<String?> _computeFingerprint(Track track) async {
    try {
      final file = File(track.filePath);
      if (!await file.exists()) {
        return null;
      }
      final stream = file.openRead(0, 10240);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
        if (builder.length >= 10240) {
          break;
        }
      }
      final data = builder.takeBytes();
      if (data.isEmpty) {
        return null;
      }
      final digest = sha1.convert(data);
      return digest.toString();
    } catch (e) {
      print('⚠️ AudioService: 计算指纹失败 - $e');
      return null;
    }
  }

  Future<void> _setAudioSource(Track track) async {
    if (Platform.isWindows && _audioPlayer.playing) {
      try {
        await _audioPlayer.pause();
      } catch (error) {
        print('⚠️ AudioService: Windows 切换音轨前暂停失败 -> $error');
      }
    }

    if (track.sourceType == TrackSourceType.webdav) {
      final streamInfo = await _buildWebDavStreamInfo(track);
      await _audioPlayer.setUrl(
        streamInfo.url.toString(),
        headers: streamInfo.headers,
      );
      return;
    }

    if (track.sourceType == TrackSourceType.mystery ||
        track.filePath.startsWith('mystery://')) {
      final streamInfo = _buildMysteryStreamInfo(track);
      await _audioPlayer.setUrl(
        streamInfo.url.toString(),
        headers: streamInfo.headers,
      );
      return;
    }

    if (track.sourceType == TrackSourceType.netease ||
        track.filePath.startsWith('netease://')) {
      final playable = await _neteaseRepository.ensureTrackStream(track);
      if (playable == null) {
        throw const AudioPlaybackException('网络歌曲暂无法播放');
      }
      await _replaceTrackInQueue(track, playable);
      if (identical(track, _currentTrack)) {
        _updateCurrentTrack(playable);
      }
      await _audioPlayer.setUrl(
        playable.filePath,
        headers: playable.httpHeaders,
      );
      return;
    }

    await _audioPlayer.setFilePath(track.filePath);
  }

  _MysteryStreamInfo _buildMysteryStreamInfo(Track track) {
    final headers = track.httpHeaders;
    final baseUrl =
        headers?[MysteryLibraryConstants.headerBaseUrl] ??
        MysteryLibraryConstants.defaultBaseUrl;
    final code = headers?[MysteryLibraryConstants.headerCode] ?? 'irigas';
    final remote =
        track.remotePath ?? _extractMysteryRelativePath(track.filePath) ?? '/';
    final normalizedRemote = _normalizeRemotePath(remote);
    final baseUri = Uri.parse(baseUrl);
    final uri = baseUri.replace(
      queryParameters: {
        'action': 'stream',
        'code': code,
        'path': normalizedRemote,
      },
    );

    print('🕵️ Mystery: 播放 URL -> ${uri.toString()}');

    unawaited(() async {
      try {
        final client = HttpClient();
        final req = await client.openUrl('GET', uri);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
        req.headers.set(HttpHeaders.userAgentHeader, 'MisuzuMusic/1.0');
        final res = await req.close();
        final previewBytes = await res.fold<List<int>>([], (prev, element) {
          prev.addAll(element);
          return prev;
        });
        print(
          '🕵️ Mystery: 预检状态 -> ${res.statusCode} ${res.reasonPhrase}, '
          'Content-Type: ${res.headers.value(HttpHeaders.contentTypeHeader)}, '
          'Bytes: ${previewBytes.length >= 2 ? previewBytes.sublist(0, 2) : previewBytes}',
        );
        client.close(force: true);
      } catch (e) {
        print('⚠️ Mystery: 预检失败 -> $e');
      }
    }());

    return _MysteryStreamInfo(
      url: uri,
      headers: const {'User-Agent': 'MisuzuMusic/1.0'},
    );
  }

  Future<_WebDavStreamInfo> _buildWebDavStreamInfo(Track track) async {
    final sourceId = track.sourceId;
    if (sourceId == null) {
      throw AudioPlaybackException(
        'WebDAV source missing for track ${track.title}',
      );
    }

    final source = await _musicLibraryRepository.getWebDavSourceById(sourceId);
    if (source == null) {
      throw AudioPlaybackException('WebDAV source not found: $sourceId');
    }

    final password = await _musicLibraryRepository.getWebDavPassword(sourceId);
    if (password == null) {
      throw AudioPlaybackException(
        'WebDAV credentials missing for source $sourceId',
      );
    }

    final uri = _buildWebDavUri(source, track.remotePath ?? '/');

    final headers = <String, String>{'User-Agent': 'MisuzuMusic/1.0'};

    if (track.httpHeaders != null) {
      track.httpHeaders!.forEach((key, value) {
        if (!key.startsWith('x-misuzu-')) {
          headers[key] = value;
        }
      });
    }

    if (source.username != null && source.username!.isNotEmpty) {
      final auth = base64.encode(utf8.encode('${source.username}:$password'));
      headers['Authorization'] = 'Basic $auth';
    }

    return _WebDavStreamInfo(url: uri, headers: headers);
  }

  Uri _buildWebDavUri(WebDavSource source, String trackRemotePath) {
    final baseUri = Uri.parse('${source.baseUrl}/');
    final rootPath = _normalizeRemotePath(source.rootPath);
    final relativePath = _normalizeRemotePath(trackRemotePath);

    String combinedPath;
    if (relativePath == '/') {
      combinedPath = rootPath;
    } else if (rootPath == '/') {
      combinedPath = relativePath;
    } else {
      combinedPath = '$rootPath$relativePath';
    }

    final segments = baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    segments.addAll(
      combinedPath.split('/').where((segment) => segment.isNotEmpty).toList(),
    );

    return baseUri.replace(pathSegments: segments);
  }

  String? _extractMysteryRelativePath(String filePath) {
    const prefix = 'mystery://';
    if (!filePath.startsWith(prefix)) {
      return null;
    }
    final remainder = filePath.substring(prefix.length);
    final slashIndex = remainder.indexOf('/');
    if (slashIndex == -1) {
      return null;
    }
    return remainder.substring(slashIndex);
  }

  String _normalizeRemotePath(String remotePath) {
    var normalized = remotePath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '/';
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

class _WebDavStreamInfo {
  const _WebDavStreamInfo({required this.url, required this.headers});

  final Uri url;
  final Map<String, String> headers;
}

class _MysteryStreamInfo {
  const _MysteryStreamInfo({required this.url, this.headers});

  final Uri url;
  final Map<String, String>? headers;
}
