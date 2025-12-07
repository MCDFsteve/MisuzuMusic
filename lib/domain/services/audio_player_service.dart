import '../entities/music_entities.dart';
import '../../core/constants/app_constants.dart';

class PlaybackSession {
  const PlaybackSession({
    required this.queue,
    required this.currentIndex,
    required this.position,
    required this.playMode,
    required this.volume,
  });

  final List<Track> queue;
  final int currentIndex;
  final Duration position;
  final PlayMode playMode;
  final double volume;
}

// Audio player service interface
abstract class AudioPlayerService {
  // Playback control
  Future<void> play(Track track, {String? fingerprint});
  Future<void> loadTrack(Track track, {String? fingerprint});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seekTo(Duration position);

  // Volume control
  Future<void> setVolume(double volume);
  double get volume;

  // Playback state
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<Track?> get currentTrackStream;
  Stream<List<Track>> get queueStream;
  Stream<PlayMode> get playModeStream;
  Track? get currentTrack;
  Duration get currentPosition;
  Duration get duration;
  bool get isPlaying;

  // Queue management
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0});
  Future<void> addToQueue(Track track);
  Future<void> addToQueueNext(Track track);
  Future<void> removeFromQueue(int index);
  Future<void> clearQueue();
  List<Track> get queue;
  int get currentIndex;

  // Play mode
  Future<void> setPlayMode(PlayMode mode);
  PlayMode get playMode;

  // Next/Previous
  Future<void> skipToNext();
  Future<void> skipToPrevious();

  // Persistence
  Future<PlaybackSession?> loadLastSession();

  // Cleanup
  Future<void> dispose();
}
