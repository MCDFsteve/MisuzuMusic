import '../repositories/music_library_repository.dart';
import '../entities/music_entities.dart';
import '../entities/webdav_entities.dart';
import '../entities/jellyfin_entities.dart';

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

class ImportLocalTracks {
  final MusicLibraryRepository _repository;

  ImportLocalTracks(this._repository);

  Future<List<Track>> call(
    List<String> filePaths, {
    bool addToLibrary = true,
  }) async {
    return _repository.importLocalTracks(
      filePaths,
      addToLibrary: addToLibrary,
    );
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

class RemoveLibraryDirectory {
  final MusicLibraryRepository _repository;

  RemoveLibraryDirectory(this._repository);

  Future<void> call(String directoryPath) async {
    await _repository.removeLibraryDirectory(directoryPath);
  }
}

class ClearLibrary {
  final MusicLibraryRepository _repository;

  ClearLibrary(this._repository);

  Future<void> call() async {
    await _repository.clearLibrary();
  }
}

class ScanWebDavDirectory {
  final MusicLibraryRepository _repository;

  ScanWebDavDirectory(this._repository);

  Future<void> call({
    required WebDavSource source,
    required String password,
  }) async {
    return await _repository.scanWebDavDirectory(
      source: source,
      password: password,
    );
  }
}

class ScanJellyfinLibrary {
  final MusicLibraryRepository _repository;

  ScanJellyfinLibrary(this._repository);

  Future<void> call({
    required JellyfinSource source,
    required String accessToken,
  }) async {
    return await _repository.scanJellyfinLibrary(
      source: source,
      accessToken: accessToken,
    );
  }
}

class MountMysteryLibrary {
  final MusicLibraryRepository _repository;

  MountMysteryLibrary(this._repository);

  Future<int> call({
    required Uri baseUri,
    required String code,
  }) async {
    return _repository.mountMysteryLibrary(baseUri: baseUri, code: code);
  }
}

class UnmountMysteryLibrary {
  final MusicLibraryRepository _repository;

  UnmountMysteryLibrary(this._repository);

  Future<void> call(String sourceId) async {
    await _repository.unmountMysteryLibrary(sourceId);
  }
}

class GetWebDavSources {
  final MusicLibraryRepository _repository;

  GetWebDavSources(this._repository);

  Future<List<WebDavSource>> call() async {
    return await _repository.getWebDavSources();
  }
}

class GetWebDavSourceById {
  final MusicLibraryRepository _repository;

  GetWebDavSourceById(this._repository);

  Future<WebDavSource?> call(String id) async {
    return await _repository.getWebDavSourceById(id);
  }
}

class SaveWebDavSource {
  final MusicLibraryRepository _repository;

  SaveWebDavSource(this._repository);

  Future<void> call(WebDavSource source, {String? password}) async {
    await _repository.saveWebDavSource(source, password: password);
  }
}

class DeleteWebDavSource {
  final MusicLibraryRepository _repository;

  DeleteWebDavSource(this._repository);

  Future<void> call(String id) async {
    await _repository.deleteWebDavSource(id);
  }
}

class GetWebDavPassword {
  final MusicLibraryRepository _repository;

  GetWebDavPassword(this._repository);

  Future<String?> call(String id) async {
    return _repository.getWebDavPassword(id);
  }
}

class AuthenticateJellyfin {
  final MusicLibraryRepository _repository;

  AuthenticateJellyfin(this._repository);

  Future<JellyfinAuthSession> call({
    required String baseUrl,
    required String username,
    required String password,
    bool ignoreTls = false,
  }) async {
    return _repository.authenticateJellyfin(
      baseUrl: baseUrl,
      username: username,
      password: password,
      ignoreTls: ignoreTls,
    );
  }
}

class GetJellyfinLibraries {
  final MusicLibraryRepository _repository;

  GetJellyfinLibraries(this._repository);

  Future<List<JellyfinLibrary>> call({
    required String baseUrl,
    required String accessToken,
    required String userId,
    bool ignoreTls = false,
  }) async {
    return _repository.getJellyfinLibraries(
      baseUrl: baseUrl,
      accessToken: accessToken,
      userId: userId,
      ignoreTls: ignoreTls,
    );
  }
}

class GetJellyfinSources {
  final MusicLibraryRepository _repository;

  GetJellyfinSources(this._repository);

  Future<List<JellyfinSource>> call() async {
    return _repository.getJellyfinSources();
  }
}

class GetJellyfinSourceById {
  final MusicLibraryRepository _repository;

  GetJellyfinSourceById(this._repository);

  Future<JellyfinSource?> call(String id) async {
    return _repository.getJellyfinSourceById(id);
  }
}

class DeleteJellyfinSource {
  final MusicLibraryRepository _repository;

  DeleteJellyfinSource(this._repository);

  Future<void> call(String id) async {
    return _repository.deleteJellyfinSource(id);
  }
}

class GetJellyfinAccessToken {
  final MusicLibraryRepository _repository;

  GetJellyfinAccessToken(this._repository);

  Future<String?> call(String id) async {
    return _repository.getJellyfinAccessToken(id);
  }
}

class TestWebDavConnection {
  final MusicLibraryRepository _repository;

  TestWebDavConnection(this._repository);

  Future<void> call({
    required WebDavSource source,
    required String password,
  }) async {
    await _repository.testWebDavConnection(source: source, password: password);
  }
}

class ListWebDavDirectory {
  final MusicLibraryRepository _repository;

  ListWebDavDirectory(this._repository);

  Future<List<WebDavEntry>> call({
    required WebDavSource source,
    required String password,
    required String path,
  }) async {
    return _repository.listWebDavDirectory(
      source: source,
      password: password,
      path: path,
    );
  }
}

class EnsureWebDavTrackMetadata {
  final MusicLibraryRepository _repository;

  EnsureWebDavTrackMetadata(this._repository);

  Future<Track?> call(Track track, {bool force = false}) async {
    return _repository.ensureWebDavTrackMetadata(track, force: force);
  }
}

class WatchTrackUpdates {
  final MusicLibraryRepository _repository;

  WatchTrackUpdates(this._repository);

  Stream<Track> call() => _repository.watchTrackUpdates();
}
