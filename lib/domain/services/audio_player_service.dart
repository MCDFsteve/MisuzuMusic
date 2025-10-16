import '../entities/music_entities.dart';
import '../../core/constants/app_constants.dart';

// Audio player service interface
abstract class AudioPlayerService {
  // Playback control
  Future<void> play(Track track);
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
  Track? get currentTrack;
  Duration get currentPosition;
  Duration get duration;
  bool get isPlaying;

  // Queue management
  Future<void> setQueue(List<Track> tracks);
  Future<void> addToQueue(Track track);
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

  // Cleanup
  Future<void> dispose();
}