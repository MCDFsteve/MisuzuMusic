import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../../core/error/exceptions.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../datasources/local/music_local_datasource.dart';
import '../models/music_models.dart';

class MusicLibraryRepositoryImpl implements MusicLibraryRepository {
  final MusicLocalDataSource _localDataSource;
  final Uuid _uuid = const Uuid();

  MusicLibraryRepositoryImpl({
    required MusicLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  @override
  Future<List<Track>> getAllTracks() async {
    try {
      final trackModels = await _localDataSource.getAllTracks();
      return trackModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all tracks: ${e.toString()}');
    }
  }

  @override
  Future<Track?> getTrackById(String id) async {
    try {
      final trackModel = await _localDataSource.getTrackById(id);
      return trackModel?.toEntity();
    } catch (e) {
      throw DatabaseException('Failed to get track by id: ${e.toString()}');
    }
  }

  @override
  Future<List<Track>> getTracksByArtist(String artist) async {
    try {
      final trackModels = await _localDataSource.getTracksByArtist(artist);
      return trackModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get tracks by artist: ${e.toString()}');
    }
  }

  @override
  Future<List<Track>> getTracksByAlbum(String album) async {
    try {
      final trackModels = await _localDataSource.getTracksByAlbum(album);
      return trackModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get tracks by album: ${e.toString()}');
    }
  }

  @override
  Future<List<Track>> searchTracks(String query) async {
    try {
      final trackModels = await _localDataSource.searchTracks(query);
      return trackModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to search tracks: ${e.toString()}');
    }
  }

  @override
  Future<void> addTrack(Track track) async {
    try {
      final trackModel = TrackModel.fromEntity(track);
      await _localDataSource.insertTrack(trackModel);
    } catch (e) {
      throw DatabaseException('Failed to add track: ${e.toString()}');
    }
  }

  @override
  Future<void> updateTrack(Track track) async {
    try {
      final trackModel = TrackModel.fromEntity(track);
      await _localDataSource.updateTrack(trackModel);
    } catch (e) {
      throw DatabaseException('Failed to update track: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteTrack(String id) async {
    try {
      await _localDataSource.deleteTrack(id);
    } catch (e) {
      throw DatabaseException('Failed to delete track: ${e.toString()}');
    }
  }

  @override
  Future<List<Artist>> getAllArtists() async {
    try {
      final artistModels = await _localDataSource.getAllArtists();
      return artistModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all artists: ${e.toString()}');
    }
  }

  @override
  Future<Artist?> getArtistByName(String name) async {
    try {
      final artistModel = await _localDataSource.getArtistByName(name);
      return artistModel?.toEntity();
    } catch (e) {
      throw DatabaseException('Failed to get artist by name: ${e.toString()}');
    }
  }

  @override
  Future<List<Album>> getAllAlbums() async {
    try {
      final albumModels = await _localDataSource.getAllAlbums();
      return albumModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all albums: ${e.toString()}');
    }
  }

  @override
  Future<Album?> getAlbumByTitleAndArtist(String title, String artist) async {
    try {
      final albumModel = await _localDataSource.getAlbumByTitleAndArtist(title, artist);
      return albumModel?.toEntity();
    } catch (e) {
      throw DatabaseException('Failed to get album: ${e.toString()}');
    }
  }

  @override
  Future<List<Album>> getAlbumsByArtist(String artist) async {
    try {
      final albumModels = await _localDataSource.getAlbumsByArtist(artist);
      return albumModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get albums by artist: ${e.toString()}');
    }
  }

  @override
  Future<List<Playlist>> getAllPlaylists() async {
    try {
      final playlistModels = await _localDataSource.getAllPlaylists();
      return playlistModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all playlists: ${e.toString()}');
    }
  }

  @override
  Future<Playlist?> getPlaylistById(String id) async {
    try {
      final playlistModel = await _localDataSource.getPlaylistById(id);
      return playlistModel?.toEntity();
    } catch (e) {
      throw DatabaseException('Failed to get playlist by id: ${e.toString()}');
    }
  }

  @override
  Future<void> createPlaylist(Playlist playlist) async {
    try {
      final playlistModel = PlaylistModel.fromEntity(playlist);
      await _localDataSource.insertPlaylist(playlistModel);
    } catch (e) {
      throw DatabaseException('Failed to create playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    try {
      final playlistModel = PlaylistModel.fromEntity(playlist);
      await _localDataSource.updatePlaylist(playlistModel);
    } catch (e) {
      throw DatabaseException('Failed to update playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    try {
      await _localDataSource.deletePlaylist(id);
    } catch (e) {
      throw DatabaseException('Failed to delete playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    try {
      final playlist = await getPlaylistById(playlistId);
      if (playlist != null) {
        final updatedTrackIds = List<String>.from(playlist.trackIds)..add(trackId);
        final updatedPlaylist = playlist.copyWith(
          trackIds: updatedTrackIds,
          updatedAt: DateTime.now(),
        );
        await updatePlaylist(updatedPlaylist);
      }
    } catch (e) {
      throw DatabaseException('Failed to add track to playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    try {
      final playlist = await getPlaylistById(playlistId);
      if (playlist != null) {
        final updatedTrackIds = List<String>.from(playlist.trackIds)..remove(trackId);
        final updatedPlaylist = playlist.copyWith(
          trackIds: updatedTrackIds,
          updatedAt: DateTime.now(),
        );
        await updatePlaylist(updatedPlaylist);
      }
    } catch (e) {
      throw DatabaseException('Failed to remove track from playlist: ${e.toString()}');
    }
  }

  @override
  Future<void> scanDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        throw DirectoryNotFoundException(directoryPath);
      }

      final audioFiles = await _findAudioFiles(directory);
      final tracks = <TrackModel>[];

      for (final file in audioFiles) {
        try {
          final track = await _createTrackFromFile(file);
          if (track != null) {
            tracks.add(track);
          }
        } catch (e) {
          // Log error but continue processing other files
          print('Error processing file ${file.path}: $e');
        }
      }

      if (tracks.isNotEmpty) {
        await _localDataSource.insertTracks(tracks);
      }
    } catch (e) {
      throw FileSystemException('Failed to scan directory: ${e.toString()}');
    }
  }

  @override
  Future<void> refreshLibrary() async {
    // Implementation would rescan all previously scanned directories
    // For now, this is a placeholder
    throw UnimplementedError('Refresh library not yet implemented');
  }

  @override
  Future<void> clearLibrary() async {
    try {
      await _localDataSource.clearAllTracks();
    } catch (e) {
      throw DatabaseException('Failed to clear library: ${e.toString()}');
    }
  }

  Future<List<File>> _findAudioFiles(Directory directory) async {
    final audioFiles = <File>[];
    final supportedExtensions = {'.mp3', '.flac', '.aac', '.wav', '.ogg', '.m4a'};

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if (supportedExtensions.contains(extension)) {
          audioFiles.add(entity);
        }
      }
    }

    return audioFiles;
  }

  Future<TrackModel?> _createTrackFromFile(File file) async {
    try {
      // Read metadata
      final metadata = await readMetadata(file, getImage: false);

      final title = metadata?.title ?? path.basenameWithoutExtension(file.path);
      final artist = metadata?.artist ?? 'Unknown Artist';
      final album = metadata?.album ?? 'Unknown Album';
      final duration = metadata?.duration ?? Duration.zero;
      final year = metadata?.year?.year;
      final trackNumber = metadata?.trackNumber;
      final genre = metadata?.genres?.isNotEmpty == true ? metadata!.genres!.first : null;

      return TrackModel(
        id: _uuid.v4(),
        title: title,
        artist: artist,
        album: album,
        filePath: file.path,
        duration: duration,
        dateAdded: DateTime.now(),
        trackNumber: trackNumber,
        year: year,
        genre: genre,
      );
    } catch (e) {
      print('Error reading metadata for ${file.path}: $e');

      // Fallback: create track with filename only
      return TrackModel(
        id: _uuid.v4(),
        title: path.basenameWithoutExtension(file.path),
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        filePath: file.path,
        duration: Duration.zero,
        dateAdded: DateTime.now(),
      );
    }
  }
}