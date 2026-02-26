import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import '../../core/constants/jellyfin_library_constants.dart';
import '../../core/constants/mystery_library_constants.dart';
import '../../core/utils/track_field_normalizer.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/entities/webdav_entities.dart';
import '../../domain/entities/jellyfin_entities.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../datasources/local/music_local_datasource.dart';
import '../datasources/remote/netease_api_client.dart';
import '../models/music_models.dart';
import '../models/jellyfin_models.dart';
import '../models/webdav_bundle.dart';
import '../models/webdav_models.dart';
import '../services/cloud_playlist_api.dart';
import '../services/netease_id_resolver.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/audio_extensions.dart';

class MusicLibraryRepositoryImpl implements MusicLibraryRepository {
  final MusicLocalDataSource _localDataSource;
  final BinaryConfigStore _configStore;
  final NeteaseApiClient _neteaseApiClient;
  final NeteaseIdResolver _neteaseIdResolver;
  final CloudPlaylistApi _cloudPlaylistApi;
  final Uuid _uuid = const Uuid();
  static const String _bundleRelativePath = '/.misuzu/library.bundle';
  static const String _playlogDirRelative = '/.misuzu/playlogs';
  static const int _playLogVersion = 1;
  static const String _coverHeaderKey = 'x-misuzu-cover-file';
  static const String _thumbnailHeaderKey = 'x-misuzu-thumbnail-file';

  MusicLibraryRepositoryImpl({
    required MusicLocalDataSource localDataSource,
    required BinaryConfigStore configStore,
    required NeteaseApiClient neteaseApiClient,
    required NeteaseIdResolver neteaseIdResolver,
    required CloudPlaylistApi cloudPlaylistApi,
  }) : _localDataSource = localDataSource,
       _configStore = configStore,
       _neteaseApiClient = neteaseApiClient,
       _neteaseIdResolver = neteaseIdResolver,
       _cloudPlaylistApi = cloudPlaylistApi;

  final Map<String, String?> _neteaseArtworkCache = {};
  final StreamController<Track> _trackUpdateController =
      StreamController<Track>.broadcast();

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
  Future<List<Track>> importLocalTracks(
    List<String> filePaths, {
    bool addToLibrary = true,
  }) async {
    final result = <Track>[];
    final seen = <String>{};

    for (final rawPath in filePaths) {
      try {
        final file = File(rawPath);
        if (!file.existsSync()) {
          continue;
        }

        final normalizedPath = path.normalize(file.absolute.path);
        if (!seen.add(normalizedPath)) {
          continue;
        }

        final extension = path.extension(normalizedPath).toLowerCase();
        if (!kSupportedAudioFileExtensions.contains(extension)) {
          continue;
        }

        final existing =
            await _localDataSource.getTrackByFilePath(normalizedPath);
        final trackModel = await _createTrackFromFile(
          file,
          existingTrack: existing,
        );
        if (trackModel == null) {
          continue;
        }

        if (addToLibrary) {
          if (existing != null) {
            await _localDataSource.updateTrack(trackModel);
          } else {
            await _localDataSource.insertTrack(trackModel);
          }
        }

        result.add(trackModel.toEntity());
      } catch (e) {
        print('❌ 导入外部音频失败 [$rawPath] -> $e');
      }
    }

    return result;
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
      _emitTrackUpdate(track);
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
  Stream<Track> watchTrackUpdates() {
    return _trackUpdateController.stream;
  }

  @override
  Future<Track?> fetchArtworkForTrack(Track track) async {
    if (track.sourceType != TrackSourceType.local &&
        track.sourceType != TrackSourceType.webdav) {
      return null;
    }
    if ((track.artworkPath ?? '').isNotEmpty) {
      return track;
    }

    final path = await _fetchArtworkFromNetease(
      title: track.title,
      artist: track.artist,
      album: track.album,
      previousArtworkPath: track.artworkPath,
      track: track,
    );

    if (path == null || path.isEmpty) {
      return null;
    }

    final updatedModel = TrackModel.fromEntity(
      track,
    ).copyWith(artworkPath: path);
    await _localDataSource.updateTrack(updatedModel);
    final updated = updatedModel.toEntity();
    _emitTrackUpdate(updated);
    return updated;
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
  Future<void> addTrackToPlaylist(String playlistId, String trackHash) async {
    try {
      await _localDataSource.addTrackToPlaylist(playlistId, trackHash, 0);
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
      await _localDataSource.removeTrackFromPlaylist(playlistId, trackHash);
    } catch (e) {
      throw DatabaseException(
        'Failed to remove track from playlist: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      final trackModels = await _localDataSource.getPlaylistTracks(playlistId);
      return trackModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get playlist tracks: ${e.toString()}');
    }
  }

  @override
  Future<void> uploadPlaylistToCloud({
    required String playlistId,
    required String remoteId,
  }) async {
    try {
      final bytes = await _localDataSource.exportPlaylistBinary(playlistId);
      if (bytes == null) {
        throw DatabaseException('未找到要上传的歌单', playlistId);
      }
      await _cloudPlaylistApi.uploadPlaylist(remoteId: remoteId, bytes: bytes);
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('上传歌单失败', e.toString());
    }
  }

  @override
  Future<Playlist?> downloadPlaylistFromCloud(String remoteId) async {
    try {
      final bytes = await _cloudPlaylistApi.downloadPlaylist(
        remoteId: remoteId,
      );
      final model = await _localDataSource.importPlaylistBinary(bytes);
      return model?.toEntity();
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('拉取云歌单失败', e.toString());
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
      final discoveredPaths = audioFiles
          .map((file) => path.normalize(file.absolute.path))
          .toSet();

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

      await _cleanupMissingLocalTracks(
        normalizedDirectory: normalizedPath,
        discoveredPaths: discoveredPaths,
      );
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
      final bundleBytes = await _downloadWebDavBundle(
        client,
        normalizedSource.rootPath,
      );
      if (bundleBytes != null) {
        // print('🌐 WebDAV: 使用二进制元数据包导入');
        try {
          await _importWebDavBundle(bundleBytes, normalizedSource);
          return;
        } catch (e) {
          print('⚠️ WebDAV: 解析元数据包失败 -> $e, 回退到目录扫描');
        }
      }

      // print(
      //   '🌐 WebDAV: 开始扫描 ${normalizedSource.baseUrl}${normalizedSource.rootPath}',
      // );
      final remoteFiles = await _collectRemoteAudioFiles(
        client,
        normalizedSource.rootPath,
      );
      // print('🌐 WebDAV: 发现 ${remoteFiles.length} 个音频候选');

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

        final fallbackFileName = remoteFile.title.isNotEmpty
            ? remoteFile.title
            : posix.basenameWithoutExtension(remoteFile.relativePath);
        final normalizedFields = normalizeTrackFields(
          title: existing?.title ?? fallbackFileName,
          artist: existing?.artist ?? 'Unknown Artist',
          album: existing?.album ?? 'Unknown Album',
          fallbackFileName: fallbackFileName,
        );
        final title = normalizedFields.title;
        final artist = normalizedFields.artist;
        final album = normalizedFields.album;
        final duration = existing?.duration ?? Duration.zero;
        final trackNumber = existing?.trackNumber;
        final year = existing?.year;
        final genre = existing?.genre;

        String? artworkPath = existing?.artworkPath;
        if (remoteFile.artworkPath != null) {
          // print('🌐 WebDAV: 发现同名封面 -> ${remoteFile.artworkPath}');
          artworkPath = await _downloadWebDavArtwork(
            client: client,
            sourceId: normalizedSource.id,
            remoteArtworkPath: remoteFile.artworkPath!,
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
          contentHash: existing?.contentHash ?? filePathKey,
          bitrate: existing?.bitrate,
          sampleRate: existing?.sampleRate,
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
      throw FileSystemException('扫描 WebDAV 目录失败: ${e.toString()}');
    }
  }

  @override
  Future<void> scanJellyfinLibrary({
    required JellyfinSource source,
    required String accessToken,
  }) async {
    var normalizedSource = source.copyWith(
      baseUrl: _normalizeBaseUrl(source.baseUrl),
      updatedAt: DateTime.now(),
      createdAt: source.createdAt ?? DateTime.now(),
    );

    final savedSources = await getJellyfinSources();
    JellyfinSource? existingSource;
    for (final item in savedSources) {
      final sameIdentity =
          item.baseUrl == normalizedSource.baseUrl &&
          item.userId == normalizedSource.userId &&
          item.libraryId == normalizedSource.libraryId;
      if (sameIdentity || item.id == normalizedSource.id) {
        existingSource = item;
        break;
      }
    }

    if (existingSource != null && existingSource.id != normalizedSource.id) {
      normalizedSource = JellyfinSource(
        id: existingSource.id,
        name: normalizedSource.name,
        baseUrl: normalizedSource.baseUrl,
        userId: normalizedSource.userId,
        libraryId: normalizedSource.libraryId,
        username: normalizedSource.username,
        libraryName: normalizedSource.libraryName,
        serverName: normalizedSource.serverName ?? existingSource.serverName,
        ignoreTls: normalizedSource.ignoreTls,
        createdAt: existingSource.createdAt,
        updatedAt: DateTime.now(),
      );
    }

    await _saveJellyfinSource(normalizedSource, accessToken: accessToken);

    try {
      final items = await _fetchJellyfinAudioItems(
        source: normalizedSource,
        accessToken: accessToken,
      );

      final existingTracks = await _localDataSource.getTracksBySource(
        TrackSourceType.jellyfin,
        normalizedSource.id,
      );
      final existingById = {
        for (final track in existingTracks) track.id: track,
      };

      final seenIds = <String>{};
      final now = DateTime.now();

      for (final item in items) {
        final itemId = _readNonEmptyString(item['Id']);
        if (itemId == null || itemId.isEmpty) {
          continue;
        }

        final trackId = _buildJellyfinTrackId(normalizedSource.id, itemId);
        final existing = existingById[trackId];

        final titleRaw =
            _readNonEmptyString(item['Name']) ?? existing?.title ?? itemId;
        final artistRaw =
            _joinJellyfinNames(item['Artists']) ??
            _joinJellyfinNames(item['AlbumArtists']) ??
            _readNonEmptyString(item['AlbumArtist']) ??
            existing?.artist;
        final albumRaw =
            _readNonEmptyString(item['Album']) ?? existing?.album;

        final normalizedFields = normalizeTrackFields(
          title: titleRaw,
          artist: artistRaw ?? 'Unknown Artist',
          album: albumRaw ?? 'Unknown Album',
          fallbackFileName: titleRaw,
        );

        final duration =
            _parseJellyfinDuration(item['RunTimeTicks']) ??
            existing?.duration ??
            Duration.zero;
        final trackNumber =
            _parseNullableInt(item['IndexNumber']) ?? existing?.trackNumber;
        final year =
            _parseNullableInt(item['ProductionYear']) ?? existing?.year;
        final genre =
            _joinJellyfinNames(item['Genres']) ?? existing?.genre;
        final dateAdded =
            _parseJellyfinDate(item['DateCreated']) ??
            existing?.dateAdded ??
            now;

        final bitrate = _parseJellyfinBitrate(item) ?? existing?.bitrate;
        final sampleRate =
            _parseJellyfinSampleRate(item) ?? existing?.sampleRate;

        final imageTag = _readPrimaryImageTag(item);
        final artworkUrl = _buildJellyfinImageUrl(
          baseUrl: normalizedSource.baseUrl,
          itemId: itemId,
          accessToken: accessToken,
          tag: imageTag,
        );

        final headers = <String, String>{
          if (existing?.httpHeaders != null) ...existing!.httpHeaders!,
          JellyfinLibraryConstants.headerItemId: itemId,
          JellyfinLibraryConstants.headerLibraryId: normalizedSource.libraryId,
          if (normalizedSource.serverName != null &&
              normalizedSource.serverName!.isNotEmpty)
            JellyfinLibraryConstants.headerServerName:
                normalizedSource.serverName!,
          if (artworkUrl != null && artworkUrl.isNotEmpty)
            JellyfinLibraryConstants.headerImageUrl: artworkUrl,
        };

        final trackModel = TrackModel(
          id: trackId,
          title: normalizedFields.title,
          artist: normalizedFields.artist,
          album: normalizedFields.album,
          filePath: _buildJellyfinFilePath(normalizedSource.id, itemId),
          duration: duration,
          dateAdded: dateAdded,
          artworkPath: existing?.artworkPath,
          trackNumber: trackNumber,
          year: year,
          genre: genre,
          sourceType: TrackSourceType.jellyfin,
          sourceId: normalizedSource.id,
          remotePath: itemId,
          httpHeaders: headers,
          contentHash: existing?.contentHash ?? trackId,
          bitrate: bitrate,
          sampleRate: sampleRate,
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
      print('❌ Jellyfin: 扫描媒体库失败 -> $e');
      throw NetworkException('扫描 Jellyfin 媒体库失败: ${e.toString()}');
    }
  }

  @override
  Future<int> mountMysteryLibrary({
    required Uri baseUri,
    required String code,
  }) async {
    final normalizedCode = code.trim().toLowerCase();
    if (normalizedCode.isEmpty) {
      throw const NetworkException('神秘代码不能为空');
    }

    final resolvedBase = baseUri.scheme.isEmpty
        ? Uri.parse(MysteryLibraryConstants.defaultBaseUrl)
        : baseUri;
    final sourceId = _buildMysterySourceId(normalizedCode);
    final displayName = '神秘代码 $normalizedCode';

    final client = HttpClient()..userAgent = 'MisuzuMusic/1.0';

    try {
      final listUri = resolvedBase.replace(
        queryParameters: {'action': 'list', 'code': normalizedCode},
      );

      final payload = await _fetchMysteryJson(client, listUri);
      final tracksRaw = payload['tracks'];
      if (tracksRaw is! List) {
        throw const NetworkException('挂载神秘代码失败', '返回数据格式不正确');
      }

      final existingTracks = await _localDataSource.getTracksBySource(
        TrackSourceType.mystery,
        sourceId,
      );
      final existingById = {
        for (final track in existingTracks) track.id: track,
      };

      final now = DateTime.now();
      final seenIds = <String>{};
      var imported = 0;

      for (final rawTrack in tracksRaw) {
        if (rawTrack is! Map<String, dynamic>) {
          continue;
        }

        final relativeValue = rawTrack['relative_path'] as String?;
        if (relativeValue == null || relativeValue.trim().isEmpty) {
          continue;
        }
        final relativePath = _normalizeMysteryRelativePath(relativeValue);
        final metadata =
            (rawTrack['metadata'] as Map<String, dynamic>?) ?? const {};
        final tags = (metadata['tags'] as Map<String, dynamic>?) ?? const {};

        final trackId = sha1
            .convert(utf8.encode('$sourceId|$relativePath'))
            .toString();
        final existing = existingById[trackId];

        final title =
            _readNonEmptyString(metadata['title']) ??
            path.basenameWithoutExtension(relativePath);
        final artist =
            _readNonEmptyString(metadata['artist']) ??
            _readNonEmptyString(tags['artist']) ??
            _readNonEmptyString(tags['album_artist']) ??
            'Unknown Artist';
        final album =
            _readNonEmptyString(metadata['album']) ??
            _readNonEmptyString(tags['album']) ??
            'Unknown Album';

        final duration = _parseMysteryDuration(metadata, existing?.duration);
        final trackNumber =
            _parseNullableInt(tags['track']) ??
            _parseNullableInt(tags['tracknumber']);
        final year =
            _parseNullableInt(tags['year']) ?? _parseNullableInt(tags['date']);
        final genre =
            _readNonEmptyString(metadata['genre']) ??
            _readNonEmptyString(tags['genre']);
        final bitrate =
            _parseNullableInt(metadata['bitrate']) ??
            _parseNullableInt(tags['bitrate']) ??
            existing?.bitrate;
        final sampleRate =
            _parseNullableInt(metadata['sample_rate']) ??
            _parseNullableInt(tags['sample_rate']) ??
            _parseNullableInt(tags['samplerate']) ??
            existing?.sampleRate;

        final coverRemote = rawTrack['cover_path'] as String?;
        final thumbRemote = rawTrack['thumbnail_path'] as String?;

        String? effectiveArtworkPath;
        final previousArtworkPath = existing?.artworkPath;
        if (previousArtworkPath != null && previousArtworkPath.isNotEmpty) {
          final previousFile = File(previousArtworkPath);
          if (previousFile.existsSync()) {
            effectiveArtworkPath = previousArtworkPath;
          }
        }

        final headers = <String, String>{
          if (existing?.httpHeaders != null) ...existing!.httpHeaders!,
          MysteryLibraryConstants.headerBaseUrl: resolvedBase.toString(),
          MysteryLibraryConstants.headerCode: normalizedCode,
          MysteryLibraryConstants.headerDisplayName: displayName,
          if (coverRemote != null)
            MysteryLibraryConstants.headerCoverRemote:
                _normalizeMysteryRelativePath(coverRemote),
          if (thumbRemote != null)
            MysteryLibraryConstants.headerThumbnailRemote:
                _normalizeMysteryRelativePath(thumbRemote),
        };

        headers.remove(MysteryLibraryConstants.headerCoverLocal);
        headers.remove(MysteryLibraryConstants.headerThumbnailLocal);

        final contentHash = existing?.contentHash ?? trackId;

        final model = TrackModel(
          id: trackId,
          title: title,
          artist: artist,
          album: album,
          filePath: _buildMysteryFilePath(sourceId, relativePath),
          duration: duration,
          dateAdded: existing?.dateAdded ?? now,
          artworkPath: effectiveArtworkPath,
          trackNumber: trackNumber ?? existing?.trackNumber,
          year: year ?? existing?.year,
          genre: genre ?? existing?.genre,
          sourceType: TrackSourceType.mystery,
          sourceId: sourceId,
          remotePath: relativePath,
          httpHeaders: headers,
          contentHash: contentHash,
          bitrate: bitrate,
          sampleRate: sampleRate,
        );

        if (existing == null) {
          await _localDataSource.insertTrack(model);
        } else {
          await _localDataSource.updateTrack(model);
          _emitTrackUpdate(model.toEntity());
        }

        seenIds.add(trackId);
        imported++;
      }

      final removedIds = existingTracks
          .where((track) => !seenIds.contains(track.id))
          .map((track) => track.id)
          .toList();
      if (removedIds.isNotEmpty) {
        await _localDataSource.deleteTracksByIds(removedIds);
        print('🕵️ Mystery: 已移除 ${removedIds.length} 首失效曲目');
      }

      print('🕵️ Mystery: 导入 $imported 首歌曲');
      return imported;
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('挂载神秘代码失败', e.toString());
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> unmountMysteryLibrary(String sourceId) async {
    try {
      final tracks = await _localDataSource.getTracksBySource(
        TrackSourceType.mystery,
        sourceId,
      );
      if (tracks.isEmpty) {
        return;
      }
      final ids = tracks.map((track) => track.id).toList();
      await _localDataSource.deleteTracksByIds(ids);
      print('🕵️ Mystery: 已卸载 $sourceId, 删除 ${ids.length} 首歌曲');
    } catch (e) {
      throw FileSystemException('卸载神秘音乐库失败', e.toString());
    }
  }

  @override
  Future<void> removeLibraryDirectory(String directoryPath) async {
    final normalizedDirectory = path.normalize(directoryPath);
    try {
      await _configStore.init();
      final raw = _configStore.getValue<dynamic>(
        StorageKeys.libraryDirectories,
      );
      final directories = <String>[
        if (raw is List)
          ...raw.whereType<String>().map((dir) => path.normalize(dir.trim())),
      ];

      final before = directories.length;
      directories.removeWhere((dir) => dir == normalizedDirectory);
      if (directories.length != before) {
        directories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        await _configStore.setValue(
          StorageKeys.libraryDirectories,
          directories,
        );
      }

      final allTracks = await _localDataSource.getAllTracks();
      final idsToRemove = allTracks
          .where(
            (track) =>
                track.sourceType == TrackSourceType.local &&
                _isTrackWithinDirectory(track.filePath, normalizedDirectory),
          )
          .map((track) => track.id)
          .toList();

      if (idsToRemove.isNotEmpty) {
        await _localDataSource.deleteTracksByIds(idsToRemove);
      }
    } catch (e) {
      throw FileSystemException('Failed to remove directory: ${e.toString()}');
    }
  }

  @override
  Future<Track?> ensureWebDavTrackMetadata(
    Track track, {
    bool force = false,
  }) async {
    try {
      final sourceId = track.sourceId ?? _extractSourceId(track.filePath);
      final remotePath =
          track.remotePath ?? _extractRemotePath(track.filePath, sourceId);

      if (sourceId == null || remotePath == null) {
        print('⚠️ WebDAV: 无法解析远程路径 -> ${track.filePath}');
        return track;
      }

      final needsMetadata =
          force ||
          track.duration <= Duration.zero ||
          track.artist.toLowerCase() == 'unknown artist' ||
          track.album.toLowerCase() == 'unknown album' ||
          (track.artworkPath == null || track.artworkPath!.isEmpty);

      if (!needsMetadata) {
        // print('🌐 WebDAV: 元数据已完整 -> ${track.title}');
        return track;
      }

      final source = await getWebDavSourceById(sourceId);
      final password = await getWebDavPassword(sourceId);
      if (source == null || password == null) {
        return track;
      }

      final client = await _createWebDavClient(source, password);
      final fullAudioPath = _combineRootAndRelative(
        source.rootPath,
        remotePath,
      );

      // print('🌐 WebDAV: 尝试补充元数据 -> $fullAudioPath');

      WebDavBundleEntry? bundleEntry;
      try {
        final bundleBytes = await _downloadWebDavBundle(
          client,
          source.rootPath,
        );
        if (bundleBytes != null) {
          final entries = WebDavBundleParser().parse(bundleBytes);
          for (final candidate in entries) {
            if (candidate.trackId == track.id) {
              bundleEntry = candidate;
              break;
            }
          }
        }
      } catch (e) {
        print('⚠️ WebDAV: 从元数据包查找音轨失败 -> $e');
        bundleEntry = null;
      }

      if (bundleEntry != null) {
        final metadata = bundleEntry.metadata;
        final title = (metadata['title'] as String?)?.trim();
        final artist = (metadata['artist'] as String?)?.trim();
        final album = (metadata['album'] as String?)?.trim();
        final durationMs = (metadata['duration_ms'] as num?)?.toInt() ?? 0;
        final trackNumber = (metadata['track_number'] as num?)?.toInt();
        final year = (metadata['year'] as num?)?.toInt();
        final genre = metadata['genre'] as String?;

        final artworkPath = await _cacheWebDavArtwork(
          sourceId,
          track.id,
          bundleEntry.artwork,
          previousArtworkPath: track.artworkPath,
        );

        final headers = <String, String>{
          if (metadata['cover_file'] is String)
            _coverHeaderKey: metadata['cover_file'] as String,
          if (metadata['thumbnail_file'] is String)
            _thumbnailHeaderKey: metadata['thumbnail_file'] as String,
        };
        if (track.httpHeaders != null) {
          headers.addAll(track.httpHeaders!);
        }

        final updatedModel = TrackModel.fromEntity(track).copyWith(
          title: title?.isNotEmpty == true
              ? title!
              : path.basenameWithoutExtension(bundleEntry.relativePath),
          artist: artist?.isNotEmpty == true ? artist! : track.artist,
          album: album?.isNotEmpty == true ? album! : track.album,
          duration: Duration(milliseconds: durationMs),
          trackNumber: trackNumber ?? track.trackNumber,
          year: year ?? track.year,
          genre: genre ?? track.genre,
          artworkPath: artworkPath ?? track.artworkPath,
          sourceType: TrackSourceType.webdav,
          sourceId: sourceId,
          remotePath: bundleEntry.relativePath,
          httpHeaders: headers.isEmpty ? track.httpHeaders : headers,
        );

        await _localDataSource.updateTrack(updatedModel);
        final updated = updatedModel.toEntity();
        _emitTrackUpdate(updated);
        // print('🌐 WebDAV: 元数据更新完成 (bundle) -> ${updatedModel.title}');
        return updated;
      }

      final coverCandidates = <String>[];
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

      // Fallback: Fetch from Netease if no artwork found on WebDAV
      if (artworkPath == null || artworkPath.isEmpty) {
        artworkPath = await _fetchArtworkFromNetease(
          title: track.title,
          artist: track.artist,
          album: track.album,
          previousArtworkPath: track.artworkPath,
          track: track,
        );
      }

      final remoteFileName = posix.basenameWithoutExtension(remotePath).trim();
      final fallbackFileName = remoteFileName.isNotEmpty
          ? remoteFileName
          : track.title;
      final normalizedFields = normalizeTrackFields(
        title: track.title,
        artist: track.artist,
        album: track.album,
        fallbackFileName: fallbackFileName,
      );

      final updatedModel = TrackModel.fromEntity(track).copyWith(
        title: normalizedFields.title,
        artist: normalizedFields.artist,
        album: normalizedFields.album,
        artworkPath: artworkPath ?? track.artworkPath,
        sourceType: TrackSourceType.webdav,
        sourceId: sourceId,
        remotePath: remotePath,
      );

      await _localDataSource.updateTrack(updatedModel);
      final updated = updatedModel.toEntity();
      _emitTrackUpdate(updated);
      // print('🌐 WebDAV: 元数据更新完成 -> ${updatedModel.title}');
      return updated;
    } catch (e) {
      print('⚠️ WebDAV: 自动补全元数据失败 -> $e');
      return track;
    }
  }

  @override
  Future<void> uploadWebDavPlayLog({
    required String sourceId,
    required String remotePath,
    required String trackId,
    required DateTime playedAt,
  }) async {
    if (trackId.isEmpty) {
      print('⚠️ WebDAV: 播放日志未上传，缺少 trackId');
      return;
    }

    final source = await getWebDavSourceById(sourceId);
    final password = await getWebDavPassword(sourceId);
    if (source == null || password == null) {
      print('⚠️ WebDAV: 无法上传播放日志，缺少源配置或密码 ($sourceId)');
      return;
    }

    try {
      final client = await _createWebDavClient(source, password);
      final timestampMs = playedAt.millisecondsSinceEpoch;
      final logFileName =
          'playlog_${timestampMs}_${_uuid.v4().replaceAll('-', '')}.bin';
      final remoteDir = _combineRootAndRelative(
        source.rootPath,
        _playlogDirRelative,
      );
      final remoteFilePath = _normalizeRemotePath(
        posix.join(remoteDir, logFileName),
      );

      final payload = _buildPlayLogPayload(timestampMs, trackId);
      await client.write(remoteFilePath, payload);
      final normalizedRemote = _normalizeRemotePath(remotePath);
      print('🌐 WebDAV: 上传播放日志 -> $remoteFilePath (track: $normalizedRemote)');
    } catch (e) {
      print('⚠️ WebDAV: 上传播放日志失败 -> $e');
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
      await _localDataSource.deleteDatabase();
      _neteaseArtworkCache.clear();
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
      final sources = raw
          .whereType<Map>()
          .map(
            (map) => WebDavSourceModel.fromMap(
              map.cast<String, dynamic>(),
            ).toEntity(),
          )
          .toList();
      await _cleanupOrphanWebDavTracks(sources);
      return sources;
    }
    await _cleanupOrphanWebDavTracks(const []);
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

  Future<void> _saveJellyfinSource(
    JellyfinSource source, {
    required String accessToken,
  }) async {
    await _configStore.init();
    final normalized = source.copyWith(
      baseUrl: _normalizeBaseUrl(source.baseUrl),
      updatedAt: DateTime.now(),
      createdAt: source.createdAt ?? DateTime.now(),
    );

    final existing = await getJellyfinSources();
    final models = <JellyfinSourceModel>[];
    for (final item in existing) {
      final sameIdentity =
          item.baseUrl == normalized.baseUrl &&
          item.userId == normalized.userId &&
          item.libraryId == normalized.libraryId;
      if (item.id == normalized.id || sameIdentity) {
        continue;
      }
      models.add(JellyfinSourceModel.fromEntity(item));
    }
    models.add(JellyfinSourceModel.fromEntity(normalized));

    final serialized = models.map((model) => model.toMap()).toList();
    await _configStore.setValue(StorageKeys.jellyfinSources, serialized);

    await _setJellyfinToken(normalized.id, accessToken);
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
  Future<JellyfinAuthSession> authenticateJellyfin({
    required String baseUrl,
    required String username,
    required String password,
    bool ignoreTls = false,
  }) async {
    final normalizedBase = _normalizeBaseUrl(baseUrl);
    final deviceId = await _getOrCreateJellyfinDeviceId();
    final client = _createJellyfinHttpClient(ignoreTls);

    try {
      final authUri = Uri.parse('$normalizedBase/Users/AuthenticateByName');
      final request = await client.postUrl(authUri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        'X-Emby-Authorization',
        _buildJellyfinClientInfo(deviceId),
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'MisuzuMusic/1.0');
      request.add(
        utf8.encode(
          json.encode({'Username': username, 'Pw': password}),
        ),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw NetworkException(
          'Jellyfin 认证失败',
          'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}\n$body',
        );
      }

      final decoded = json.decode(body);
      if (decoded is! Map) {
        throw const NetworkException('Jellyfin 返回数据异常');
      }

      final token = _readNonEmptyString(decoded['AccessToken']);
      final user = decoded['User'];
      final userId = user is Map ? _readNonEmptyString(user['Id']) : null;

      if (token == null || userId == null) {
        throw const NetworkException('Jellyfin 返回数据异常');
      }

      final serverName = await _fetchJellyfinServerName(
        client,
        normalizedBase,
        deviceId: deviceId,
      );

      return JellyfinAuthSession(
        accessToken: token,
        userId: userId,
        serverName: serverName,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<JellyfinLibrary>> getJellyfinLibraries({
    required String baseUrl,
    required String accessToken,
    required String userId,
    bool ignoreTls = false,
  }) async {
    final normalizedBase = _normalizeBaseUrl(baseUrl);
    final deviceId = await _getOrCreateJellyfinDeviceId();
    final client = _createJellyfinHttpClient(ignoreTls);

    try {
      final uri = Uri.parse('$normalizedBase/Users/$userId/Views');
      final data = await _fetchJellyfinJson(
        client,
        uri,
        accessToken: accessToken,
        deviceId: deviceId,
      );

      final items = data['Items'];
      if (items is! List) {
        return const [];
      }

      final results = <JellyfinLibrary>[];
      for (final raw in items) {
        if (raw is! Map) {
          continue;
        }
        final id = _readNonEmptyString(raw['Id']);
        final name = _readNonEmptyString(raw['Name']);
        if (id == null || name == null) {
          continue;
        }
        final collectionType =
            _readNonEmptyString(raw['CollectionType'])?.toLowerCase();
        if (collectionType != 'music') {
          continue;
        }
        results.add(
          JellyfinLibrary(
            id: id,
            name: name,
            collectionType: collectionType,
          ),
        );
      }

      results.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return results;
    } catch (e) {
      throw NetworkException('获取 Jellyfin 媒体库失败', e.toString());
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<JellyfinSource>> getJellyfinSources() async {
    await _configStore.init();
    final raw = _configStore.getValue<dynamic>(StorageKeys.jellyfinSources);
    if (raw is List) {
      final sources = raw
          .whereType<Map>()
          .map(
            (map) =>
                JellyfinSourceModel.fromMap(map.cast<String, dynamic>())
                    .toEntity(),
          )
          .toList();
      await _cleanupOrphanJellyfinTracks(sources);
      return sources;
    }
    await _cleanupOrphanJellyfinTracks(const []);
    return const [];
  }

  @override
  Future<JellyfinSource?> getJellyfinSourceById(String id) async {
    final sources = await getJellyfinSources();
    try {
      return sources.firstWhere((source) => source.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteJellyfinSource(String id) async {
    await _configStore.init();
    final existing = await getJellyfinSources();
    final filtered = existing.where((source) => source.id != id).toList();
    final serialized = filtered
        .map((source) => JellyfinSourceModel.fromEntity(source).toMap())
        .toList();
    await _configStore.setValue(StorageKeys.jellyfinSources, serialized);
    await _removeJellyfinToken(id);

    final tracks = await _localDataSource.getTracksBySource(
      TrackSourceType.jellyfin,
      id,
    );
    if (tracks.isNotEmpty) {
      await _localDataSource.deleteTracksByIds(
        tracks.map((track) => track.id).toList(),
      );
    }
  }

  @override
  Future<String?> getJellyfinAccessToken(String id) async {
    final tokens = await _loadJellyfinTokens();
    return tokens[id];
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
        if (kSupportedAudioFileExtensions.contains(extension)) {
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

      final fileName = path.basenameWithoutExtension(file.path);
      final rawTitle = metadata?.title ?? fileName;
      final rawArtist = metadata?.artist ?? 'Unknown Artist';
      final rawAlbum = metadata?.album ?? 'Unknown Album';
      final duration = metadata?.duration ?? Duration.zero;
      final year = metadata?.year?.year;
      final trackNumber = metadata?.trackNumber;
      final genre = metadata?.genres?.isNotEmpty == true
          ? metadata!.genres!.first
          : null;

      final normalized = normalizeTrackFields(
        title: rawTitle,
        artist: rawArtist,
        album: rawAlbum,
        fallbackFileName: fileName,
      );
      final title = normalized.title;
      final artist = normalized.artist;
      final album = normalized.album;

      String? artworkPath = await _saveArtwork(
        metadata,
        previousArtworkPath: existingTrack?.artworkPath,
      );

      final resolvedBitrate = await _resolveBitrate(
        metadata: metadata,
        file: file,
        duration: duration,
      );
      final sampleRate = metadata?.sampleRate;

      if (artworkPath == null || artworkPath.isEmpty) {
        artworkPath = await _fetchArtworkFromNetease(
          title: title,
          artist: artist,
          album: album,
          previousArtworkPath: existingTrack?.artworkPath,
          track: existingTrack?.toEntity(),
        );
      }

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
        bitrate: resolvedBitrate ?? existingTrack?.bitrate,
        sampleRate: sampleRate ?? existingTrack?.sampleRate,
      );
    } catch (e) {
      print('Error reading metadata for ${file.path}: $e');

      // Fallback: create track with filename only
      final fileName = path.basenameWithoutExtension(file.path);
      final normalized = normalizeTrackFields(
        title: fileName,
        artist: existingTrack?.artist ?? 'Unknown Artist',
        album: existingTrack?.album ?? 'Unknown Album',
        fallbackFileName: fileName,
      );

      return TrackModel(
        id: existingTrack?.id ?? _uuid.v4(),
        title: normalized.title,
        artist: normalized.artist,
        album: normalized.album,
        filePath: file.path,
        duration: existingTrack?.duration ?? Duration.zero,
        dateAdded: existingTrack?.dateAdded ?? DateTime.now(),
        artworkPath: existingTrack?.artworkPath,
        trackNumber: existingTrack?.trackNumber,
        year: existingTrack?.year,
        genre: existingTrack?.genre,
        sourceType: existingTrack?.sourceType ?? TrackSourceType.local,
        bitrate: existingTrack?.bitrate,
        sampleRate: existingTrack?.sampleRate,
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

  Future<String?> _saveArtworkBytes(
    Uint8List bytes, {
    String? previousArtworkPath,
    String fileExtension = '.jpg',
  }) async {
    if (bytes.isEmpty) {
      return previousArtworkPath;
    }

    final cacheDir = await _artworkCacheDirectory();
    final filePath = path.join(cacheDir.path, '${_uuid.v4()}$fileExtension');
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (previousArtworkPath != null && previousArtworkPath != filePath) {
      final previousFile = File(previousArtworkPath);
      if (await previousFile.exists()) {
        await previousFile.delete();
      }
    }

    return filePath;
  }

  Future<int?> _resolveBitrate({
    required AudioMetadata? metadata,
    required File file,
    required Duration duration,
  }) async {
    int? rawBitrate = metadata?.bitrate;
    final int? calculated = await _calculateBitrateFromFile(file, duration);

    if (rawBitrate != null && rawBitrate > 0) {
      if (calculated != null) {
        final ratio = calculated / rawBitrate;
        if (ratio > 1.5 && ratio < 9.5) {
          return calculated;
        }
      }
      return rawBitrate;
    }

    return calculated;
  }

  Future<int?> _calculateBitrateFromFile(File file, Duration duration) async {
    if (duration <= Duration.zero) {
      return null;
    }
    try {
      final length = await file.length();
      if (length <= 0) {
        return null;
      }
      final seconds = duration.inMilliseconds / 1000;
      if (seconds <= 0) {
        return null;
      }
      return (length * 8 / seconds).round();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchArtworkFromNetease({
    required String title,
    required String artist,
    required String album,
    String? previousArtworkPath,
    Track? track,
  }) async {
    final normalizedTitle = title.trim().toLowerCase();
    if (normalizedTitle.isEmpty) {
      return null;
    }

    final normalizedArtist = artist.trim().toLowerCase();
    final cacheKey =
        track?.contentHash ?? '$normalizedTitle::$normalizedArtist';
    if (_neteaseArtworkCache.containsKey(cacheKey)) {
      return _neteaseArtworkCache[cacheKey];
    }
    if (!await _isAutoFetchArtworkEnabled()) {
      return null;
    }

    try {
      int? songId;
      if (track != null) {
        final resolution = await _neteaseIdResolver.resolve(track: track);
        songId = resolution?.id;
      }

      if (songId == null) {
        String? artistQuery = artist.trim();
        if (artistQuery.isEmpty ||
            artistQuery.toLowerCase() == 'unknown artist') {
          artistQuery = null;
        }

        songId = await _neteaseApiClient.searchSongId(
          title: title,
          artist: artistQuery,
        );

        if (songId == null) {
          songId = await _neteaseApiClient.searchSongId(
            title: title,
            artist: null,
          );
        }

        if (songId == null) {
          final trimmedAlbum = album.trim();
          if (trimmedAlbum.isNotEmpty &&
              trimmedAlbum.toLowerCase() != 'unknown album') {
            songId = await _neteaseApiClient.searchSongId(
              title: trimmedAlbum,
              artist: artistQuery,
            );
          }
        }
      }

      if (songId == null) {
        _neteaseArtworkCache[cacheKey] = null;
        return null;
      }

      final coverUrl = await _neteaseApiClient.fetchSongCoverUrl(songId);
      if (coverUrl == null || coverUrl.isEmpty) {
        _neteaseArtworkCache[cacheKey] = null;
        return null;
      }

      final optimizedUrl = coverUrl.contains('?')
          ? '$coverUrl&param=512y512'
          : '$coverUrl?param=512y512';

      final imageBytes = await _neteaseApiClient.downloadImage(optimizedUrl);
      if (imageBytes == null || imageBytes.isEmpty) {
        _neteaseArtworkCache[cacheKey] = null;
        return null;
      }

      final savedPath = await _saveArtworkBytes(
        imageBytes,
        previousArtworkPath: previousArtworkPath,
        fileExtension: '.jpg',
      );

      _neteaseArtworkCache[cacheKey] = savedPath;
      return savedPath;
    } catch (e) {
      print('⚠️ MusicLibraryRepository: 网络歌曲封面获取失败 -> $e');
      _neteaseArtworkCache[cacheKey] = null;
      return null;
    }
  }

  Future<bool> _isAutoFetchArtworkEnabled() async {
    await _configStore.init();
    final stored = _configStore.getValue<bool>(StorageKeys.autoFetchArtwork);
    return stored ?? true;
  }

  Future<String?> _cacheWebDavArtwork(
    String sourceId,
    String trackId,
    Uint8List? bytes, {
    String? previousArtworkPath,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      return previousArtworkPath;
    }

    final cacheDir = await _artworkCacheDirectory();
    final digest = sha1.convert(bytes).toString();
    final fileName = 'webdav_${sourceId}_$digest.png';
    final filePath = path.join(cacheDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

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

  Future<Map<String, dynamic>> _fetchMysteryJson(
    HttpClient client,
    Uri uri,
  ) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'MisuzuMusic/1.0');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final rawPreview = body.length > 360
        ? '${body.substring(0, 360)}...'
        : body;
    print('🕵️ Mystery: 响应预览 -> $rawPreview');
    if (response.statusCode != HttpStatus.ok) {
      throw NetworkException('神秘代码请求失败', 'HTTP ${response.statusCode}');
    }
    final cleaned = _sanitizeMysteryResponseBody(body);
    final cleanedPreview = cleaned.length > 360
        ? '${cleaned.substring(0, 360)}...'
        : cleaned;
    print('🕵️ Mystery: 清理后响应预览 -> $cleanedPreview');
    try {
      final decoded = json.decode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      final preview = cleaned.length > 180
          ? '${cleaned.substring(0, 177)}...'
          : cleaned;
      throw NetworkException('神秘代码请求失败', '无法解析响应: $preview');
    }
    throw const NetworkException('神秘代码请求失败', '响应格式错误');
  }

  Future<String?> _downloadMysteryArtwork({
    required HttpClient client,
    required Uri baseUri,
    required String code,
    required String? remotePath,
    required String sourceId,
    required bool isThumbnail,
    String? previousPath,
  }) async {
    if (remotePath == null || remotePath.trim().isEmpty) {
      return previousPath;
    }

    final normalizedRemote = _normalizeMysteryRelativePath(remotePath);
    final uri = baseUri.replace(
      queryParameters: {
        'action': isThumbnail ? 'thumbnail' : 'cover',
        'code': code,
        'path': normalizedRemote,
      },
    );

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'MisuzuMusic/1.0');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return previousPath;
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        return previousPath;
      }

      final cacheDir = await _artworkCacheDirectory();
      final digest = sha1.convert(
        utf8.encode(
          '$sourceId|$normalizedRemote|${isThumbnail ? 'thumb' : 'cover'}',
        ),
      );
      final fileName =
          'mystery_${digest.toString()}${isThumbnail ? '_thumb' : '_cover'}.webp';
      final filePath = path.join(cacheDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (previousPath != null && previousPath != filePath) {
        final previousFile = File(previousPath);
        if (await previousFile.exists()) {
          await previousFile.delete();
        }
      }

      return filePath;
    } catch (e) {
      print('⚠️ Mystery: 下载封面失败 [$remotePath] -> $e');
      return previousPath;
    }
  }

  String _buildMysterySourceId(String code) {
    return '${MysteryLibraryConstants.idPrefix}_$code';
  }

  String _normalizeMysteryRelativePath(String rawPath) {
    var normalized = rawPath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '/';
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    normalized = posix.normalize(normalized);
    if (normalized.isEmpty) {
      return '/';
    }
    return normalized.startsWith('/') ? normalized : '/$normalized';
  }

  String _buildMysteryFilePath(String sourceId, String relativePath) {
    final normalized = _normalizeMysteryRelativePath(relativePath);
    return 'mystery://$sourceId$normalized';
  }

  Duration _parseMysteryDuration(
    Map<String, dynamic> metadata,
    Duration? fallback,
  ) {
    final tags = (metadata['tags'] as Map<String, dynamic>?) ?? const {};
    final durationMsValue = metadata['duration_ms'] ?? tags['duration_ms'];
    int? durationMs;
    if (durationMsValue is num) {
      durationMs = durationMsValue.toInt();
    } else if (durationMsValue is String) {
      durationMs = int.tryParse(durationMsValue.trim());
    }

    if (durationMs == null) {
      final seconds =
          _parseNullableDouble(metadata['duration']) ??
          _parseNullableDouble(tags['duration']);
      if (seconds != null) {
        durationMs = (seconds * 1000).round();
      }
    }

    if (durationMs == null || durationMs <= 0) {
      return fallback ?? Duration.zero;
    }
    return Duration(milliseconds: durationMs);
  }

  String? _readNonEmptyString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return trimmed;
    }
    return null;
  }

  double? _parseNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return double.tryParse(trimmed);
    }
    return null;
  }

  String _sanitizeMysteryResponseBody(String body) {
    var sanitized = body.trimLeft();
    sanitized = sanitized.replaceAll(String.fromCharCode(0), '');

    if (sanitized.isEmpty) {
      return sanitized;
    }

    final match = RegExp(r'[\{\[]').firstMatch(sanitized);
    if (match != null && match.start > 0) {
      sanitized = sanitized.substring(match.start).trimLeft();
    }

    sanitized = sanitized.replaceAll(String.fromCharCode(0), '');
    return sanitized;
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

  bool _isTrackWithinDirectory(String filePath, String directoryPath) {
    final normalizedTrack = path.normalize(filePath);
    final normalizedDirectory = path.normalize(directoryPath);
    if (normalizedTrack == normalizedDirectory) {
      return true;
    }
    return path.isWithin(normalizedDirectory, normalizedTrack);
  }

  Future<void> _cleanupOrphanWebDavTracks(List<WebDavSource> sources) async {
    try {
      final validIds = sources.map((source) => source.id).toSet();
      final allTracks = await _localDataSource.getAllTracks();
      final orphanIds = allTracks
          .where(
            (track) =>
                track.sourceType == TrackSourceType.webdav &&
                (track.sourceId == null || !validIds.contains(track.sourceId!)),
          )
          .map((track) => track.id)
          .toList();
      if (orphanIds.isNotEmpty) {
        await _localDataSource.deleteTracksByIds(orphanIds);
      }
    } catch (e) {
      print('⚠️ WebDAV: 清理孤立音轨失败 -> $e');
    }
  }

  Future<void> _cleanupOrphanJellyfinTracks(
    List<JellyfinSource> sources,
  ) async {
    try {
      final validIds = sources.map((source) => source.id).toSet();
      final allTracks = await _localDataSource.getAllTracks();
      final orphanIds = allTracks
          .where(
            (track) =>
                track.sourceType == TrackSourceType.jellyfin &&
                (track.sourceId == null || !validIds.contains(track.sourceId!)),
          )
          .map((track) => track.id)
          .toList();
      if (orphanIds.isNotEmpty) {
        await _localDataSource.deleteTracksByIds(orphanIds);
      }
    } catch (e) {
      print('⚠️ Jellyfin: 清理孤立音轨失败 -> $e');
    }
  }

  Future<void> _cleanupMissingLocalTracks({
    required String normalizedDirectory,
    required Set<String> discoveredPaths,
  }) async {
    try {
      final allTracks = await _localDataSource.getAllTracks();
      final missingIds = <String>[];

      for (final track in allTracks) {
        if (track.sourceType != TrackSourceType.local) {
          continue;
        }

        final normalizedTrackPath = path.normalize(track.filePath);
        if (!_isTrackWithinDirectory(
          normalizedTrackPath,
          normalizedDirectory,
        )) {
          continue;
        }

        final existsInScan = discoveredPaths.contains(normalizedTrackPath);
        final existsOnDisk =
            existsInScan || File(normalizedTrackPath).existsSync();
        if (!existsOnDisk) {
          missingIds.add(track.id);
        }
      }

      if (missingIds.isNotEmpty) {
        await _localDataSource.deleteTracksByIds(missingIds);
        print('📁 Local scan: 已移除 ${missingIds.length} 首缺失的本地歌曲');
      }
    } catch (e) {
      print('⚠️ Local scan: 清理缺失歌曲失败 -> $e');
    }
  }

  Uint8List _buildPlayLogPayload(int timestampMs, String trackId) {
    final trackIdBytes = utf8.encode(trackId);
    final builder = BytesBuilder();
    builder.add(utf8.encode('MMLG'));
    builder.add(_encodeUint16(_playLogVersion));
    builder.add(_encodeUint32(1));
    builder.add(_encodeUint64(timestampMs));
    builder.add(_encodeUint8(trackIdBytes.length));
    builder.add(trackIdBytes);
    return builder.toBytes();
  }

  Uint8List _encodeUint8(int value) => Uint8List.fromList([value & 0xFF]);

  Uint8List _encodeUint16(int value) {
    final bytes = Uint8List(2);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, value, Endian.little);
    return bytes;
  }

  Uint8List _encodeUint32(int value) {
    final bytes = Uint8List(4);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, value, Endian.little);
    return bytes;
  }

  Uint8List _encodeUint64(int value) {
    final bytes = Uint8List(8);
    final data = ByteData.sublistView(bytes);
    data.setUint64(0, value, Endian.little);
    return bytes;
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
      final normalizedExtension = extension.isNotEmpty
          ? extension.toLowerCase()
          : '.png';
      final digest = sha1.convert(utf8.encode('$sourceId|$remoteArtworkPath'));
      final cacheDir = await _artworkCacheDirectory();
      final filePath = path.join(
        cacheDir.path,
        '${digest.toString()}$normalizedExtension',
      );

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      // print('🌐 WebDAV: 封面已缓存 -> $filePath');

      if (previousArtworkPath != null && previousArtworkPath != filePath) {
        final previous = File(previousArtworkPath);
        if (await previous.exists()) {
          print('🌐 WebDAV: 清理旧封面 -> $previousArtworkPath');
          await previous.delete();
        }
      }

      return filePath;
    } catch (e) {
      // Optional artwork file, suppress error
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

  String _buildJellyfinFilePath(String sourceId, String itemId) {
    final normalized = itemId.trim();
    return 'jellyfin://$sourceId/$normalized';
  }

  String? _extractJellyfinSourceId(String filePath) {
    const prefix = 'jellyfin://';
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

  String? _extractJellyfinItemId(String filePath) {
    const prefix = 'jellyfin://';
    if (!filePath.startsWith(prefix)) {
      return null;
    }
    final remainder = filePath.substring(prefix.length);
    final slashIndex = remainder.indexOf('/');
    if (slashIndex == -1) {
      return remainder.isEmpty ? null : remainder;
    }
    final itemId = remainder.substring(slashIndex + 1);
    return itemId.isEmpty ? null : itemId;
  }

  String _buildJellyfinTrackId(String sourceId, String itemId) {
    final digest = sha1.convert(utf8.encode('$sourceId|$itemId'));
    return digest.toString();
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

  Future<Map<String, String>> _loadJellyfinTokens() async {
    await _configStore.init();
    final raw = _configStore.getValue<dynamic>(StorageKeys.jellyfinTokens);
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

  Future<void> _setJellyfinToken(String sourceId, String token) async {
    final map = await _loadJellyfinTokens();
    map[sourceId] = token;
    await _configStore.setValue(StorageKeys.jellyfinTokens, map);
  }

  Future<void> _removeJellyfinToken(String sourceId) async {
    final map = await _loadJellyfinTokens();
    if (map.remove(sourceId) != null) {
      await _configStore.setValue(StorageKeys.jellyfinTokens, map);
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

  HttpClient _createJellyfinHttpClient(bool ignoreTls) {
    final client = HttpClient();
    if (ignoreTls) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    return client;
  }

  String _buildJellyfinClientInfo(String deviceId) {
    return 'MediaBrowser Client="${AppConstants.appName}", '
        'Device="${AppConstants.appName}", '
        'DeviceId="$deviceId", '
        'Version="${AppConstants.version}"';
  }

  Future<String> _getOrCreateJellyfinDeviceId() async {
    await _configStore.init();
    final existing = _configStore.getValue<String>(
      StorageKeys.jellyfinDeviceId,
    );
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _uuid.v4();
    await _configStore.setValue(StorageKeys.jellyfinDeviceId, created);
    return created;
  }

  Future<Map<String, dynamic>> _fetchJellyfinJson(
    HttpClient client,
    Uri uri, {
    String? accessToken,
    String? deviceId,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final request = await client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'MisuzuMusic/1.0');
    if (deviceId != null && deviceId.isNotEmpty) {
      request.headers.set(
        'X-Emby-Authorization',
        _buildJellyfinClientInfo(deviceId),
      );
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers.set('X-Emby-Token', accessToken);
    }
    if (body != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(json.encode(body)));
    }

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NetworkException(
        'Jellyfin 请求失败',
        'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}\n$text',
      );
    }
    if (text.isEmpty) {
      return const {};
    }
    final decoded = json.decode(text);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return const {};
  }

  Future<String?> _fetchJellyfinServerName(
    HttpClient client,
    String baseUrl, {
    required String deviceId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/System/Info/Public');
      final data = await _fetchJellyfinJson(
        client,
        uri,
        deviceId: deviceId,
      );
      return _readNonEmptyString(data['ServerName']);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchJellyfinAudioItems({
    required JellyfinSource source,
    required String accessToken,
  }) async {
    final client = _createJellyfinHttpClient(source.ignoreTls);
    final deviceId = await _getOrCreateJellyfinDeviceId();
    final items = <Map<String, dynamic>>[];
    const limit = 500;
    var startIndex = 0;

    try {
      while (true) {
        final uri = Uri.parse(
          '${source.baseUrl}/Users/${source.userId}/Items',
        ).replace(
          queryParameters: {
            'ParentId': source.libraryId,
            'Recursive': 'true',
            'IncludeItemTypes': 'Audio',
            'Fields':
                'Album,Artists,AlbumArtists,AlbumArtist,Genres,RunTimeTicks,ProductionYear,IndexNumber,DateCreated,ImageTags,MediaSources',
            'StartIndex': startIndex.toString(),
            'Limit': limit.toString(),
            'SortBy': 'SortName',
            'SortOrder': 'Ascending',
          },
        );

        final data = await _fetchJellyfinJson(
          client,
          uri,
          accessToken: accessToken,
          deviceId: deviceId,
        );

        final batch = data['Items'];
        if (batch is! List || batch.isEmpty) {
          break;
        }

        for (final raw in batch) {
          if (raw is Map<String, dynamic>) {
            items.add(raw);
          } else if (raw is Map) {
            items.add(raw.cast<String, dynamic>());
          }
        }

        final total =
            (data['TotalRecordCount'] as num?)?.toInt() ?? items.length;
        startIndex += batch.length;
        if (items.length >= total) {
          break;
        }
      }
    } finally {
      client.close(force: true);
    }

    return items;
  }

  String? _readPrimaryImageTag(Map<String, dynamic> item) {
    final tags = item['ImageTags'];
    if (tags is Map) {
      return _readNonEmptyString(tags['Primary']);
    }
    return null;
  }

  String? _buildJellyfinImageUrl({
    required String baseUrl,
    required String itemId,
    required String accessToken,
    String? tag,
  }) {
    final params = <String, String>{
      'api_key': accessToken,
      'quality': '90',
      'width': '400',
    };
    if (tag != null && tag.isNotEmpty) {
      params['tag'] = tag;
    }
    final uri = Uri.parse('$baseUrl/Items/$itemId/Images/Primary');
    return uri.replace(queryParameters: params).toString();
  }

  Duration? _parseJellyfinDuration(dynamic ticksValue) {
    if (ticksValue == null) {
      return null;
    }
    double? ticks;
    if (ticksValue is num) {
      ticks = ticksValue.toDouble();
    } else if (ticksValue is String) {
      ticks = double.tryParse(ticksValue.trim());
    }
    if (ticks == null || ticks <= 0) {
      return null;
    }
    final millis = (ticks / 10000).round();
    if (millis <= 0) {
      return null;
    }
    return Duration(milliseconds: millis);
  }

  DateTime? _parseJellyfinDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  String? _joinJellyfinNames(dynamic value) {
    if (value is! List) {
      return null;
    }
    final names = <String>[];
    for (final item in value) {
      if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          names.add(trimmed);
        }
      } else if (item is Map) {
        final name = _readNonEmptyString(item['Name']);
        if (name != null) {
          names.add(name);
        }
      }
    }
    if (names.isEmpty) {
      return null;
    }
    return names.join(' / ');
  }

  int? _parseJellyfinBitrate(Map<String, dynamic> item) {
    final sources = item['MediaSources'];
    if (sources is List && sources.isNotEmpty) {
      final first = sources.first;
      if (first is Map) {
        final bitrate = first['Bitrate'] ?? first['AudioBitrate'];
        return _parseNullableInt(bitrate);
      }
    }
    return null;
  }

  int? _parseJellyfinSampleRate(Map<String, dynamic> item) {
    final sources = item['MediaSources'];
    if (sources is List && sources.isNotEmpty) {
      final first = sources.first;
      if (first is Map) {
        final streams = first['MediaStreams'];
        if (streams is List) {
          for (final stream in streams) {
            if (stream is Map && stream['Type'] == 'Audio') {
              return _parseNullableInt(stream['SampleRate']);
            }
          }
        }
      }
    }
    return null;
  }

  Future<Uint8List?> _downloadWebDavBundle(
    webdav.Client client,
    String rootPath,
  ) async {
    final remotePath = _combineRootAndRelative(rootPath, _bundleRelativePath);
    try {
      final bytes = await client.read(remotePath);
      if (bytes.isEmpty) {
        return null;
      }
      return Uint8List.fromList(bytes);
    } catch (e) {
      // Optional file, suppress error
      return null;
    }
  }

  Future<void> _importWebDavBundle(
    Uint8List bundleBytes,
    WebDavSource source,
  ) async {
    final parser = WebDavBundleParser();
    final entries = parser.parse(bundleBytes);
    final now = DateTime.now();

    final existingTracks = await _localDataSource.getTracksByWebDavSource(
      source.id,
    );
    final existingById = {for (final track in existingTracks) track.id: track};
    final seenIds = <String>{};

    for (final entry in entries) {
      final metadata = entry.metadata;
      final title = (metadata['title'] as String?)?.trim();
      final artist = (metadata['artist'] as String?)?.trim();
      final album = (metadata['album'] as String?)?.trim();
      final durationMs = (metadata['duration_ms'] as num?)?.toInt() ?? 0;
      final trackNumber = (metadata['track_number'] as num?)?.toInt();
      final year = (metadata['year'] as num?)?.toInt();
      final genre = metadata['genre'] as String?;
      final bitrate = (metadata['bitrate'] as num?)?.toInt();
      final sampleRate = (metadata['sample_rate'] as num?)?.toInt();

      final existing = existingById[entry.trackId];
      final artworkPath = await _cacheWebDavArtwork(
        source.id,
        entry.trackId,
        entry.artwork,
        previousArtworkPath: existing?.artworkPath,
      );

      final headers = <String, String>{
        if (existing?.httpHeaders != null) ...existing!.httpHeaders!,
        if (metadata['cover_file'] is String)
          _coverHeaderKey: metadata['cover_file'] as String,
        if (metadata['thumbnail_file'] is String)
          _thumbnailHeaderKey: metadata['thumbnail_file'] as String,
      };

      final trackModel = TrackModel(
        id: entry.trackId,
        title: title?.isNotEmpty == true
            ? title!
            : path.basenameWithoutExtension(entry.relativePath),
        artist: artist?.isNotEmpty == true ? artist! : 'Unknown Artist',
        album: album?.isNotEmpty == true ? album! : 'Unknown Album',
        filePath: _buildWebDavFilePath(source.id, entry.relativePath),
        duration: Duration(milliseconds: durationMs),
        dateAdded: existing?.dateAdded ?? now,
        artworkPath: artworkPath,
        trackNumber: trackNumber,
        year: year,
        genre: genre,
        sourceType: TrackSourceType.webdav,
        sourceId: source.id,
        remotePath: entry.relativePath,
        httpHeaders: headers.isEmpty ? existing?.httpHeaders : headers,
        contentHash:
            metadata?['hash_sha1_first_10kb'] as String? ?? entry.trackId,
        bitrate: bitrate ?? existing?.bitrate,
        sampleRate: sampleRate ?? existing?.sampleRate,
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
      print('🌐 WebDAV: 已移除 ${removedIds.length} 首已删除的曲目');
    }

    print('🌐 WebDAV: 从元数据包导入 ${entries.length} 首歌曲');
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

        if (kSupportedAudioFileExtensions.contains(extension)) {
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

  void _emitTrackUpdate(Track track) {
    try {
      _trackUpdateController.add(track);
    } catch (_) {
      // ignore
    }
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
