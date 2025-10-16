import '../../models/lyrics_models.dart';

abstract class LyricsLocalDataSource {
  // Lyrics operations
  Future<LyricsModel?> getLyricsByTrackId(String trackId);
  Future<void> insertLyrics(LyricsModel lyrics);
  Future<void> updateLyrics(LyricsModel lyrics);
  Future<void> deleteLyrics(String trackId);
  Future<bool> hasLyrics(String trackId);

  // Lyrics settings
  Future<LyricsSettingsModel> getLyricsSettings();
  Future<void> saveLyricsSettings(LyricsSettingsModel settings);
}