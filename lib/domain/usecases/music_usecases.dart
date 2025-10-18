import '../repositories/music_library_repository.dart';
import '../entities/music_entities.dart';

class GetAllTracks {
  final MusicLibraryRepository _repository;

  GetAllTracks(this._repository);

  Future<List<Track>> call() async {
    return await _repository.getAllTracks();
  }
}

class SearchTracks {
  final MusicLibraryRepository _repository;

  SearchTracks(this._repository);

  Future<List<Track>> call(String query) async {
    if (query.trim().isEmpty) {
      return await _repository.getAllTracks();
    }
    return await _repository.searchTracks(query);
  }
}

class ScanMusicDirectory {
  final MusicLibraryRepository _repository;

  ScanMusicDirectory(this._repository);

  Future<void> call(String directoryPath) async {
    return await _repository.scanDirectory(directoryPath);
  }
}

class GetAllArtists {
  final MusicLibraryRepository _repository;

  GetAllArtists(this._repository);

  Future<List<Artist>> call() async {
    return await _repository.getAllArtists();
  }
}

class GetAllAlbums {
  final MusicLibraryRepository _repository;

  GetAllAlbums(this._repository);

  Future<List<Album>> call() async {
    return await _repository.getAllAlbums();
  }
}

class GetLibraryDirectories {
  final MusicLibraryRepository _repository;

  GetLibraryDirectories(this._repository);

  Future<List<String>> call() async {
    return await _repository.getLibraryDirectories();
  }
}
