import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/error/exceptions.dart';
import '../../../domain/entities/music_entities.dart';
import '../../models/music_models.dart';
import '../../storage/playlist_file_storage.dart';
import 'database_helper.dart';
import 'music_local_datasource.dart';

class MusicLocalDataSourceImpl implements MusicLocalDataSource {
  final DatabaseHelper _databaseHelper;
  final PlaylistFileStorage _playlistStorage;

  MusicLocalDataSourceImpl(this._databaseHelper, this._playlistStorage);

  @override
  Future<List<TrackModel>> getAllTracks() async {
    try {
      final maps = await _databaseHelper.query(
        'tracks',
        orderBy:
            'title COLLATE NOCASE ASC, artist COLLATE NOCASE ASC, album COLLATE NOCASE ASC',
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
      throw DatabaseException(
        'Failed to get tracks by artist: ${e.toString()}',
      );
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
      final prepared = await _prepareTrackForInsert(track);
      await _databaseHelper.insert('tracks', prepared.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert track: ${e.toString()}');
    }
  }

  @override
  Future<void> updateTrack(TrackModel track) async {
    try {
      final prepared = await _prepareTrackForInsert(track);
      await _databaseHelper.update(
        'tracks',
        prepared.toMap(),
        where: 'id = ?',
        whereArgs: [prepared.id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update track: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteTrack(String id) async {
    try {
      await _databaseHelper.delete('tracks', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to delete track: ${e.toString()}');
    }
  }

  @override
  Future<void> insertTracks(List<TrackModel> tracks) async {
    try {
      final prepared = <TrackModel>[];
      for (final track in tracks) {
        prepared.add(await _prepareTrackForInsert(track));
      }
      await _databaseHelper.batch((batch) {
        for (final track in prepared) {
          batch.insert('tracks', track.toMap());
        }
      });
    } catch (e) {
      throw DatabaseException('Failed to insert tracks: ${e.toString()}');
    }
  }

  Future<TrackModel> _prepareTrackForInsert(TrackModel track) async {
    if (track.contentHash != null && track.contentHash!.isNotEmpty) {
      return track;
    }

    if (track.sourceType == TrackSourceType.webdav) {
      final hash = track.contentHash ?? track.id;
      return track.copyWith(contentHash: hash);
    }

    if (track.sourceType == TrackSourceType.local) {
      final file = File(track.filePath);
      if (await file.exists()) {
        final hash = await _computeFileHash(file);
        return track.copyWith(contentHash: hash);
      }
    }

    return track;
  }

  Future<String> _computeFileHash(File file) async {
    final builder = BytesBuilder(copy: false);
    final stream = file.openRead(0, 10240);
    await for (final chunk in stream) {
      builder.add(chunk);
      if (builder.length >= 10240) {
        break;
      }
    }
    var data = builder.takeBytes();
    if (data.isEmpty) {
      data = await file.readAsBytes();
    }
    final digest = sha1.convert(data);
    return digest.toString();
  }

  @override
  Future<TrackModel?> getTrackByFilePath(String filePath) async {
    try {
      final maps = await _databaseHelper.query(
        'tracks',
        where: 'file_path = ?',
        whereArgs: [filePath],
        limit: 1,
      );
      if (maps.isEmpty) {
        return null;
      }
      return TrackModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException(
        'Failed to get track by file path: ${e.toString()}',
      );
    }
  }

  @override
  Future<TrackModel?> getTrackByContentHash(String contentHash) async {
    try {
      final byHash = await _databaseHelper.query(
        'tracks',
        where: 'content_hash = ?',
        whereArgs: [contentHash],
        limit: 1,
      );
      if (byHash.isNotEmpty) {
        return TrackModel.fromMap(byHash.first);
      }

      // Fallback to ID match for legacy playlists that stored track IDs.
      final byId = await _databaseHelper.query(
        'tracks',
        where: 'id = ?',
        whereArgs: [contentHash],
        limit: 1,
      );
      if (byId.isEmpty) {
        return null;
      }

      final model = TrackModel.fromMap(byId.first);
      final prepared = await _prepareTrackForInsert(model);
      if (prepared.contentHash != model.contentHash) {
        try {
          await _databaseHelper.update(
            'tracks',
            {'content_hash': prepared.contentHash},
            where: 'id = ?',
            whereArgs: [prepared.id],
          );
        } catch (_) {
          // Ignored
        }
      }
      return prepared;
    } catch (e) {
      throw DatabaseException(
        'Failed to get track by content hash: ${e.toString()}',
      );
    }
  }

  @override
  Future<TrackModel?> findMatchingTrack({
    required String title,
    required String artist,
    required String album,
    required int durationMs,
  }) async {
    try {
      final normalizedTitle = title.toLowerCase();
      final normalizedArtist = artist.toLowerCase();
      final normalizedAlbum = album.toLowerCase();

      final primary = await _databaseHelper.rawQuery(
        '''
        SELECT * FROM tracks
        WHERE lower(title) = ? AND lower(artist) = ? AND lower(album) = ?
        ORDER BY ABS(duration_ms - ?)
      ''',
        [normalizedTitle, normalizedArtist, normalizedAlbum, durationMs],
      );

      List<Map<String, Object?>> candidates = primary;

      if (candidates.isEmpty) {
        const toleranceMs = 2000;
        candidates = await _databaseHelper.rawQuery(
          '''
          SELECT * FROM tracks
          WHERE lower(title) = ?
            AND ABS(duration_ms - ?) <= ?
          ORDER BY ABS(duration_ms - ?)
        ''',
          [normalizedTitle, durationMs, toleranceMs, durationMs],
        );
      }

      if (candidates.isEmpty) {
        return null;
      }

      return TrackModel.fromMap(candidates.first);
    } catch (e) {
      throw DatabaseException('Failed to find matching track: ${e.toString()}');
    }
  }

  @override
  Future<List<TrackModel>> getTracksByWebDavSource(String sourceId) async {
    try {
      final maps = await _databaseHelper.query(
        'tracks',
        where: 'source_type = ? AND source_id = ?',
        whereArgs: [TrackSourceType.webdav.name, sourceId],
      );
      return maps.map((map) => TrackModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get WebDAV tracks: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteTracksByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    try {
      await _databaseHelper.batch((batch) {
        for (final id in ids) {
          batch.delete('tracks', where: 'id = ?', whereArgs: [id]);
        }
      });
    } catch (e) {
      throw DatabaseException('Failed to delete tracks: ${e.toString()}');
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
      final maps = await _databaseHelper.rawQuery(
        '''
        SELECT
          artist as name,
          COUNT(*) as track_count,
          NULL as artwork_path
        FROM tracks
        WHERE artist = ?
        GROUP BY artist
      ''',
        [name],
      );

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
  Future<AlbumModel?> getAlbumByTitleAndArtist(
    String title,
    String artist,
  ) async {
    try {
      final maps = await _databaseHelper.rawQuery(
        '''
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
      ''',
        [title, artist],
      );

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
      final maps = await _databaseHelper.rawQuery(
        '''
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
      ''',
        [artist],
      );
      return maps.map((map) => AlbumModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException(
        'Failed to get albums by artist: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<PlaylistModel>> getAllPlaylists() async {
    try {
      return _playlistStorage.loadAllPlaylists();
    } catch (e) {
      throw DatabaseException('Failed to get all playlists: ${e.toString()}');
    }
  }

  @override
  Future<PlaylistModel?> getPlaylistById(String id) async {
    try {
      return _playlistStorage.loadPlaylist(id);
    } catch (e) {
      throw DatabaseException('Failed to get playlist by id: ${e.toString()}');
    }
  }

  @override
  Future<void> insertPlaylist(PlaylistModel playlist) async {
    try {
      final hashes = await _normalizePlaylistTrackHashes(playlist.trackIds);
      final model = playlist.copyWith(trackIds: hashes);
      await _playlistStorage.savePlaylist(model);
    } catch (e) {
      throw DatabaseException('Failed to insert playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> updatePlaylist(PlaylistModel playlist) async {
    try {
      final hashes = await _normalizePlaylistTrackHashes(playlist.trackIds);
      final model = playlist.copyWith(trackIds: hashes);
      await _playlistStorage.savePlaylist(model);
    } catch (e) {
      throw DatabaseException('Failed to update playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    try {
      await _playlistStorage.deletePlaylist(id);
    } catch (e) {
      throw DatabaseException('Failed to delete playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> addTrackToPlaylist(
    String playlistId,
    String trackHash,
    int position,
  ) async {
    try {
      final playlist = await getPlaylistById(playlistId);
      if (playlist == null) {
        return;
      }

      final hashes = await _normalizePlaylistTrackHashes(playlist.trackIds);
      final normalizedTrackId = (await _normalizePlaylistTrackHashes([
        trackHash,
      ])).first;
      if (!hashes.contains(normalizedTrackId)) {
        hashes.add(normalizedTrackId);
      }

      final updated = playlist.copyWith(
        trackIds: hashes,
        updatedAt: DateTime.now(),
      );
      await updatePlaylist(updated);
    } catch (e) {
      throw DatabaseException(
        'Failed to add track to playlist: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackHash,
  ) async {
    try {
      final playlist = await getPlaylistById(playlistId);
      if (playlist == null) {
        return;
      }

      final hashes = await _normalizePlaylistTrackHashes(playlist.trackIds);
      final canonical = (await _normalizePlaylistTrackHashes([
        trackHash,
      ])).first;
      hashes.remove(canonical);

      final updated = playlist.copyWith(
        trackIds: hashes,
        updatedAt: DateTime.now(),
      );
      await updatePlaylist(updated);
    } catch (e) {
      throw DatabaseException(
        'Failed to remove track from playlist: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<TrackModel>> getPlaylistTracks(String playlistId) async {
    try {
      final playlist = await getPlaylistById(playlistId);
      if (playlist == null) {
        return [];
      }

      final result = <TrackModel>[];
      for (final hash in playlist.trackIds) {
        final trackModel = await getTrackByContentHash(hash);
        if (trackModel != null) {
          result.add(trackModel);
        }
      }
      return result;
    } catch (e) {
      throw DatabaseException('Failed to get playlist tracks: ${e.toString()}');
    }
  }

  @override
  Future<Uint8List?> exportPlaylistBinary(String playlistId) async {
    try {
      return _playlistStorage.exportPlaylistBytes(playlistId);
    } catch (e) {
      throw DatabaseException('Failed to export playlist: ${e.toString()}');
    }
  }

  @override
  Future<PlaylistModel?> importPlaylistBinary(Uint8List bytes) async {
    try {
      return _playlistStorage.importPlaylistBytes(bytes);
    } catch (e) {
      throw DatabaseException('Failed to import playlist: ${e.toString()}');
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
      final result = await _databaseHelper.rawQuery(
        'SELECT COUNT(*) as count FROM tracks',
      );
      return result.first['count'] as int;
    } catch (e) {
      throw DatabaseException('Failed to get tracks count: ${e.toString()}');
    }
  }

  @override
  Future<int> getArtistsCount() async {
    try {
      final result = await _databaseHelper.rawQuery(
        'SELECT COUNT(DISTINCT artist) as count FROM tracks',
      );
      return result.first['count'] as int;
    } catch (e) {
      throw DatabaseException('Failed to get artists count: ${e.toString()}');
    }
  }

  @override
  Future<int> getAlbumsCount() async {
    try {
      final result = await _databaseHelper.rawQuery(
        'SELECT COUNT(DISTINCT album, artist) as count FROM tracks',
      );
      return result.first['count'] as int;
    } catch (e) {
      throw DatabaseException('Failed to get albums count: ${e.toString()}');
    }
  }

  Future<String?> _resolveTrackHash(String identifier) async {
    final byHash = await getTrackByContentHash(identifier);
    if (byHash != null) {
      return byHash.contentHash ?? identifier;
    }

    final byId = await getTrackById(identifier);
    if (byId != null) {
      final prepared = await _prepareTrackForInsert(byId);
      if (prepared.contentHash != byId.contentHash) {
        try {
          await _databaseHelper.update(
            'tracks',
            {'content_hash': prepared.contentHash},
            where: 'id = ?',
            whereArgs: [prepared.id],
          );
        } catch (_) {}
      }
      return prepared.contentHash ?? prepared.id;
    }
    return null;
  }

  Future<List<String>> _normalizePlaylistTrackHashes(
    List<String> identifiers,
  ) async {
    final result = <String>[];
    final seen = <String>{};
    for (final id in identifiers) {
      final hash = await _resolveTrackHash(id) ?? id;
      if (seen.add(hash)) {
        result.add(hash);
      }
    }
    return result;
  }
}
