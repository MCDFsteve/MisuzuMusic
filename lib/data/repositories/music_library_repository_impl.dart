import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/io.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart' show posix;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../../core/error/exceptions.dart';
import '../../core/storage/binary_config_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/entities/webdav_entities.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../datasources/local/music_local_datasource.dart';
import '../models/music_models.dart';
import '../models/webdav_models.dart';
import '../../core/constants/app_constants.dart';

class MusicLibraryRepositoryImpl implements MusicLibraryRepository {
  final MusicLocalDataSource _localDataSource;
  final BinaryConfigStore _configStore;
  final Uuid _uuid = const Uuid();
  static const Set<String> _supportedAudioExtensions = {
    '.mp3',
    '.flac',
    '.aac',
    '.wav',
    '.ogg',
    '.m4a',
    '.opus',
    '.wma',
    '.aiff',
    '.alac',
    '.dsf',
    '.ape',
    '.wv',
    '.mka',
  };

  MusicLibraryRepositoryImpl({
    required MusicLocalDataSource localDataSource,
    required BinaryConfigStore configStore,
  }) : _localDataSource = localDataSource,
       _configStore = configStore;

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
      throw DatabaseException(
        'Failed to get tracks by artist: ${e.toString()}',
      );
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
  Future<Track?> findMatchingTrack(Track reference) async {
    try {
      final model = await _localDataSource.findMatchingTrack(
        title: reference.title,
        artist: reference.artist,
        album: reference.album,
        durationMs: reference.duration.inMilliseconds,
      );
      return model?.toEntity();
    } catch (e) {
      throw DatabaseException('Failed to find matching track: ${e.toString()}');
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
      final albumModel = await _localDataSource.getAlbumByTitleAndArtist(
        title,
        artist,
      );
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
      throw DatabaseException(
        'Failed to get albums by artist: ${e.toString()}',
      );
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
        final updatedTrackIds = List<String>.from(playlist.trackIds)
          ..add(trackId);
        final updatedPlaylist = playlist.copyWith(
          trackIds: updatedTrackIds,
          updatedAt: DateTime.now(),
        );
        await updatePlaylist(updatedPlaylist);
      }
    } catch (e) {
      throw DatabaseException(
        'Failed to add track to playlist: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    try {
      final playlist = await getPlaylistById(playlistId);
      if (playlist != null) {
        final updatedTrackIds = List<String>.from(playlist.trackIds)
          ..remove(trackId);
        final updatedPlaylist = playlist.copyWith(
          trackIds: updatedTrackIds,
          updatedAt: DateTime.now(),
        );
        await updatePlaylist(updatedPlaylist);
      }
    } catch (e) {
      throw DatabaseException(
        'Failed to remove track from playlist: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> scanDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        throw DirectoryNotFoundException(directoryPath);
      }

      final normalizedPath = path.normalize(directory.absolute.path);
      await _registerLibraryDirectory(normalizedPath);

      final audioFiles = await _findAudioFiles(directory);

      for (final file in audioFiles) {
        try {
          final existing = await _localDataSource.getTrackByFilePath(file.path);
          final track = await _createTrackFromFile(
            file,
            existingTrack: existing,
          );
          if (track != null) {
            if (existing != null) {
              await _localDataSource.updateTrack(track);
            } else {
              await _localDataSource.insertTrack(track);
            }
          }
        } catch (e) {
          // Log error but continue processing other files
          print('Error processing file ${file.path}: $e');
        }
      }
    } catch (e) {
      throw FileSystemException('Failed to scan directory: ${e.toString()}');
    }
  }

  @override
  Future<void> scanWebDavDirectory({
    required WebDavSource source,
    required String password,
  }) async {
    var normalizedSource = source.copyWith(
      baseUrl: _normalizeBaseUrl(source.baseUrl),
      rootPath: _normalizeRemotePath(source.rootPath),
      updatedAt: DateTime.now(),
      createdAt: source.createdAt ?? DateTime.now(),
    );

    final savedSources = await getWebDavSources();
    final existing = savedSources.firstWhere(
      (item) =>
          item.baseUrl == normalizedSource.baseUrl &&
          item.rootPath == normalizedSource.rootPath &&
          (item.username ?? '') == (normalizedSource.username ?? ''),
      orElse: () => normalizedSource,
    );
    if (existing.id != normalizedSource.id) {
      normalizedSource = WebDavSource(
        id: existing.id,
        name: normalizedSource.name,
        baseUrl: normalizedSource.baseUrl,
        rootPath: normalizedSource.rootPath,
        username: normalizedSource.username,
        ignoreTls: normalizedSource.ignoreTls,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
    }

    await saveWebDavSource(normalizedSource, password: password);

    final client = await _createWebDavClient(normalizedSource, password);

    try {
      print(
        '🌐 WebDAV: 开始扫描 ${normalizedSource.baseUrl}${normalizedSource.rootPath}',
      );
      final remoteFiles = await _collectRemoteAudioFiles(
        client,
        normalizedSource.rootPath,
      );
      print('🌐 WebDAV: 发现 ${remoteFiles.length} 个音频候选');

      final existingTracks = await _localDataSource.getTracksByWebDavSource(
        normalizedSource.id,
      );
      final existingByRemotePath = {
        for (final track in existingTracks) (track.remotePath ?? ''): track,
      };

      final seenIds = <String>{};
      final now = DateTime.now();

      for (final remoteFile in remoteFiles) {
        final filePathKey = _buildWebDavFilePath(
          normalizedSource.id,
          remoteFile.relativePath,
        );
        final existing = existingByRemotePath[remoteFile.relativePath];

        _WebDavTrackMetadata? metadata;
        if (remoteFile.metadataPath != null) {
          print(
            '🌐 WebDAV: 尝试读取元数据 -> ${remoteFile.metadataPath}',
          );
          metadata = await _loadWebDavTrackMetadata(
            client,
            remoteFile.metadataPath!,
          );
          if (metadata != null) {
            print(
              '🌐 WebDAV: 元数据载入成功 -> 标题: ${metadata.title ?? remoteFile.title}',
            );
          } else {
            print(
              '⚠️ WebDAV: 元数据读取失败或为空 -> ${remoteFile.metadataPath}',
            );
          }
        } else {
          print('⚠️ WebDAV: 未找到元数据文件 -> ${remoteFile.relativePath}');
        }

        final title = metadata?.title ?? remoteFile.title;
        final artist = metadata?.artist ??
            metadata?.albumArtist ??
            existing?.artist ??
            'Unknown Artist';
        final album = metadata?.album ?? existing?.album ?? 'Unknown Album';
        final duration = metadata?.duration ?? existing?.duration ?? Duration.zero;
        final trackNumber = metadata?.trackNumber ?? existing?.trackNumber;
        final year = metadata?.year ?? existing?.year;
        final genre = metadata?.genre ?? existing?.genre;

        String? artworkPath = existing?.artworkPath;
        if (remoteFile.artworkPath != null) {
          print('🌐 WebDAV: 发现同名封面 -> ${remoteFile.artworkPath}');
          artworkPath = await _downloadWebDavArtwork(
            client: client,
            sourceId: normalizedSource.id,
            remoteArtworkPath: remoteFile.artworkPath!,
            previousArtworkPath: existing?.artworkPath,
          );
        } else if (metadata?.hasCover == true &&
            metadata?.coverFileName != null) {
          final remoteCoverPath = _normalizeRemotePath(
            posix.join(
              posix.dirname(remoteFile.fullPath),
              metadata!.coverFileName!,
            ),
          );
          print(
            '🌐 WebDAV: 依据元数据查找封面 -> $remoteCoverPath',
          );
          artworkPath = await _downloadWebDavArtwork(
            client: client,
            sourceId: normalizedSource.id,
            remoteArtworkPath: remoteCoverPath,
            previousArtworkPath: existing?.artworkPath,
          );
        }

        final trackModel = TrackModel(
          id: existing?.id ?? _uuid.v4(),
          title: title,
          artist: artist,
          album: album,
          filePath: filePathKey,
          duration: duration,
          dateAdded: existing?.dateAdded ?? now,
          artworkPath: artworkPath,
          trackNumber: trackNumber,
          year: year,
          genre: genre,
          sourceType: TrackSourceType.webdav,
          sourceId: normalizedSource.id,
          remotePath: remoteFile.relativePath,
        );

        if (existing == null) {
          await _localDataSource.insertTrack(trackModel);
        } else {
          await _localDataSource.updateTrack(trackModel);
        }
        seenIds.add(trackModel.id);
      }

      final removedIds = existingTracks
          .where((track) => !seenIds.contains(track.id))
          .map((track) => track.id)
          .toList();
      if (removedIds.isNotEmpty) {
        await _localDataSource.deleteTracksByIds(removedIds);
      }
    } catch (e) {
      print('❌ WebDAV: 扫描目录失败 -> $e');
      throw FileSystemException(
        '扫描 WebDAV 目录失败: ${e.toString()}',
      );
    }
  }

  @override
  Future<Track?> ensureWebDavTrackMetadata(
    Track track, {
    bool force = false,
  }) async {
    try {
      final sourceId = track.sourceId ?? _extractSourceId(track.filePath);
      final remotePath = track.remotePath ??
          _extractRemotePath(track.filePath, sourceId);

      if (sourceId == null || remotePath == null) {
        print('⚠️ WebDAV: 无法解析远程路径 -> ${track.filePath}');
        return track;
      }

      final needsMetadata = force ||
          track.duration <= Duration.zero ||
          track.artist.toLowerCase() == 'unknown artist' ||
          track.album.toLowerCase() == 'unknown album' ||
          (track.artworkPath == null || track.artworkPath!.isEmpty);

      if (!needsMetadata) {
        print('🌐 WebDAV: 元数据已完整 -> ${track.title}');
        return track;
      }

      final source = await getWebDavSourceById(sourceId);
      final password = await getWebDavPassword(sourceId);
      if (source == null || password == null) {
        print('⚠️ WebDAV: 缺少源配置或密码 -> $sourceId');
        return track;
      }

      final client = await _createWebDavClient(source, password);
      final fullAudioPath = _combineRootAndRelative(
        source.rootPath,
        remotePath,
      );

      print('🌐 WebDAV: 尝试补充元数据 -> $fullAudioPath');

      final metadataFullPath = _replaceExtension(fullAudioPath, '.json');
      final metadata = await _loadWebDavTrackMetadata(
        client,
        metadataFullPath,
      );

      final coverCandidates = <String>[];
      if (metadata?.coverFileName != null) {
        coverCandidates.add(
          _normalizeRemotePath(
            posix.join(
              posix.dirname(fullAudioPath),
              metadata!.coverFileName!,
            ),
          ),
        );
      }
      coverCandidates.add(_replaceExtension(fullAudioPath, '.png'));

      String? artworkPath = track.artworkPath;
      for (final candidate in coverCandidates) {
        artworkPath = await _downloadWebDavArtwork(
          client: client,
          sourceId: sourceId,
          remoteArtworkPath: candidate,
          previousArtworkPath: artworkPath,
        );
        if (artworkPath != null && artworkPath.isNotEmpty) {
          break;
        }
      }

      final updatedModel = TrackModel.fromEntity(track).copyWith(
        title: metadata?.title ?? track.title,
        artist: metadata?.artist ?? metadata?.albumArtist ?? track.artist,
        album: metadata?.album ?? track.album,
        duration: metadata?.duration ?? track.duration,
        trackNumber: metadata?.trackNumber ?? track.trackNumber,
        year: metadata?.year ?? track.year,
        genre: metadata?.genre ?? track.genre,
        artworkPath: artworkPath ?? track.artworkPath,
        sourceType: TrackSourceType.webdav,
        sourceId: sourceId,
        remotePath: remotePath,
      );

      await _localDataSource.updateTrack(updatedModel);
      print('🌐 WebDAV: 元数据更新完成 -> ${updatedModel.title}');
      return updatedModel.toEntity();
    } catch (e) {
      print('⚠️ WebDAV: 自动补全元数据失败 -> $e');
      return track;
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

  @override
  Future<List<String>> getLibraryDirectories() async {
    await _configStore.init();
    final raw = _configStore.getValue<dynamic>(StorageKeys.libraryDirectories);
    if (raw is List) {
      final cleaned = raw
          .whereType<String>()
          .map((value) => path.normalize(value.trim()))
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      cleaned.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return cleaned;
    }
    return const [];
  }

  @override
  Future<List<WebDavSource>> getWebDavSources() async {
    await _configStore.init();
    final raw = _configStore.getValue<dynamic>(StorageKeys.webDavSources);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (map) => WebDavSourceModel.fromMap(
              map.cast<String, dynamic>(),
            ).toEntity(),
          )
          .toList();
    }
    return const [];
  }

  @override
  Future<WebDavSource?> getWebDavSourceById(String id) async {
    final sources = await getWebDavSources();
    try {
      return sources.firstWhere((source) => source.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveWebDavSource(WebDavSource source, {String? password}) async {
    await _configStore.init();
    final normalized = source.copyWith(
      baseUrl: _normalizeBaseUrl(source.baseUrl),
      rootPath: _normalizeRemotePath(source.rootPath),
      updatedAt: DateTime.now(),
      createdAt: source.createdAt ?? DateTime.now(),
    );

    final existing = await getWebDavSources();
    final models = <WebDavSourceModel>[];
    for (final item in existing) {
      final isSameIdentity =
          item.baseUrl == normalized.baseUrl &&
          item.rootPath == normalized.rootPath &&
          (item.username ?? '') == (normalized.username ?? '');
      if (item.id == normalized.id || isSameIdentity) {
        continue;
      }
      models.add(WebDavSourceModel.fromEntity(item));
    }
    models.add(WebDavSourceModel.fromEntity(normalized));

    final serialized = models.map((model) => model.toMap()).toList();

    await _configStore.setValue(StorageKeys.webDavSources, serialized);

    if (password != null) {
      await _setWebDavPassword(normalized.id, password);
    }
  }

  @override
  Future<void> deleteWebDavSource(String id) async {
    await _configStore.init();
    final existing = await getWebDavSources();
    final filtered = existing.where((source) => source.id != id).toList();
    final serialized = filtered
        .map((source) => WebDavSourceModel.fromEntity(source).toMap())
        .toList();
    await _configStore.setValue(StorageKeys.webDavSources, serialized);
    await _removeWebDavPassword(id);

    final tracks = await _localDataSource.getTracksByWebDavSource(id);
    if (tracks.isNotEmpty) {
      await _localDataSource.deleteTracksByIds(
        tracks.map((track) => track.id).toList(),
      );
    }
  }

  @override
  Future<String?> getWebDavPassword(String id) async {
    final passwords = await _loadWebDavPasswords();
    return passwords[id];
  }

  @override
  Future<void> testWebDavConnection({
    required WebDavSource source,
    required String password,
  }) async {
    final normalizedSource = source.copyWith(
      baseUrl: _normalizeBaseUrl(source.baseUrl),
      rootPath: _normalizeRemotePath(source.rootPath),
    );
    print(
      '🌐 WebDAV: 正在测试连接 -> ${normalizedSource.baseUrl}${normalizedSource.rootPath}',
    );
    final client = await _createWebDavClient(normalizedSource, password);
    try {
      await client.readDir(normalizedSource.rootPath);
      print('✅ WebDAV: 连接测试成功');
    } catch (e) {
      print('❌ WebDAV: 连接测试失败 -> $e');
      throw FileSystemException('WebDAV 连接失败: ${e.toString()}');
    }
  }

  @override
  Future<List<WebDavEntry>> listWebDavDirectory({
    required WebDavSource source,
    required String password,
    required String path,
  }) async {
    final normalizedSource = source.copyWith(
      baseUrl: _normalizeBaseUrl(source.baseUrl),
      rootPath: _normalizeRemotePath(source.rootPath),
    );
    final client = await _createWebDavClient(normalizedSource, password);
    try {
      final targetPath = _normalizeRemotePath(path);
      print('🌐 WebDAV: 列取目录 $targetPath');
      final entries = await client.readDir(targetPath);
      final result = <WebDavEntry>[];
      for (final entry in entries) {
        final name = entry.name ?? '';
        final entryPath = _normalizeRemotePath(
          entry.path ?? posix.join(targetPath, name),
        );
        final isDir = entry.isDir ?? false;
        result.add(
          WebDavEntry(
            name: name.isEmpty ? entryPath : name,
            path: entryPath,
            isDirectory: isDir,
          ),
        );
      }
      result.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return result;
    } catch (e) {
      print('❌ WebDAV: 列取目录失败 [$path] -> $e');
      throw FileSystemException('读取 WebDAV 目录失败: ${e.toString()}');
    }
  }

  Future<List<File>> _findAudioFiles(Directory directory) async {
    final audioFiles = <File>[];

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if (_supportedAudioExtensions.contains(extension)) {
          audioFiles.add(entity);
        }
      }
    }

    return audioFiles;
  }

  Future<TrackModel?> _createTrackFromFile(
    File file, {
    TrackModel? existingTrack,
  }) async {
    try {
      // Read metadata
      final metadata = await readMetadata(file, getImage: true);

      final title = metadata?.title ?? path.basenameWithoutExtension(file.path);
      final artist = metadata?.artist ?? 'Unknown Artist';
      final album = metadata?.album ?? 'Unknown Album';
      final duration = metadata?.duration ?? Duration.zero;
      final year = metadata?.year?.year;
      final trackNumber = metadata?.trackNumber;
      final genre = metadata?.genres?.isNotEmpty == true
          ? metadata!.genres!.first
          : null;

      final artworkPath = await _saveArtwork(
        metadata,
        previousArtworkPath: existingTrack?.artworkPath,
      );

      return TrackModel(
        id: existingTrack?.id ?? _uuid.v4(),
        title: title,
        artist: artist,
        album: album,
        filePath: file.path,
        duration: duration,
        dateAdded: existingTrack?.dateAdded ?? DateTime.now(),
        artworkPath: artworkPath,
        trackNumber: trackNumber,
        year: year,
        genre: genre,
        sourceType: TrackSourceType.local,
      );
    } catch (e) {
      print('Error reading metadata for ${file.path}: $e');

      // Fallback: create track with filename only
      return TrackModel(
        id: existingTrack?.id ?? _uuid.v4(),
        title: path.basenameWithoutExtension(file.path),
        artist: existingTrack?.artist ?? 'Unknown Artist',
        album: existingTrack?.album ?? 'Unknown Album',
        filePath: file.path,
        duration: existingTrack?.duration ?? Duration.zero,
        dateAdded: existingTrack?.dateAdded ?? DateTime.now(),
        artworkPath: existingTrack?.artworkPath,
        trackNumber: existingTrack?.trackNumber,
        year: existingTrack?.year,
        genre: existingTrack?.genre,
        sourceType: existingTrack?.sourceType ?? TrackSourceType.local,
      );
    }
  }

  Future<String?> _saveArtwork(
    AudioMetadata? metadata, {
    String? previousArtworkPath,
  }) async {
    if (metadata == null || metadata.pictures.isEmpty) {
      return previousArtworkPath;
    }

    final picture = metadata.pictures.first;
    if (picture.bytes.isEmpty) {
      return previousArtworkPath;
    }

    final extension = _extensionFromMimeType(picture.mimetype);
    final cacheDir = await _artworkCacheDirectory();
    final filePath = path.join(cacheDir.path, '${_uuid.v4()}$extension');

    final file = File(filePath);
    await file.writeAsBytes(picture.bytes, flush: true);

    if (previousArtworkPath != null && previousArtworkPath != filePath) {
      final previousFile = File(previousArtworkPath);
      if (await previousFile.exists()) {
        await previousFile.delete();
      }
    }

    return filePath;
  }

  Future<Directory> _artworkCacheDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final cacheDir = Directory(
      path.join(supportDir.path, AppConstants.artworkCacheDir),
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  String _extensionFromMimeType(String mimetype) {
    switch (mimetype.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/bmp':
        return '.bmp';
      default:
        return '.img';
    }
  }

  Future<void> _registerLibraryDirectory(String directoryPath) async {
    await _configStore.init();
    final raw = _configStore.getValue<dynamic>(StorageKeys.libraryDirectories);
    final Set<String> directories = {
      if (raw is List)
        ...raw.whereType<String>().map((e) => path.normalize(e.trim())),
    };
    final normalized = path.normalize(directoryPath);
    if (directories.add(normalized)) {
      final sorted = directories.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await _configStore.setValue(StorageKeys.libraryDirectories, sorted);
    }
  }

  String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _normalizeRemotePath(String remotePath) {
    var normalized = remotePath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '/';
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _removeExtension(String remotePath) {
    final extension = posix.extension(remotePath);
    if (extension.isEmpty) {
      return remotePath;
    }
    return remotePath.substring(0, remotePath.length - extension.length);
  }

  String _replaceExtension(String remotePath, String newExtension) {
    return '${_removeExtension(remotePath)}$newExtension';
  }

  String? _extractSourceId(String filePath) {
    const prefix = 'webdav://';
    if (!filePath.startsWith(prefix)) {
      return null;
    }
    final remainder = filePath.substring(prefix.length);
    final slashIndex = remainder.indexOf('/');
    if (slashIndex <= 0) {
      return null;
    }
    return remainder.substring(0, slashIndex);
  }

  String? _extractRemotePath(String filePath, String? sourceId) {
    const prefix = 'webdav://';
    if (!filePath.startsWith(prefix)) {
      return null;
    }
    final remainder = filePath.substring(prefix.length);
    final slashIndex = remainder.indexOf('/');
    if (slashIndex == -1) {
      return null;
    }
    final remote = remainder.substring(slashIndex);
    return _normalizeRemotePath(remote);
  }

  String _combineRootAndRelative(String rootPath, String relativePath) {
    final normalizedRoot = _normalizeRemotePath(rootPath);
    final normalizedRelative = _normalizeRemotePath(relativePath);
    if (normalizedRoot == '/') {
      return normalizedRelative;
    }
    if (normalizedRelative == '/') {
      return normalizedRoot;
    }
    return '$normalizedRoot$normalizedRelative';
  }

  Future<_WebDavTrackMetadata?> _loadWebDavTrackMetadata(
    webdav.Client client,
    String metadataPath,
  ) async {
    try {
      final raw = await client.read(metadataPath);
      if (raw.isEmpty) {
        print('⚠️ WebDAV: 元数据文件为空 -> $metadataPath');
        return null;
      }

      final decoded = json.decode(utf8.decode(raw)) as Map<String, dynamic>;
      final durationMs = _parseNullableInt(decoded['duration_ms']);
      final trackNumber = _parseNullableInt(decoded['track_number']);
      final discNumber = _parseNullableInt(decoded['disc_number']);
      final year = _parseNullableInt(decoded['year']);

      return _WebDavTrackMetadata(
        title: decoded['title'] as String?,
        artist: decoded['artist'] as String?,
        album: decoded['album'] as String?,
        albumArtist: decoded['album_artist'] as String?,
        genre: decoded['genre'] as String?,
        year: year,
        trackNumber: trackNumber,
        discNumber: discNumber,
        duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
        fingerprint: decoded['hash_sha1_first_10kb'] as String?,
        hasCover: decoded['has_cover'] == true,
        coverFileName: decoded['cover_file'] as String?,
      );
    } catch (e) {
      print('⚠️ WebDAV: 读取元数据失败 [$metadataPath] - $e');
      return null;
    }
  }

  Future<String?> _downloadWebDavArtwork({
    required webdav.Client client,
    required String sourceId,
    required String remoteArtworkPath,
    String? previousArtworkPath,
  }) async {
    try {
      final bytes = await client.read(remoteArtworkPath);
      if (bytes.isEmpty) {
        print('⚠️ WebDAV: 封面文件为空 -> $remoteArtworkPath');
        return previousArtworkPath;
      }

      final extension = posix.extension(remoteArtworkPath);
      final normalizedExtension =
          extension.isNotEmpty ? extension.toLowerCase() : '.png';
      final digest = sha1.convert(
        utf8.encode('$sourceId|$remoteArtworkPath'),
      );
      final cacheDir = await _artworkCacheDirectory();
      final filePath = path.join(
        cacheDir.path,
        '${digest.toString()}$normalizedExtension',
      );

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      print('🌐 WebDAV: 封面已缓存 -> $filePath');

      if (previousArtworkPath != null && previousArtworkPath != filePath) {
        final previous = File(previousArtworkPath);
        if (await previous.exists()) {
          print('🌐 WebDAV: 清理旧封面 -> $previousArtworkPath');
          await previous.delete();
        }
      }

      return filePath;
    } catch (e) {
      print('⚠️ WebDAV: 下载封面失败 [$remoteArtworkPath] - $e');
      return previousArtworkPath;
    }
  }

  int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      for (final separator in ['/', '-', ';']) {
        if (trimmed.contains(separator)) {
          return _parseNullableInt(trimmed.split(separator).first);
        }
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  String _relativeRemotePath(String rootPath, String fullPath) {
    final normalizedRoot = _normalizeRemotePath(rootPath);
    final normalizedFull = _normalizeRemotePath(fullPath);
    if (!normalizedFull.startsWith(normalizedRoot)) {
      return normalizedFull;
    }
    final slice = normalizedFull.substring(normalizedRoot.length);
    if (slice.isEmpty) {
      return '/';
    }
    return slice.startsWith('/') ? slice : '/$slice';
  }

  String _buildWebDavFilePath(String sourceId, String relativePath) {
    final normalized = _normalizeRemotePath(relativePath);
    return 'webdav://$sourceId$normalized';
  }

  Future<Map<String, String>> _loadWebDavPasswords() async {
    await _configStore.init();
    final raw = _configStore.getValue<dynamic>(StorageKeys.webDavPasswords);
    if (raw is Map) {
      final result = <String, String>{};
      raw.forEach((key, value) {
        if (key is String && value is String) {
          result[key] = value;
        }
      });
      return result;
    }
    return {};
  }

  Future<void> _setWebDavPassword(String sourceId, String password) async {
    final map = await _loadWebDavPasswords();
    map[sourceId] = password;
    await _configStore.setValue(StorageKeys.webDavPasswords, map);
  }

  Future<void> _removeWebDavPassword(String sourceId) async {
    final map = await _loadWebDavPasswords();
    if (map.remove(sourceId) != null) {
      await _configStore.setValue(StorageKeys.webDavPasswords, map);
    }
  }

  Future<webdav.Client> _createWebDavClient(
    WebDavSource source,
    String password,
  ) async {
    final client = webdav.newClient(
      source.baseUrl,
      user: source.username ?? '',
      password: password,
    );

    client.setHeaders({'User-Agent': 'MisuzuMusic/1.0'});

    if (source.ignoreTls) {
      final adapter = client.c.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final httpClient = HttpClient();
          httpClient.badCertificateCallback = (cert, host, port) => true;
          return httpClient;
        };
      }
    }

    return client;
  }

  Future<List<_RemoteAudioFile>> _collectRemoteAudioFiles(
    webdav.Client client,
    String rootPath,
  ) async {
    final aggregates = <String, _RemoteFileAggregate>{};
    final queue = <String>[_normalizeRemotePath(rootPath)];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current)) {
        continue;
      }

      List<webdav.File> entries;
      try {
        entries = await client.readDir(current);
      } catch (e) {
        print('⚠️ WebDAV: 读取目录失败 [$current] - $e');
        continue;
      }

      for (final entry in entries) {
        final name = entry.name ?? '';
        final pathValue = entry.path ?? posix.join(current, name);
        final normalizedPath = _normalizeRemotePath(pathValue);

        final isDir = entry.isDir ?? false;
        if (isDir) {
          queue.add(normalizedPath);
          continue;
        }

        final extension = posix.extension(normalizedPath).toLowerCase();
        final relativePath = _relativeRemotePath(rootPath, normalizedPath);
        final baseKey = _removeExtension(relativePath);
        final aggregate = aggregates.putIfAbsent(
          baseKey,
          () => _RemoteFileAggregate(baseKey: baseKey),
        );

        if (_supportedAudioExtensions.contains(extension)) {
          aggregate.audioFullPath = normalizedPath;
          aggregate.audioRelativePath = relativePath;
          final title = posix.basenameWithoutExtension(normalizedPath);
          aggregate.title = title.isNotEmpty ? title : name;
        } else if (extension == '.json') {
          print('🌐 WebDAV: 发现元数据文件 -> $normalizedPath');
          aggregate.metadataFullPath = normalizedPath;
          aggregate.metadataRelativePath = relativePath;
        } else if (extension == '.png') {
          print('🌐 WebDAV: 发现封面文件 -> $normalizedPath');
          aggregate.artworkFullPath = normalizedPath;
          aggregate.artworkRelativePath = relativePath;
        }
      }
    }

    final results = <_RemoteAudioFile>[];
    for (final aggregate in aggregates.values) {
      if (aggregate.audioFullPath == null ||
          aggregate.audioRelativePath == null) {
        continue;
      }
      results.add(aggregate.toRemoteAudioFile());
    }

    return results;
  }
}

class _RemoteAudioFile {
  const _RemoteAudioFile({
    required this.fullPath,
    required this.relativePath,
    required this.title,
    this.metadataPath,
    this.metadataRelativePath,
    this.artworkPath,
    this.artworkRelativePath,
  });

  final String fullPath;
  final String relativePath;
  final String title;
  final String? metadataPath;
  final String? metadataRelativePath;
  final String? artworkPath;
  final String? artworkRelativePath;
}

class _RemoteFileAggregate {
  _RemoteFileAggregate({required this.baseKey});

  final String baseKey;
  String? audioFullPath;
  String? audioRelativePath;
  String? metadataFullPath;
  String? metadataRelativePath;
  String? artworkFullPath;
  String? artworkRelativePath;
  String? title;

  _RemoteAudioFile toRemoteAudioFile() {
    return _RemoteAudioFile(
      fullPath: audioFullPath!,
      relativePath: audioRelativePath!,
      title: title ?? posix.basenameWithoutExtension(audioFullPath!),
      metadataPath: metadataFullPath,
      metadataRelativePath: metadataRelativePath,
      artworkPath: artworkFullPath,
      artworkRelativePath: artworkRelativePath,
    );
  }
}

class _WebDavTrackMetadata {
  const _WebDavTrackMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.duration,
    this.fingerprint,
    this.hasCover = false,
    this.coverFileName,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final Duration? duration;
  final String? fingerprint;
  final bool hasCover;
  final String? coverFileName;
}
