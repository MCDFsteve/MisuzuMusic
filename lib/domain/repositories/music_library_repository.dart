import '../entities/music_entities.dart';
import '../entities/webdav_entities.dart';

// Repository interface for music library operations
abstract class MusicLibraryRepository {
  // Track operations
  Future<List<Track>> getAllTracks();
  Future<Track?> getTrackById(String id);
  Future<List<Track>> getTracksByArtist(String artist);
  Future<List<Track>> getTracksByAlbum(String album);
  Future<List<Track>> searchTracks(String query);
  Future<void> addTrack(Track track);
  Future<void> updateTrack(Track track);
  Future<void> deleteTrack(String id);
  Future<Track?> findMatchingTrack(Track reference);
  Future<Track?> fetchArtworkForTrack(Track track);
  Stream<Track> watchTrackUpdates();

  // Artist operations
  Future<List<Artist>> getAllArtists();
  Future<Artist?> getArtistByName(String name);

  // Album operations
  Future<List<Album>> getAllAlbums();
  Future<Album?> getAlbumByTitleAndArtist(String title, String artist);
  Future<List<Album>> getAlbumsByArtist(String artist);

  // Playlist operations
  Future<List<Playlist>> getAllPlaylists();
  Future<Playlist?> getPlaylistById(String id);
  Future<void> createPlaylist(Playlist playlist);
  Future<void> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
  Future<void> addTrackToPlaylist(String playlistId, String trackHash);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackHash);
  Future<List<Track>> getPlaylistTracks(String playlistId);
  Future<void> uploadPlaylistToCloud({
    required String playlistId,
    required String remoteId,
  });
  Future<Playlist?> downloadPlaylistFromCloud(String remoteId);

  // Library management
  Future<void> scanDirectory(String path);
  Future<void> scanWebDavDirectory({
    required WebDavSource source,
    required String password,
  });
  Future<int> mountMysteryLibrary({
    required Uri baseUri,
    required String code,
  });
  Future<void> unmountMysteryLibrary(String sourceId);
  Future<void> removeLibraryDirectory(String directoryPath);
  Future<Track?> ensureWebDavTrackMetadata(Track track, {bool force = false});
  Future<void> uploadWebDavPlayLog({
    required String sourceId,
    required String remotePath,
    required String trackId,
    required DateTime playedAt,
  });
  Future<void> refreshLibrary();
  Future<void> clearLibrary();
  Future<List<String>> getLibraryDirectories();
  Future<List<WebDavSource>> getWebDavSources();
  Future<WebDavSource?> getWebDavSourceById(String id);
  Future<void> saveWebDavSource(WebDavSource source, {String? password});
  Future<void> deleteWebDavSource(String id);
  Future<String?> getWebDavPassword(String id);
  Future<void> testWebDavConnection({
    required WebDavSource source,
    required String password,
  });
  Future<List<WebDavEntry>> listWebDavDirectory({
    required WebDavSource source,
    required String password,
    required String path,
  });
}
