import '../entities/lyrics_entities.dart';

// Repository interface for lyrics operations
abstract class LyricsRepository {
  // Get lyrics for a track
  Future<Lyrics?> getLyricsByTrackId(String trackId);

  // Save lyrics for a track
  Future<void> saveLyrics(Lyrics lyrics);

  // Delete lyrics for a track
  Future<void> deleteLyrics(String trackId);

  // Search for lyrics files in the same directory as audio file
  Future<String?> findLyricsFile(String audioFilePath);

  // Load lyrics from file
  Future<Lyrics?> loadLyricsFromFile(String filePath, String trackId);

  // Check if lyrics exist for a track
  Future<bool> hasLyrics(String trackId);

  // Fetch lyrics from remote provider when local file is missing
  Future<Lyrics?> fetchOnlineLyrics({
    required String trackId,
    required String title,
    String? artist,
    bool cloudOnly = false,
  });
}
