import '../entities/netease_entities.dart';
import '../entities/music_entities.dart';

abstract class NeteaseRepository {
  Future<NeteaseSession?> loadSession();
  Future<NeteaseSession> loginWithCookie(String cookie);
  Future<void> logout();
  Future<NeteaseSession?> refreshSession();
  Future<List<NeteasePlaylist>> fetchUserPlaylists();
  Future<List<Track>> fetchPlaylistTracks(int playlistId);
  Future<Track?> ensureTrackStream(Track track);
  List<NeteasePlaylist> getCachedPlaylists();
  Map<int, List<Track>> getCachedPlaylistTracks();
}
