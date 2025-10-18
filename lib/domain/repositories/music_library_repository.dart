import '../entities/music_entities.dart';

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
  Future<void> addTrackToPlaylist(String playlistId, String trackId);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);

  // Library management
  Future<void> scanDirectory(String path);
  Future<void> refreshLibrary();
  Future<void> clearLibrary();
  Future<List<String>> getLibraryDirectories();
}
