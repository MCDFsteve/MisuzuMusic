import '../entities/music_entities.dart';

abstract class PlaybackHistoryRepository {
  Future<void> recordPlay(
    Track track,
    DateTime playedAt, {
    String? fingerprint,
  });
  Future<List<PlaybackHistoryEntry>> getHistory({int limit = 100});
  Stream<List<PlaybackHistoryEntry>> watchHistory({int? limit});
  Future<void> clearHistory();
  Future<void> updateTrackMetadata(Track track);
}
