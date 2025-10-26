import '../../core/error/exceptions.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/entities/netease_entities.dart';
import '../../domain/repositories/netease_repository.dart';
import '../datasources/remote/netease_api_client.dart';
import '../models/netease_models.dart';
import '../storage/netease_session_store.dart';

class NeteaseRepositoryImpl implements NeteaseRepository {
  NeteaseRepositoryImpl({
    required NeteaseApiClient apiClient,
    required NeteaseSessionStore sessionStore,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore;

  final NeteaseApiClient _apiClient;
  final NeteaseSessionStore _sessionStore;

  NeteaseCachePayload _cache = NeteaseCachePayload.empty();

  NeteaseSession? get _session => _cache.session == null
      ? null
      : NeteaseSession(
          cookie: _cache.session!.cookie,
          account: NeteaseAccount(
            userId: _cache.session!.account.userId,
            nickname: _cache.session!.account.nickname,
            avatarUrl: _cache.session!.account.avatarUrl,
          ),
          updatedAt: _cache.session!.updatedAt,
        );

  Future<void> _ensureLoaded() async {
    if (_cache.session != null || _cache.playlists.isNotEmpty) {
      return;
    }
    _cache = await _sessionStore.loadCache();
  }

  Future<void> _persist() async {
    await _sessionStore.saveCache(_cache);
  }

  @override
  Future<NeteaseSession?> loadSession() async {
    await _ensureLoaded();
    return _session;
  }

  @override
  Future<NeteaseSession> loginWithCookie(String cookie) async {
    final profile = await _apiClient.fetchAccountProfile(cookie);
    if (profile == null) {
      throw const AuthenticationException('网络歌曲 Cookie 无效或已过期');
    }
    final sessionModel = NeteaseSessionModel(
      cookie: cookie,
      account: profile,
      updatedAt: DateTime.now(),
    );
    _cache = NeteaseCachePayload(
      session: sessionModel,
      playlists: const [],
      playlistTracks: const {},
    );
    await _persist();
    return NeteaseSession(
      cookie: cookie,
      account: NeteaseAccount(
        userId: profile.userId,
        nickname: profile.nickname,
        avatarUrl: profile.avatarUrl,
      ),
      updatedAt: sessionModel.updatedAt,
    );
  }

  @override
  Future<void> logout() async {
    _cache = NeteaseCachePayload.empty();
    await _sessionStore.clear();
  }

  @override
  Future<NeteaseSession?> refreshSession() async {
    await _ensureLoaded();
    final cached = _cache.session;
    if (cached == null) {
      return null;
    }
    final profile = await _apiClient.fetchAccountProfile(cached.cookie);
    if (profile == null) {
      await logout();
      return null;
    }
    final sessionModel = NeteaseSessionModel(
      cookie: cached.cookie,
      account: profile,
      updatedAt: DateTime.now(),
    );
    _cache = _cache.copyWith(session: sessionModel);
    await _persist();
    return NeteaseSession(
      cookie: sessionModel.cookie,
      account: NeteaseAccount(
        userId: sessionModel.account.userId,
        nickname: sessionModel.account.nickname,
        avatarUrl: sessionModel.account.avatarUrl,
      ),
      updatedAt: sessionModel.updatedAt,
    );
  }

  @override
  Future<List<NeteasePlaylist>> fetchUserPlaylists() async {
    await _ensureLoaded();
    final session = _cache.session;
    if (session == null) {
      throw const AuthenticationException('网络歌曲账号未登录');
    }
    final playlists = await _apiClient.fetchUserPlaylists(
      cookie: session.cookie,
      userId: session.account.userId,
    );
    _cache = _cache.copyWith(playlists: playlists);
    await _persist();
    return playlists
        .map(
          (playlist) => NeteasePlaylist(
            id: playlist.id,
            name: playlist.name,
            trackCount: playlist.trackCount,
            playCount: playlist.playCount,
            creatorName: playlist.creatorName,
            coverUrl: playlist.coverUrl,
            description: playlist.description,
            updatedAt: playlist.updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<List<Track>> fetchPlaylistTracks(int playlistId) async {
    await _ensureLoaded();
    final session = _cache.session;
    if (session == null) {
      throw const AuthenticationException('网络歌曲账号未登录');
    }

    final cachedTracks = _cache.playlistTracks[playlistId];

    final tracks = await _apiClient.fetchPlaylistTracks(
      cookie: session.cookie,
      playlistId: playlistId,
    );

    if (tracks == null) {
      if (cachedTracks == null) {
        return const [];
      }
      return cachedTracks
          .map((track) => track.toPlayerTrack(cookie: session.cookie))
          .toList();
    }

    final updatedTracks = Map<int, List<NeteaseTrackModel>>.from(
      _cache.playlistTracks,
    )..[playlistId] = tracks;
    _cache = _cache.copyWith(playlistTracks: updatedTracks);
    await _persist();

    return tracks
        .map((track) => track.toPlayerTrack(cookie: session.cookie))
        .toList();
  }

  @override
  Future<Track?> ensureTrackStream(Track track) async {
    await _ensureLoaded();
    final session = _cache.session;
    if (session == null) {
      throw const AuthenticationException('网络歌曲账号未登录');
    }
    final id = int.tryParse(
      track.sourceId ?? track.id.replaceFirst('netease_', ''),
    );
    if (id == null) {
      return null;
    }
    final streamInfo = await _apiClient.fetchTrackStream(
      cookie: session.cookie,
      trackId: id,
    );
    if (streamInfo == null) {
      return null;
    }
    return track.copyWith(
      filePath: streamInfo.url,
      remotePath: streamInfo.url,
      httpHeaders: {
        ...(track.httpHeaders ?? {}),
        'Cookie': streamInfo.cookie,
        'Referer': 'https://music.163.com',
      },
    );
  }

  @override
  List<NeteasePlaylist> getCachedPlaylists() {
    return _cache.playlists
        .map(
          (playlist) => NeteasePlaylist(
            id: playlist.id,
            name: playlist.name,
            trackCount: playlist.trackCount,
            playCount: playlist.playCount,
            creatorName: playlist.creatorName,
            coverUrl: playlist.coverUrl,
            description: playlist.description,
            updatedAt: playlist.updatedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Map<int, List<Track>> getCachedPlaylistTracks() {
    final session = _cache.session;
    if (session == null) {
      return const {};
    }
    final Map<int, List<Track>> result = {};
    _cache.playlistTracks.forEach((key, value) {
      result[key] = value
          .map((track) => track.toPlayerTrack(cookie: session.cookie))
          .toList(growable: false);
    });
    return result;
  }

  @override
  Future<String?> addTrackToPlaylist(int playlistId, Track track) async {
    await _ensureLoaded();
    final session = _cache.session;
    if (session == null) {
      return '网络歌曲账号未登录';
    }
    final trackId = int.tryParse(
      track.sourceId ?? track.id.replaceFirst('netease_', ''),
    );
    if (trackId == null) {
      return '无法识别歌曲 ID';
    }
    final success = await _apiClient.addTrackToPlaylist(
      cookie: session.cookie,
      playlistId: playlistId,
      trackId: trackId,
    );
    if (!success) {
      return '添加到网络歌曲歌单失败';
    }

    final cachedTracks = _cache.playlistTracks[playlistId];
    final exists =
        cachedTracks?.any((element) => element.id == trackId) ?? false;

    final updatedTracks = Map<int, List<NeteaseTrackModel>>.from(
      _cache.playlistTracks,
    )
      ..remove(playlistId);

    final updatedPlaylists = _cache.playlists
        .map(
          (playlist) => playlist.id == playlistId && !exists
              ? playlist.copyWith(trackCount: playlist.trackCount + 1)
              : playlist,
        )
        .toList();

    _cache = _cache.copyWith(
      playlistTracks: updatedTracks,
      playlists: updatedPlaylists,
    );
    await _persist();
    return null;
  }
}
