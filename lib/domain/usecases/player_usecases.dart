import '../entities/music_entities.dart';
import '../services/audio_player_service.dart';

class PlayTrack {
  final AudioPlayerService _audioPlayerService;

  PlayTrack(this._audioPlayerService);

  Future<void> call(Track track) async {
    await _audioPlayerService.play(track);
  }
}

class PausePlayer {
  final AudioPlayerService _audioPlayerService;

  PausePlayer(this._audioPlayerService);

  Future<void> call() async {
    await _audioPlayerService.pause();
  }
}

class ResumePlayer {
  final AudioPlayerService _audioPlayerService;

  ResumePlayer(this._audioPlayerService);

  Future<void> call() async {
    await _audioPlayerService.resume();
  }
}

class StopPlayer {
  final AudioPlayerService _audioPlayerService;

  StopPlayer(this._audioPlayerService);

  Future<void> call() async {
    await _audioPlayerService.stop();
  }
}

class SeekToPosition {
  final AudioPlayerService _audioPlayerService;

  SeekToPosition(this._audioPlayerService);

  Future<void> call(Duration position) async {
    await _audioPlayerService.seekTo(position);
  }
}

class SetVolume {
  final AudioPlayerService _audioPlayerService;

  SetVolume(this._audioPlayerService);

  Future<void> call(double volume) async {
    await _audioPlayerService.setVolume(volume);
  }
}

class SkipToNext {
  final AudioPlayerService _audioPlayerService;

  SkipToNext(this._audioPlayerService);

  Future<void> call() async {
    await _audioPlayerService.skipToNext();
  }
}

class SkipToPrevious {
  final AudioPlayerService _audioPlayerService;

  SkipToPrevious(this._audioPlayerService);

  Future<void> call() async {
    await _audioPlayerService.skipToPrevious();
  }
}