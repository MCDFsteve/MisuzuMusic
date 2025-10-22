import 'dart:typed_data';

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
  Future<TrackModel?> getTrackByContentHash(String contentHash);
  Future<TrackModel?> findMatchingTrack({
    required String title,
    required String artist,
    required String album,
    required int durationMs,
  });
  Future<List<TrackModel>> getTracksByWebDavSource(String sourceId);
  Future<void> deleteTracksByIds(List<String> ids);

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
  Future<void> addTrackToPlaylist(
    String playlistId,
    String trackHash,
    int position,
  );
  Future<void> removeTrackFromPlaylist(String playlistId, String trackHash);
  Future<List<TrackModel>> getPlaylistTracks(String playlistId);
  Future<Uint8List?> exportPlaylistBinary(String playlistId);
  Future<PlaylistModel?> importPlaylistBinary(Uint8List bytes);

  // Library management
  Future<void> clearAllTracks();
  Future<int> getTracksCount();
  Future<int> getArtistsCount();
  Future<int> getAlbumsCount();
}
