import '../../domain/entities/music_entities.dart';
import '../datasources/remote/netease_api_client.dart';
import '../models/netease_models.dart';

import 'song_id_mapping_service.dart';

class NeteaseIdResolver {
  NeteaseIdResolver({
    required SongIdMappingService mappingService,
    required NeteaseApiClient neteaseApiClient,
  }) : _mappingService = mappingService,
       _neteaseApiClient = neteaseApiClient;

  final SongIdMappingService _mappingService;
  final NeteaseApiClient _neteaseApiClient;

  final Map<String, Future<NeteaseIdResolution?>> _pending = {};
  final Map<String, NeteaseIdResolution?> _cache = {};

  Future<NeteaseIdResolution?> resolve({
    required Track track,
    bool allowSearch = true,
    bool refreshCache = false,
    bool saveToServerOnSuccess = true,
  }) {
    final key = _cacheKey(track);
    if (!refreshCache) {
      if (_cache.containsKey(key)) {
        return Future.value(_cache[key]);
      }
      final inflight = _pending[key];
      if (inflight != null) {
        return inflight;
      }
    }

    final future = _resolveInternal(
      track: track,
      allowSearch: allowSearch,
      saveToServerOnSuccess: saveToServerOnSuccess,
    );

    _pending[key] = future;
    return future
        .whenComplete(() {
          _pending.remove(key);
        })
        .then((value) {
          _cache[key] = value;
          return value;
        });
  }

  Future<NeteaseIdResolution?> _resolveInternal({
    required Track track,
    required bool allowSearch,
    required bool saveToServerOnSuccess,
  }) async {
    final hash = _hashForTrack(track);

    if (hash != null) {
      try {
        final remoteId = await _mappingService.fetchNeteaseId(hash);
        if (remoteId != null) {
          return NeteaseIdResolution(
            id: remoteId,
            source: NeteaseIdSource.server,
            hash: hash,
            savedToServer: true,
          );
        }
      } catch (error) {
        // 网络失败不应阻塞后续逻辑
        // ignore: avoid_print
        //print('⚠️ NeteaseIdResolver: remote lookup failed -> $error');
      }
    }

    if (!allowSearch) {
      return null;
    }

    final searchedId = await _searchNeteaseIdForTrack(track);
    if (searchedId == null) {
      return null;
    }

    bool saved = false;
    if (hash != null && saveToServerOnSuccess) {
      try {
        await _mappingService.saveMapping(
          hash: hash,
          neteaseId: searchedId,
          title: track.title,
          artist: track.artist,
          album: track.album,
          source: 'auto',
        );
        saved = true;
      } catch (error) {
        // ignore: avoid_print
        //print('⚠️ NeteaseIdResolver: save mapping failed -> $error');
      }
    }

    return NeteaseIdResolution(
      id: searchedId,
      source: NeteaseIdSource.autoSearch,
      hash: hash,
      savedToServer: saved,
    );
  }

  Future<void> saveMapping({
    required Track track,
    required int neteaseId,
    String source = 'manual',
  }) async {
    final hash = _hashForTrack(track);
    if (hash == null) {
      throw ArgumentError('track ${track.id} 缺少 contentHash，无法提交映射');
    }

    await _mappingService.saveMapping(
      hash: hash,
      neteaseId: neteaseId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      source: source,
    );

    final resolution = NeteaseIdResolution(
      id: neteaseId,
      source: NeteaseIdSource.manual,
      hash: hash,
      savedToServer: true,
    );
    _cache[_cacheKey(track)] = resolution;
  }

  Future<List<NeteaseSongCandidate>> searchCandidates({
    required String keyword,
    String? artist,
    int limit = 10,
  }) async {
    if (keyword.trim().isEmpty) {
      return const [];
    }
    final sanitizedArtist = artist?.trim();
    try {
      return await _neteaseApiClient.searchSongCandidates(
        keyword: keyword.trim(),
        artist: sanitizedArtist?.isEmpty == true ? null : sanitizedArtist,
        limit: limit,
      );
    } catch (error) {
      // ignore: avoid_print
      //print('⚠️ NeteaseIdResolver: search candidates failed -> $error');
      return const [];
    }
  }

  void clearCacheForTrack(Track track) {
    _cache.remove(_cacheKey(track));
  }

  String _cacheKey(Track track) {
    return _hashForTrack(track) ?? 'track:${track.id}';
  }

  String? _hashForTrack(Track track) {
    final hash = track.contentHash?.trim();
    if (hash == null || hash.isEmpty) {
      return null;
    }
    return hash;
  }

  Future<int?> _searchNeteaseIdForTrack(Track track) async {
    String? artist = track.artist.trim();
    if (artist.isEmpty || artist.toLowerCase() == 'unknown artist') {
      artist = null;
    }

    final attempts = <({String title, String? artist})>{
      (title: track.title, artist: artist),
      (title: track.title, artist: null),
    };

    final normalizedAlbum = track.album.trim();
    if (normalizedAlbum.isNotEmpty &&
        normalizedAlbum.toLowerCase() != 'unknown album') {
      attempts.add((title: normalizedAlbum, artist: artist));
    }

    for (final attempt in attempts) {
      final id = await _neteaseApiClient.searchSongId(
        title: attempt.title,
        artist: attempt.artist,
      );
      if (id != null) {
        return id;
      }
    }
    return null;
  }
}

class NeteaseIdResolution {
  const NeteaseIdResolution({
    required this.id,
    required this.source,
    this.hash,
    this.savedToServer = false,
  });

  final int id;
  final NeteaseIdSource source;
  final String? hash;
  final bool savedToServer;
}

enum NeteaseIdSource { server, autoSearch, manual }
