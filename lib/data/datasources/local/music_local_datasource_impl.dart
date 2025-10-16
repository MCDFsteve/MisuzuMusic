import '../../../core/error/exceptions.dart';
import '../../models/music_models.dart';
import 'database_helper.dart';
import 'music_local_datasource.dart';

class MusicLocalDataSourceImpl implements MusicLocalDataSource {
  final DatabaseHelper _databaseHelper;

  MusicLocalDataSourceImpl(this._databaseHelper);

  @override
  Future<List<TrackModel>> getAllTracks() async {
    try {
      final maps = await _databaseHelper.query(
        'tracks',
        orderBy: 'date_added DESC',
      );
      return maps.map((map) => TrackModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all tracks: ${e.toString()}');
    }
  }

  @override
  Future<TrackModel?> getTrackById(String id) async {
    try {
      final maps = await _databaseHelper.query(
        'tracks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return TrackModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw DatabaseException('Failed to get track by id: ${e.toString()}');
    }
  }

  @override
  Future<List<TrackModel>> getTracksByArtist(String artist) async {
    try {
      final maps = await _databaseHelper.query(
        'tracks',
        where: 'artist = ?',
        whereArgs: [artist],
        orderBy: 'album, track_number',
      );
      return maps.map((map) => TrackModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get tracks by artist: ${e.toString()}');
    }
  }

  @override
  Future<List<TrackModel>> getTracksByAlbum(String album) async {
    try {
      final maps = await _databaseHelper.query(
        'tracks',
        where: 'album = ?',
        whereArgs: [album],
        orderBy: 'track_number',
      );
      return maps.map((map) => TrackModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get tracks by album: ${e.toString()}');
    }
  }

  @override
  Future<List<TrackModel>> searchTracks(String query) async {
    try {
      final maps = await _databaseHelper.searchTracks(query);
      return maps.map((map) => TrackModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to search tracks: ${e.toString()}');
    }
  }

  @override
  Future<void> insertTrack(TrackModel track) async {
    try {
      await _databaseHelper.insert('tracks', track.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert track: ${e.toString()}');
    }
  }

  @override
  Future<void> updateTrack(TrackModel track) async {
    try {
      await _databaseHelper.update(
        'tracks',
        track.toMap(),
        where: 'id = ?',
        whereArgs: [track.id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update track: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteTrack(String id) async {
    try {
      await _databaseHelper.delete(
        'tracks',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to delete track: ${e.toString()}');
    }
  }

  @override
  Future<void> insertTracks(List<TrackModel> tracks) async {
    try {
      await _databaseHelper.batch((batch) {
        for (final track in tracks) {
          batch.insert('tracks', track.toMap());
        }
      });
    } catch (e) {
      throw DatabaseException('Failed to insert tracks: ${e.toString()}');
    }
  }

  @override
  Future<List<ArtistModel>> getAllArtists() async {
    try {
      final maps = await _databaseHelper.rawQuery('''
        SELECT
          artist as name,
          COUNT(*) as track_count,
          NULL as artwork_path
        FROM tracks
        GROUP BY artist
        ORDER BY artist
      ''');
      return maps.map((map) => ArtistModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all artists: ${e.toString()}');
    }
  }

  @override
  Future<ArtistModel?> getArtistByName(String name) async {
    try {
      final maps = await _databaseHelper.rawQuery('''
        SELECT
          artist as name,
          COUNT(*) as track_count,
          NULL as artwork_path
        FROM tracks
        WHERE artist = ?
        GROUP BY artist
      ''', [name]);

      if (maps.isNotEmpty) {
        return ArtistModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw DatabaseException('Failed to get artist by name: ${e.toString()}');
    }
  }

  @override
  Future<List<AlbumModel>> getAllAlbums() async {
    try {
      final maps = await _databaseHelper.rawQuery('''
        SELECT
          album as title,
          artist,
          COUNT(*) as track_count,
          MIN(year) as year,
          NULL as artwork_path,
          SUM(duration_ms) as total_duration_ms
        FROM tracks
        GROUP BY album, artist
        ORDER BY artist, album
      ''');
      return maps.map((map) => AlbumModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all albums: ${e.toString()}');
    }
  }

  @override
  Future<AlbumModel?> getAlbumByTitleAndArtist(String title, String artist) async {
    try {
      final maps = await _databaseHelper.rawQuery('''
        SELECT
          album as title,
          artist,
          COUNT(*) as track_count,
          MIN(year) as year,
          NULL as artwork_path,
          SUM(duration_ms) as total_duration_ms
        FROM tracks
        WHERE album = ? AND artist = ?
        GROUP BY album, artist
      ''', [title, artist]);

      if (maps.isNotEmpty) {
        return AlbumModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw DatabaseException('Failed to get album: ${e.toString()}');
    }
  }

  @override
  Future<List<AlbumModel>> getAlbumsByArtist(String artist) async {
    try {
      final maps = await _databaseHelper.rawQuery('''
        SELECT
          album as title,
          artist,
          COUNT(*) as track_count,
          MIN(year) as year,
          NULL as artwork_path,
          SUM(duration_ms) as total_duration_ms
        FROM tracks
        WHERE artist = ?
        GROUP BY album, artist
        ORDER BY album
      ''', [artist]);
      return maps.map((map) => AlbumModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get albums by artist: ${e.toString()}');
    }
  }

  @override
  Future<List<PlaylistModel>> getAllPlaylists() async {
    try {
      final maps = await _databaseHelper.query(
        'playlists',
        orderBy: 'created_at DESC',
      );

      final playlists = <PlaylistModel>[];
      for (final map in maps) {
        final playlist = PlaylistModel.fromMap(map);
        final trackIds = await _getPlaylistTrackIds(playlist.id);
        playlists.add(playlist.copyWith(trackIds: trackIds));
      }

      return playlists;
    } catch (e) {
      throw DatabaseException('Failed to get all playlists: ${e.toString()}');
    }
  }

  @override
  Future<PlaylistModel?> getPlaylistById(String id) async {
    try {
      final maps = await _databaseHelper.query(
        'playlists',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final playlist = PlaylistModel.fromMap(maps.first);
        final trackIds = await _getPlaylistTrackIds(id);
        return playlist.copyWith(trackIds: trackIds);
      }
      return null;
    } catch (e) {
      throw DatabaseException('Failed to get playlist by id: ${e.toString()}');
    }
  }

  @override
  Future<void> insertPlaylist(PlaylistModel playlist) async {
    try {
      await _databaseHelper.transaction((txn) async {
        // Insert playlist
        await txn.insert('playlists', playlist.toMap());

        // Insert playlist tracks
        for (int i = 0; i < playlist.trackIds.length; i++) {
          await txn.insert('playlist_tracks', {
            'playlist_id': playlist.id,
            'track_id': playlist.trackIds[i],
            'position': i,
          });
        }
      });
    } catch (e) {
      throw DatabaseException('Failed to insert playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> updatePlaylist(PlaylistModel playlist) async {
    try {
      await _databaseHelper.transaction((txn) async {
        // Update playlist
        await txn.update(
          'playlists',
          playlist.toMap(),
          where: 'id = ?',
          whereArgs: [playlist.id],
        );

        // Remove existing tracks
        await txn.delete(
          'playlist_tracks',
          where: 'playlist_id = ?',
          whereArgs: [playlist.id],
        );

        // Insert updated tracks
        for (int i = 0; i < playlist.trackIds.length; i++) {
          await txn.insert('playlist_tracks', {
            'playlist_id': playlist.id,
            'track_id': playlist.trackIds[i],
            'position': i,
          });
        }
      });
    } catch (e) {
      throw DatabaseException('Failed to update playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    try {
      await _databaseHelper.delete(
        'playlists',
        where: 'id = ?',
        whereArgs: [id],
      );
      // playlist_tracks will be deleted by CASCADE
    } catch (e) {
      throw DatabaseException('Failed to delete playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, String trackId, int position) async {
    try {
      await _databaseHelper.insert('playlist_tracks', {
        'playlist_id': playlistId,
        'track_id': trackId,
        'position': position,
      });
    } catch (e) {
      throw DatabaseException('Failed to add track to playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    try {
      await _databaseHelper.delete(
        'playlist_tracks',
        where: 'playlist_id = ? AND track_id = ?',
        whereArgs: [playlistId, trackId],
      );
    } catch (e) {
      throw DatabaseException('Failed to remove track from playlist: ${e.toString()}');
    }
  }

  @override
  Future<List<TrackModel>> getPlaylistTracks(String playlistId) async {
    try {
      final maps = await _databaseHelper.rawQuery('''
        SELECT t.* FROM tracks t
        INNER JOIN playlist_tracks pt ON t.id = pt.track_id
        WHERE pt.playlist_id = ?
        ORDER BY pt.position
      ''', [playlistId]);

      return maps.map((map) => TrackModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get playlist tracks: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAllTracks() async {
    try {
      await _databaseHelper.delete('tracks');
    } catch (e) {
      throw DatabaseException('Failed to clear all tracks: ${e.toString()}');
    }
  }

  @override
  Future<int> getTracksCount() async {
    try {
      final result = await _databaseHelper.rawQuery('SELECT COUNT(*) as count FROM tracks');
      return result.first['count'] as int;
    } catch (e) {
      throw DatabaseException('Failed to get tracks count: ${e.toString()}');
    }
  }

  @override
  Future<int> getArtistsCount() async {
    try {
      final result = await _databaseHelper.rawQuery('SELECT COUNT(DISTINCT artist) as count FROM tracks');
      return result.first['count'] as int;
    } catch (e) {
      throw DatabaseException('Failed to get artists count: ${e.toString()}');
    }
  }

  @override
  Future<int> getAlbumsCount() async {
    try {
      final result = await _databaseHelper.rawQuery('SELECT COUNT(DISTINCT album, artist) as count FROM tracks');
      return result.first['count'] as int;
    } catch (e) {
      throw DatabaseException('Failed to get albums count: ${e.toString()}');
    }
  }

  Future<List<String>> _getPlaylistTrackIds(String playlistId) async {
    final maps = await _databaseHelper.query(
      'playlist_tracks',
      columns: ['track_id'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position',
    );

    return maps.map((map) => map['track_id'] as String).toList();
  }
}