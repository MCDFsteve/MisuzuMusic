import '../../../domain/entities/music_entities.dart';
import '../../models/music_models.dart';

abstract class MusicLocalDataSource {
  // Track operations
  Future<List<TrackModel>> getAllTracks();
  Future<TrackModel?> getTrackById(String id);
  Future<List<TrackModel>> getTracksByArtist(String artist);
  Future<List<TrackModel>> getTracksByAlbum(String album);
  Future<List<TrackModel>> searchTracks(String query);
  Future<void> insertTrack(TrackModel track);
  Future<void> updateTrack(TrackModel track);
  Future<void> deleteTrack(String id);
  Future<void> insertTracks(List<TrackModel> tracks);
  Future<TrackModel?> getTrackByFilePath(String filePath);

  // Artist operations
  Future<List<ArtistModel>> getAllArtists();
  Future<ArtistModel?> getArtistByName(String name);

  // Album operations
  Future<List<AlbumModel>> getAllAlbums();
  Future<AlbumModel?> getAlbumByTitleAndArtist(String title, String artist);
  Future<List<AlbumModel>> getAlbumsByArtist(String artist);

  // Playlist operations
  Future<List<PlaylistModel>> getAllPlaylists();
  Future<PlaylistModel?> getPlaylistById(String id);
  Future<void> insertPlaylist(PlaylistModel playlist);
  Future<void> updatePlaylist(PlaylistModel playlist);
  Future<void> deletePlaylist(String id);
  Future<void> addTrackToPlaylist(String playlistId, String trackId, int position);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);
  Future<List<TrackModel>> getPlaylistTracks(String playlistId);

  // Library management
  Future<void> clearAllTracks();
  Future<int> getTracksCount();
  Future<int> getArtistsCount();
  Future<int> getAlbumsCount();
}
