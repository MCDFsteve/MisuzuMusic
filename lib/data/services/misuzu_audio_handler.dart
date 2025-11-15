import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/services/audio_player_service.dart';

class MisuzuAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  MisuzuAudioHandler(this._audioPlayerService) {
    _subscriptions.add(
      _audioPlayerService.playerStateStream.listen(_handlePlayerState),
    );
    _subscriptions.add(
      _audioPlayerService.currentTrackStream.listen(_handleTrackChange),
    );
    _subscriptions.add(
      _audioPlayerService.queueStream.listen(_handleQueueChange),
    );
    _subscriptions.add(
      _audioPlayerService.positionStream.listen((_) => _updatePlaybackState()),
    );
    _subscriptions.add(
      _audioPlayerService.playModeStream.listen((_) => _updatePlaybackState()),
    );
  }

  final AudioPlayerService _audioPlayerService;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  PlayerState _latestPlayerState = PlayerState.stopped;
  Track? _latestTrack;
  List<Track> _latestQueue = const [];

  @override
  Future<void> play() async {
    if (_audioPlayerService.currentTrack != null) {
      await _audioPlayerService.resume();
      return;
    }

    final queue = _audioPlayerService.queue;
    if (queue.isNotEmpty) {
      final index = _audioPlayerService.currentIndex.clamp(0, queue.length - 1);
      await _audioPlayerService.play(queue[index]);
    }
  }

  @override
  Future<void> pause() => _audioPlayerService.pause();

  @override
  Future<void> stop() => _audioPlayerService.stop();

  @override
  Future<void> seek(Duration position) => _audioPlayerService.seekTo(position);

  @override
  Future<void> skipToNext() => _audioPlayerService.skipToNext();

  @override
  Future<void> skipToPrevious() => _audioPlayerService.skipToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    final queue = _audioPlayerService.queue;
    if (index < 0 || index >= queue.length) {
      return;
    }
    await _audioPlayerService.play(queue[index]);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final track = _findTrackById(mediaItem.id);
    if (track != null) {
      await _audioPlayerService.play(track);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final track = _findTrackById(mediaItem.id);
    if (track != null) {
      await _audioPlayerService.addToQueue(track);
    }
  }

  Track? _findTrackById(String id) {
    for (final track in _audioPlayerService.queue) {
      if (track.id == id) {
        return track;
      }
    }
    return null;
  }

  void _handlePlayerState(PlayerState state) {
    _latestPlayerState = state;
    _updatePlaybackState();
  }

  void _handleTrackChange(Track? track) {
    _latestTrack = track;
    if (track != null) {
      mediaItem.add(_mapTrackToMediaItem(track));
    } else {
      mediaItem.add(null);
    }
    _updatePlaybackState();
  }

  void _handleQueueChange(List<Track> queueTracks) {
    _latestQueue = queueTracks;
    queue.add(queueTracks.map(_mapTrackToMediaItem).toList(growable: false));
    _updatePlaybackState();
  }

  void _updatePlaybackState() {
    final isPlaying = _latestPlayerState == PlayerState.playing;
    final processingState = _mapProcessingState(_latestPlayerState);
    final controls = <MediaControl>[
      if (_latestQueue.length > 1) MediaControl.skipToPrevious,
      isPlaying ? MediaControl.pause : MediaControl.play,
      MediaControl.stop,
      if (_latestQueue.length > 1) MediaControl.skipToNext,
    ];

    final compactIndices = List<int>.generate(
      controls.length > 3 ? 3 : controls.length,
      (index) => index,
    );

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: compactIndices,
        processingState: processingState,
        playing: isPlaying,
        updatePosition: _audioPlayerService.currentPosition,
        bufferedPosition: _audioPlayerService.currentPosition,
        speed: 1.0,
        queueIndex: _calculateQueueIndex(),
      ),
    );
  }

  int? _calculateQueueIndex() {
    final queue = _audioPlayerService.queue;
    if (queue.isEmpty || _audioPlayerService.currentIndex >= queue.length) {
      return null;
    }
    return _audioPlayerService.currentIndex;
  }

  AudioProcessingState _mapProcessingState(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
      case PlayerState.paused:
        return AudioProcessingState.ready;
      case PlayerState.loading:
        return AudioProcessingState.loading;
      case PlayerState.stopped:
        final hasUpcomingTrack =
            _audioPlayerService.currentTrack != null ||
            (_audioPlayerService.queue.isNotEmpty &&
                _audioPlayerService.currentIndex <
                    _audioPlayerService.queue.length);
        return hasUpcomingTrack
            ? AudioProcessingState.completed
            : AudioProcessingState.idle;
    }
  }

  MediaItem _mapTrackToMediaItem(Track track) {
    final extras = <String, dynamic>{
      'sourceType': track.sourceType.name,
      'filePath': track.filePath,
      'remotePath': track.remotePath,
      'httpHeaders': track.httpHeaders,
    };

    return MediaItem(
      id: track.id,
      title: track.title,
      album: track.album,
      artist: track.artist,
      duration: track.duration,
      artUri: _resolveArtworkUri(track.artworkPath),
      extras: extras,
    );
  }

  Uri? _resolveArtworkUri(String? artworkPath) {
    if (artworkPath == null || artworkPath.isEmpty) {
      return null;
    }

    // 检查是否是网络URL
    if (artworkPath.startsWith('http://') ||
        artworkPath.startsWith('https://')) {
      return Uri.tryParse(artworkPath);
    }

    // 处理本地文件路径
    final file = File(artworkPath);
    if (file.existsSync()) {
      return Uri.file(file.path);
    }

    // 如果本地文件不存在，返回null而不是尝试解析可能无效的URI
    return null;
  }
}
