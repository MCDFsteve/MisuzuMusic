import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/usecases/player_usecases.dart';
import '../../../domain/services/audio_player_service.dart';

// Events
abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

class PlayerPlayTrack extends PlayerEvent {
  final Track track;
  final String? fingerprint;

  const PlayerPlayTrack(this.track, {this.fingerprint});

  @override
  List<Object?> get props => [track, fingerprint];
}

class PlayerPause extends PlayerEvent {
  const PlayerPause();
}

class PlayerResume extends PlayerEvent {
  const PlayerResume();
}

class PlayerStop extends PlayerEvent {
  const PlayerStop();
}

class PlayerSeekTo extends PlayerEvent {
  final Duration position;

  const PlayerSeekTo(this.position);

  @override
  List<Object> get props => [position];
}

class PlayerSetVolume extends PlayerEvent {
  final double volume;

  const PlayerSetVolume(this.volume);

  @override
  List<Object> get props => [volume];
}

class PlayerSkipNext extends PlayerEvent {
  const PlayerSkipNext();
}

class PlayerSkipPrevious extends PlayerEvent {
  const PlayerSkipPrevious();
}

class PlayerSetPlayMode extends PlayerEvent {
  final PlayMode playMode;

  const PlayerSetPlayMode(this.playMode);

  @override
  List<Object> get props => [playMode];
}

class PlayerSetQueue extends PlayerEvent {
  final List<Track> tracks;
  final int? startIndex;
  final bool autoPlay;
  final Duration? initialPosition;

  const PlayerSetQueue(
    this.tracks, {
    this.startIndex,
    this.autoPlay = true,
    this.initialPosition,
  });

  @override
  List<Object?> get props => [tracks, startIndex, autoPlay, initialPosition];
}

class PlayerRestoreLastSession extends PlayerEvent {
  const PlayerRestoreLastSession();
}

class PlayerPositionChanged extends PlayerEvent {
  final Duration position;

  const PlayerPositionChanged(this.position);

  @override
  List<Object> get props => [position];
}

class PlayerDurationChanged extends PlayerEvent {
  final Duration duration;

  const PlayerDurationChanged(this.duration);

  @override
  List<Object> get props => [duration];
}

class PlayerStateChanged extends PlayerEvent {
  final PlayerState playerState;

  const PlayerStateChanged(this.playerState);

  @override
  List<Object> get props => [playerState];
}

// States
abstract class PlayerBlocState extends Equatable {
  const PlayerBlocState();

  @override
  List<Object?> get props => [];
}

class PlayerInitial extends PlayerBlocState {
  const PlayerInitial();
}

class PlayerLoading extends PlayerBlocState {
  final Track? track;
  final Duration position;
  final Duration duration;
  final double volume;
  final PlayMode playMode;
  final List<Track> queue;
  final int currentIndex;

  const PlayerLoading({
    this.track,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.playMode = PlayMode.repeatAll,
    this.queue = const <Track>[],
    this.currentIndex = 0,
  });

  @override
  List<Object?> get props => [
        track,
        position,
        duration,
        volume,
        playMode,
        queue,
        currentIndex,
      ];

  PlayerLoading copyWith({
    Track? track,
    Duration? position,
    Duration? duration,
    double? volume,
    PlayMode? playMode,
    List<Track>? queue,
    int? currentIndex,
  }) {
    return PlayerLoading(
      track: track ?? this.track,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playMode: playMode ?? this.playMode,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class PlayerPlaying extends PlayerBlocState {
  final Track track;
  final Duration position;
  final Duration duration;
  final double volume;
  final PlayMode playMode;
  final List<Track> queue;
  final int currentIndex;

  const PlayerPlaying({
    required this.track,
    required this.position,
    required this.duration,
    required this.volume,
    required this.playMode,
    required this.queue,
    required this.currentIndex,
  });

  @override
  List<Object> get props => [
        track,
        position,
        duration,
        volume,
        playMode,
        queue,
        currentIndex,
      ];

  PlayerPlaying copyWith({
    Track? track,
    Duration? position,
    Duration? duration,
    double? volume,
    PlayMode? playMode,
    List<Track>? queue,
    int? currentIndex,
  }) {
    return PlayerPlaying(
      track: track ?? this.track,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playMode: playMode ?? this.playMode,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class PlayerPaused extends PlayerBlocState {
  final Track track;
  final Duration position;
  final Duration duration;
  final double volume;
  final PlayMode playMode;
  final List<Track> queue;
  final int currentIndex;

  const PlayerPaused({
    required this.track,
    required this.position,
    required this.duration,
    required this.volume,
    required this.playMode,
    required this.queue,
    required this.currentIndex,
  });

  @override
  List<Object> get props => [
        track,
        position,
        duration,
        volume,
        playMode,
        queue,
        currentIndex,
      ];

  PlayerPaused copyWith({
    Track? track,
    Duration? position,
    Duration? duration,
    double? volume,
    PlayMode? playMode,
    List<Track>? queue,
    int? currentIndex,
  }) {
    return PlayerPaused(
      track: track ?? this.track,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playMode: playMode ?? this.playMode,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class PlayerStopped extends PlayerBlocState {
  final double volume;
  final PlayMode playMode;
  final List<Track> queue;

  const PlayerStopped({
    required this.volume,
    required this.playMode,
    required this.queue,
  });

  @override
  List<Object> get props => [volume, playMode, queue];
}

class PlayerError extends PlayerBlocState {
  final String message;

  const PlayerError(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class PlayerBloc extends Bloc<PlayerEvent, PlayerBlocState> {
  final PlayTrack _playTrack;
  final PausePlayer _pausePlayer;
  final ResumePlayer _resumePlayer;
  final StopPlayer _stopPlayer;
  final SeekToPosition _seekToPosition;
  final SetVolume _setVolume;
  final SkipToNext _skipToNext;
  final SkipToPrevious _skipToPrevious;
  final AudioPlayerService _audioPlayerService;

  late StreamSubscription _playerStateSubscription;
  late StreamSubscription _positionSubscription;
  late StreamSubscription _durationSubscription;

  PlayerBloc({
    required PlayTrack playTrack,
    required PausePlayer pausePlayer,
    required ResumePlayer resumePlayer,
    required StopPlayer stopPlayer,
    required SeekToPosition seekToPosition,
    required SetVolume setVolume,
    required SkipToNext skipToNext,
    required SkipToPrevious skipToPrevious,
    required AudioPlayerService audioPlayerService,
  })  : _playTrack = playTrack,
        _pausePlayer = pausePlayer,
        _resumePlayer = resumePlayer,
        _stopPlayer = stopPlayer,
        _seekToPosition = seekToPosition,
        _setVolume = setVolume,
        _skipToNext = skipToNext,
        _skipToPrevious = skipToPrevious,
        _audioPlayerService = audioPlayerService,
        super(const PlayerInitial()) {

    _initializeSubscriptions();

    on<PlayerPlayTrack>(_onPlayTrack);
    on<PlayerPause>(_onPause);
    on<PlayerResume>(_onResume);
    on<PlayerStop>(_onStop);
    on<PlayerSeekTo>(_onSeekTo);
    on<PlayerSetVolume>(_onSetVolume);
    on<PlayerSkipNext>(_onSkipNext);
    on<PlayerSkipPrevious>(_onSkipPrevious);
    on<PlayerSetPlayMode>(_onSetPlayMode);
    on<PlayerSetQueue>(_onSetQueue);
    on<PlayerPositionChanged>(_onPositionChanged);
    on<PlayerDurationChanged>(_onDurationChanged);
    on<PlayerStateChanged>(_onPlayerStateChanged);
    on<PlayerRestoreLastSession>(_onRestoreLastSession);
  }

  void _initializeSubscriptions() {
    _playerStateSubscription = _audioPlayerService.playerStateStream.listen(
      (playerState) => add(PlayerStateChanged(playerState)),
    );

    _positionSubscription = _audioPlayerService.positionStream.listen(
      (position) => add(PlayerPositionChanged(position)),
    );

    _durationSubscription = _audioPlayerService.durationStream.listen(
      (duration) => add(PlayerDurationChanged(duration)),
    );
  }

  Future<void> _onPlayTrack(PlayerPlayTrack event, Emitter<PlayerBlocState> emit) async {
    try {
      print('🎵 PlayerBloc: 开始播放音轨 - ${event.track.title}');
      emit(PlayerLoading(
        track: event.track,
        position: Duration.zero,
        duration: Duration.zero,
        volume: _audioPlayerService.volume,
        playMode: _audioPlayerService.playMode,
        queue: _audioPlayerService.queue,
        currentIndex: _audioPlayerService.currentIndex,
      ));
      await _playTrack(event.track, fingerprint: event.fingerprint);
      print('🎵 PlayerBloc: 播放音轨完成');
    } catch (e) {
      print('❌ PlayerBloc: 播放音轨失败 - $e');
      emit(PlayerError('Failed to play track: ${e.toString()}'));
    }
  }

  Future<void> _onPause(PlayerPause event, Emitter<PlayerBlocState> emit) async {
    try {
      await _pausePlayer();
    } catch (e) {
      emit(PlayerError('Failed to pause: ${e.toString()}'));
    }
  }

  Future<void> _onResume(PlayerResume event, Emitter<PlayerBlocState> emit) async {
    try {
      await _resumePlayer();
    } catch (e) {
      emit(PlayerError('Failed to resume: ${e.toString()}'));
    }
  }

  Future<void> _onStop(PlayerStop event, Emitter<PlayerBlocState> emit) async {
    try {
      await _stopPlayer();
    } catch (e) {
      emit(PlayerError('Failed to stop: ${e.toString()}'));
    }
  }

  Future<void> _onSeekTo(PlayerSeekTo event, Emitter<PlayerBlocState> emit) async {
    try {
      await _seekToPosition(event.position);
    } catch (e) {
      emit(PlayerError('Failed to seek: ${e.toString()}'));
    }
  }

  Future<void> _onSetVolume(PlayerSetVolume event, Emitter<PlayerBlocState> emit) async {
    final targetVolume = event.volume.clamp(0.0, 1.0);
    try {
      await _setVolume(targetVolume);

      final currentState = state;
      if (currentState is PlayerPlaying) {
        emit(currentState.copyWith(volume: targetVolume));
      } else if (currentState is PlayerPaused) {
        emit(currentState.copyWith(volume: targetVolume));
      } else if (currentState is PlayerLoading) {
        emit(currentState.copyWith(volume: targetVolume));
      } else if (currentState is PlayerStopped) {
        emit(PlayerStopped(
          volume: targetVolume,
          playMode: currentState.playMode,
          queue: currentState.queue,
        ));
      }
    } catch (e) {
      emit(PlayerError('Failed to set volume: ${e.toString()}'));
    }
  }

  Future<void> _onSkipNext(PlayerSkipNext event, Emitter<PlayerBlocState> emit) async {
    try {
      await _skipToNext();
    } catch (e) {
      emit(PlayerError('Failed to skip to next: ${e.toString()}'));
    }
  }

  Future<void> _onSkipPrevious(PlayerSkipPrevious event, Emitter<PlayerBlocState> emit) async {
    try {
      await _skipToPrevious();
    } catch (e) {
      emit(PlayerError('Failed to skip to previous: ${e.toString()}'));
    }
  }

  Future<void> _onSetPlayMode(PlayerSetPlayMode event, Emitter<PlayerBlocState> emit) async {
    try {
      await _audioPlayerService.setPlayMode(event.playMode);
      final currentState = state;
      if (currentState is PlayerPlaying) {
        emit(currentState.copyWith(playMode: event.playMode));
      } else if (currentState is PlayerPaused) {
        emit(currentState.copyWith(playMode: event.playMode));
      } else if (currentState is PlayerLoading) {
        emit(currentState.copyWith(playMode: event.playMode));
      } else if (currentState is PlayerStopped) {
        emit(PlayerStopped(
          volume: currentState.volume,
          playMode: event.playMode,
          queue: currentState.queue,
        ));
      }
    } catch (e) {
      emit(PlayerError('Failed to set play mode: ${e.toString()}'));
    }
  }

  Future<void> _onSetQueue(PlayerSetQueue event, Emitter<PlayerBlocState> emit) async {
    try {
      print('🎵 PlayerBloc: 设置播放队列 - ${event.tracks.length} 首歌曲');
      print('🎵 PlayerBloc: 开始索引 - ${event.startIndex}');

      await _audioPlayerService.setQueue(
        event.tracks,
        startIndex: event.startIndex ?? 0,
      );

      if (event.startIndex != null && event.tracks.isNotEmpty) {
        final trackToPlay = event.tracks[event.startIndex!];
        if (event.autoPlay) {
          print('🎵 PlayerBloc: 即将播放歌曲 - ${trackToPlay.title}');
          print('🎵 PlayerBloc: 文件路径 - ${trackToPlay.filePath}');

          await _playTrack(trackToPlay);
          print('🎵 PlayerBloc: 播放命令已发送');
        } else {
          print('🎵 PlayerBloc: 预加载歌曲 - ${trackToPlay.title}');
          await _audioPlayerService.loadTrack(trackToPlay);
          final rawPosition = event.initialPosition ?? Duration.zero;
          final clampedPosition = rawPosition > trackToPlay.duration
              ? trackToPlay.duration
              : rawPosition;
          if (clampedPosition > Duration.zero) {
            await _seekToPosition(clampedPosition);
          }

          emit(PlayerPaused(
            track: trackToPlay,
            position: clampedPosition,
            duration: trackToPlay.duration,
            volume: _audioPlayerService.volume,
            playMode: _audioPlayerService.playMode,
            queue: event.tracks,
            currentIndex: event.startIndex!,
          ));
        }
      }
    } catch (e) {
      print('❌ PlayerBloc: 设置队列失败 - $e');
      emit(PlayerError('Failed to set queue: ${e.toString()}'));
    }
  }

  Future<void> _onRestoreLastSession(
    PlayerRestoreLastSession event,
    Emitter<PlayerBlocState> emit,
  ) async {
    try {
      final session = await _audioPlayerService.loadLastSession();
      final currentVolume = _audioPlayerService.volume;
      final currentPlayMode = _audioPlayerService.playMode;

      if (session == null || session.queue.isEmpty) {
        emit(PlayerStopped(
          volume: currentVolume,
          playMode: currentPlayMode,
          queue: const [],
        ));
        return;
      }

      await _audioPlayerService.setPlayMode(session.playMode);
      await _audioPlayerService.setQueue(
        session.queue,
        startIndex: session.currentIndex,
      );

      final track = session.queue[session.currentIndex];
      await _audioPlayerService.loadTrack(track);

      final clampedPosition = session.position > track.duration
          ? track.duration
          : session.position;

      if (clampedPosition > Duration.zero) {
        await _seekToPosition(clampedPosition);
      }

      emit(PlayerPaused(
        track: track,
        position: clampedPosition,
        duration: track.duration,
        volume: session.volume,
        playMode: session.playMode,
        queue: session.queue,
        currentIndex: session.currentIndex,
      ));
    } catch (e) {
      emit(PlayerStopped(
        volume: _audioPlayerService.volume,
        playMode: _audioPlayerService.playMode,
        queue: const [],
      ));
    }
  }

  void _onPositionChanged(PlayerPositionChanged event, Emitter<PlayerBlocState> emit) {
    final currentState = state;
    if (currentState is PlayerPlaying) {
      emit(currentState.copyWith(position: event.position));
    } else if (currentState is PlayerPaused) {
      emit(currentState.copyWith(position: event.position));
    }
  }

  void _onDurationChanged(PlayerDurationChanged event, Emitter<PlayerBlocState> emit) {
    final currentState = state;
    if (currentState is PlayerPlaying) {
      emit(currentState.copyWith(duration: event.duration));
    } else if (currentState is PlayerPaused) {
      emit(currentState.copyWith(duration: event.duration));
    }
  }

  void _onPlayerStateChanged(PlayerStateChanged event, Emitter<PlayerBlocState> emit) {
    final currentTrack = _audioPlayerService.currentTrack;
    final position = _audioPlayerService.currentPosition;
    final duration = _audioPlayerService.duration;
    final volume = _audioPlayerService.volume;
    final playMode = _audioPlayerService.playMode;
    final queue = _audioPlayerService.queue;
    final currentIndex = _audioPlayerService.currentIndex;

    switch (event.playerState) {
      case PlayerState.playing:
        if (currentTrack != null) {
          emit(PlayerPlaying(
            track: currentTrack,
            position: position,
            duration: duration,
            volume: volume,
            playMode: playMode,
            queue: queue,
            currentIndex: currentIndex,
          ));
        }
        break;
      case PlayerState.paused:
        if (currentTrack != null) {
          emit(PlayerPaused(
            track: currentTrack,
            position: position,
            duration: duration,
            volume: volume,
            playMode: playMode,
            queue: queue,
            currentIndex: currentIndex,
          ));
        }
        break;
      case PlayerState.stopped:
        emit(PlayerStopped(
          volume: volume,
          playMode: playMode,
          queue: queue,
        ));
        break;
      case PlayerState.loading:
        if (currentTrack == null) {
          emit(PlayerLoading(
            track: null,
            position: position,
            duration: duration,
            volume: volume,
            playMode: playMode,
            queue: queue,
            currentIndex: currentIndex,
          ));
        } else {
          final currentState = state;
          if (currentState is PlayerPlaying) {
            emit(
              currentState.copyWith(
                position: position,
                duration: duration,
                volume: volume,
                playMode: playMode,
                queue: queue,
                currentIndex: currentIndex,
              ),
            );
          } else if (currentState is PlayerPaused) {
            emit(
              currentState.copyWith(
                position: position,
                duration: duration,
                volume: volume,
                playMode: playMode,
                queue: queue,
                currentIndex: currentIndex,
              ),
            );
          } else {
            emit(PlayerLoading(
              track: currentTrack,
              position: position,
              duration: duration,
              volume: volume,
              playMode: playMode,
              queue: queue,
              currentIndex: currentIndex,
            ));
          }
        }
        break;
    }
  }

  @override
  Future<void> close() {
    _playerStateSubscription.cancel();
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    return super.close();
  }
}
