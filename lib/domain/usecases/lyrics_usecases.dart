import '../entities/lyrics_entities.dart';
import '../repositories/lyrics_repository.dart';

class GetLyrics {
  final LyricsRepository _repository;

  GetLyrics(this._repository);

  Future<Lyrics?> call(String trackId) async {
    return await _repository.getLyricsByTrackId(trackId);
  }
}

class LoadLyricsFromFile {
  final LyricsRepository _repository;

  LoadLyricsFromFile(this._repository);

  Future<Lyrics?> call(String filePath, String trackId) async {
    return await _repository.loadLyricsFromFile(filePath, trackId);
  }
}

class SaveLyrics {
  final LyricsRepository _repository;

  SaveLyrics(this._repository);

  Future<void> call(Lyrics lyrics) async {
    await _repository.saveLyrics(lyrics);
  }
}

class FindLyricsFile {
  final LyricsRepository _repository;

  FindLyricsFile(this._repository);

  Future<String?> call(String audioFilePath) async {
    return await _repository.findLyricsFile(audioFilePath);
  }
}

class FetchOnlineLyrics {
  final LyricsRepository _repository;

  FetchOnlineLyrics(this._repository);

  Future<Lyrics?> call({
    required String trackId,
    required String title,
    String? artist,
    bool cloudOnly = false,
  }) async {
    return await _repository.fetchOnlineLyrics(
      trackId: trackId,
      title: title,
      artist: artist,
      cloudOnly: cloudOnly,
    );
  }
}
