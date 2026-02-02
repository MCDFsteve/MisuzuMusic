import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/music_entities.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../../domain/services/audio_player_service.dart';

class CarPlayService {
  CarPlayService(
    this._musicLibraryRepository,
    this._audioPlayerService, {
    MethodChannel? channel,
  }) : _channel =
           channel ?? const MethodChannel('com.aimessoft.misuzumusic/carplay');

  final MusicLibraryRepository _musicLibraryRepository;
  final AudioPlayerService _audioPlayerService;
  final MethodChannel _channel;

  bool _initialized = false;
  DateTime _lastCacheAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cacheTtl = Duration(minutes: 1);

  List<Track>? _allTracksCache;
  List<Artist>? _allArtistsCache;
  List<Album>? _allAlbumsCache;
  List<Playlist>? _allPlaylistsCache;

  final Map<String, List<Track>> _nodeTracksCache = <String, List<Track>>{};

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!Platform.isIOS) {
      _channel.setMethodCallHandler(null);
      return;
    }

    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      await _channel.invokeMethod<void>('ready');
    } catch (_) {
      // Native side may not be ready yet; it can request data later.
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getChildren':
        final args = call.arguments;
        final nodeId = args is Map
            ? args['nodeId']?.toString()
            : call.arguments?.toString();
        if (nodeId == null || nodeId.isEmpty) {
          return const <Map<String, Object?>>[];
        }
        final items = await _getChildren(nodeId);
        return items;
      case 'playItem':
        final args = call.arguments;
        final id = args is Map
            ? args['id']?.toString()
            : call.arguments?.toString();
        if (id == null || id.isEmpty) {
          return false;
        }
        await _playItem(id);
        return true;
      default:
        return null;
    }
  }

  Future<List<Map<String, Object?>>> _getChildren(String nodeId) async {
    _maybeExpireCaches();

    if (nodeId == 'tracks') {
      final tracks = await _ensureAllTracks();
      return _buildLetterGroups(
        prefix: 'tracks:group:',
        titles: tracks.map((t) => t.title),
        subtitleSuffix: '首歌曲',
      );
    }

    if (nodeId.startsWith('tracks:group:')) {
      final letter = nodeId.substring('tracks:group:'.length);
      final tracks = await _tracksForTracksGroup(letter);
      _nodeTracksCache[nodeId] = tracks;
      return tracks
          .map(
            (track) => _playableItem(
              id: _encodePlayId(nodeId: nodeId, trackId: track.id),
              title: track.title,
              subtitle: track.artist,
            ),
          )
          .toList(growable: false);
    }

    if (nodeId == 'artists') {
      final artists = await _ensureAllArtists();
      return _buildLetterGroups(
        prefix: 'artists:group:',
        titles: artists.map((a) => a.name),
        subtitleSuffix: '位艺术家',
      );
    }

    if (nodeId.startsWith('artists:group:')) {
      final letter = nodeId.substring('artists:group:'.length);
      final artists = await _ensureAllArtists();
      final filtered =
          artists
              .where((artist) => _groupKey(artist.name) == letter)
              .toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));

      return filtered
          .map(
            (artist) => _containerItem(
              id: 'artists:artist:${_b64(artist.name)}',
              title: artist.name,
              subtitle: '${artist.trackCount}首歌曲',
            ),
          )
          .toList(growable: false);
    }

    if (nodeId.startsWith('artists:artist:')) {
      final artistName = _decodeB64(nodeId.substring('artists:artist:'.length));
      if (artistName == null || artistName.isEmpty) {
        return const <Map<String, Object?>>[];
      }
      final tracks = await _musicLibraryRepository.getTracksByArtist(
        artistName,
      );
      tracks.sort(_compareTracksForArtist);
      _nodeTracksCache[nodeId] = tracks;
      return tracks
          .map(
            (track) => _playableItem(
              id: _encodePlayId(nodeId: nodeId, trackId: track.id),
              title: track.title,
              subtitle: track.album.isNotEmpty ? track.album : track.artist,
            ),
          )
          .toList(growable: false);
    }

    if (nodeId == 'albums') {
      final albums = await _ensureAllAlbums();
      return _buildLetterGroups(
        prefix: 'albums:group:',
        titles: albums.map((a) => a.title),
        subtitleSuffix: '张专辑',
      );
    }

    if (nodeId.startsWith('albums:group:')) {
      final letter = nodeId.substring('albums:group:'.length);
      final albums = await _ensureAllAlbums();
      final filtered =
          albums
              .where((album) => _groupKey(album.title) == letter)
              .toList(growable: false)
            ..sort((a, b) {
              final titleCmp = a.title.compareTo(b.title);
              if (titleCmp != 0) return titleCmp;
              return a.artist.compareTo(b.artist);
            });

      return filtered
          .map(
            (album) => _containerItem(
              id: 'albums:album:${_b64(album.artist)}:${_b64(album.title)}',
              title: album.title,
              subtitle: album.artist,
            ),
          )
          .toList(growable: false);
    }

    if (nodeId.startsWith('albums:album:')) {
      final parts = nodeId.substring('albums:album:'.length).split(':');
      if (parts.length < 2) {
        return const <Map<String, Object?>>[];
      }
      final artist = _decodeB64(parts[0]);
      final title = _decodeB64(parts[1]);
      if (artist == null || title == null || title.isEmpty) {
        return const <Map<String, Object?>>[];
      }
      final tracks = await _musicLibraryRepository.getTracksByAlbum(title);
      final filtered =
          tracks
              .where((track) => track.album == title && track.artist == artist)
              .toList(growable: false)
            ..sort(_compareTracksForAlbum);

      _nodeTracksCache[nodeId] = filtered;
      return filtered
          .map(
            (track) => _playableItem(
              id: _encodePlayId(nodeId: nodeId, trackId: track.id),
              title: track.title,
              subtitle: track.artist,
            ),
          )
          .toList(growable: false);
    }

    if (nodeId == 'playlists') {
      final playlists = await _ensureAllPlaylists();
      final sorted = List<Playlist>.from(playlists)
        ..sort((a, b) => a.name.compareTo(b.name));
      return sorted
          .map(
            (playlist) => _containerItem(
              id: 'playlists:playlist:${_b64(playlist.id)}',
              title: playlist.name,
              subtitle: '${playlist.trackIds.length}首歌曲',
            ),
          )
          .toList(growable: false);
    }

    if (nodeId.startsWith('playlists:playlist:')) {
      final playlistId = _decodeB64(
        nodeId.substring('playlists:playlist:'.length),
      );
      if (playlistId == null || playlistId.isEmpty) {
        return const <Map<String, Object?>>[];
      }
      final tracks = await _musicLibraryRepository.getPlaylistTracks(
        playlistId,
      );
      _nodeTracksCache[nodeId] = tracks;
      return tracks
          .map(
            (track) => _playableItem(
              id: _encodePlayId(nodeId: nodeId, trackId: track.id),
              title: track.title,
              subtitle: track.artist,
            ),
          )
          .toList(growable: false);
    }

    return const <Map<String, Object?>>[];
  }

  Future<void> _playItem(String id) async {
    final decoded = _decodePlayId(id);
    if (decoded == null) {
      return;
    }

    final nodeId = decoded.nodeId;
    final trackId = decoded.trackId;
    final tracks = await _tracksForQueueNode(nodeId);

    var startIndex = tracks.indexWhere((track) => track.id == trackId);
    List<Track> queue = tracks;

    if (queue.isEmpty || startIndex == -1) {
      final track = await _musicLibraryRepository.getTrackById(trackId);
      if (track == null) {
        return;
      }
      queue = <Track>[track];
      startIndex = 0;
    }

    await _audioPlayerService.setQueue(queue, startIndex: startIndex);
    await _audioPlayerService.play(queue[startIndex]);
  }

  Future<List<Track>> _tracksForQueueNode(String nodeId) async {
    _maybeExpireCaches();
    final cached = _nodeTracksCache[nodeId];
    if (cached != null) {
      return cached;
    }

    if (nodeId == 'tracks') {
      final tracks = await _ensureAllTracks();
      return tracks;
    }

    if (nodeId.startsWith('tracks:group:')) {
      final letter = nodeId.substring('tracks:group:'.length);
      return _tracksForTracksGroup(letter);
    }

    if (nodeId.startsWith('artists:artist:')) {
      final artistName = _decodeB64(nodeId.substring('artists:artist:'.length));
      if (artistName == null || artistName.isEmpty) {
        return const <Track>[];
      }
      final tracks = await _musicLibraryRepository.getTracksByArtist(
        artistName,
      );
      tracks.sort(_compareTracksForArtist);
      return tracks;
    }

    if (nodeId.startsWith('albums:album:')) {
      final parts = nodeId.substring('albums:album:'.length).split(':');
      if (parts.length < 2) {
        return const <Track>[];
      }
      final artist = _decodeB64(parts[0]);
      final title = _decodeB64(parts[1]);
      if (artist == null || title == null || title.isEmpty) {
        return const <Track>[];
      }
      final tracks = await _musicLibraryRepository.getTracksByAlbum(title);
      final filtered =
          tracks
              .where((track) => track.album == title && track.artist == artist)
              .toList(growable: false)
            ..sort(_compareTracksForAlbum);
      return filtered;
    }

    if (nodeId.startsWith('playlists:playlist:')) {
      final playlistId = _decodeB64(
        nodeId.substring('playlists:playlist:'.length),
      );
      if (playlistId == null || playlistId.isEmpty) {
        return const <Track>[];
      }
      return _musicLibraryRepository.getPlaylistTracks(playlistId);
    }

    return const <Track>[];
  }

  Future<List<Track>> _tracksForTracksGroup(String letter) async {
    final tracks = await _ensureAllTracks();
    final filtered =
        tracks
            .where((track) => _groupKey(track.title) == letter)
            .toList(growable: false)
          ..sort((a, b) {
            final titleCmp = a.title.compareTo(b.title);
            if (titleCmp != 0) return titleCmp;
            return a.artist.compareTo(b.artist);
          });
    return filtered;
  }

  Future<List<Track>> _ensureAllTracks() async {
    final cached = _allTracksCache;
    if (cached != null) {
      return cached;
    }
    final tracks = await _musicLibraryRepository.getAllTracks();
    _allTracksCache = tracks;
    _lastCacheAt = DateTime.now();
    return tracks;
  }

  Future<List<Artist>> _ensureAllArtists() async {
    final cached = _allArtistsCache;
    if (cached != null) {
      return cached;
    }
    final artists = await _musicLibraryRepository.getAllArtists();
    _allArtistsCache = artists;
    _lastCacheAt = DateTime.now();
    return artists;
  }

  Future<List<Album>> _ensureAllAlbums() async {
    final cached = _allAlbumsCache;
    if (cached != null) {
      return cached;
    }
    final albums = await _musicLibraryRepository.getAllAlbums();
    _allAlbumsCache = albums;
    _lastCacheAt = DateTime.now();
    return albums;
  }

  Future<List<Playlist>> _ensureAllPlaylists() async {
    final cached = _allPlaylistsCache;
    if (cached != null) {
      return cached;
    }
    final playlists = await _musicLibraryRepository.getAllPlaylists();
    _allPlaylistsCache = playlists;
    _lastCacheAt = DateTime.now();
    return playlists;
  }

  void _maybeExpireCaches() {
    if (_lastCacheAt == DateTime.fromMillisecondsSinceEpoch(0)) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastCacheAt) < _cacheTtl) {
      return;
    }
    _allTracksCache = null;
    _allArtistsCache = null;
    _allAlbumsCache = null;
    _allPlaylistsCache = null;
    _nodeTracksCache.clear();
    _lastCacheAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, Object?>> _buildLetterGroups({
    required String prefix,
    required Iterable<String> titles,
    required String subtitleSuffix,
  }) {
    final counts = <String, int>{};
    for (final title in titles) {
      final key = _groupKey(title);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final result = <Map<String, Object?>>[];
    for (final code in List<int>.generate(26, (i) => 65 + i)) {
      final letter = String.fromCharCode(code);
      final count = counts[letter] ?? 0;
      if (count == 0) continue;
      result.add(
        _containerItem(
          id: '$prefix$letter',
          title: letter,
          subtitle: '$count$subtitleSuffix',
        ),
      );
    }

    final otherCount = counts['#'] ?? 0;
    if (otherCount > 0) {
      result.add(
        _containerItem(
          id: '$prefix#',
          title: '#',
          subtitle: '$otherCount$subtitleSuffix',
        ),
      );
    }

    return result;
  }

  String _groupKey(String input) {
    final trimmed = input.trimLeft();
    if (trimmed.isEmpty) {
      return '#';
    }
    final first = trimmed[0].toUpperCase();
    final code = first.codeUnitAt(0);
    if (code >= 65 && code <= 90) {
      return first;
    }
    return '#';
  }

  int _compareTracksForArtist(Track a, Track b) {
    final albumCmp = a.album.compareTo(b.album);
    if (albumCmp != 0) return albumCmp;
    final trackNoA = a.trackNumber ?? 0;
    final trackNoB = b.trackNumber ?? 0;
    final trackNoCmp = trackNoA.compareTo(trackNoB);
    if (trackNoCmp != 0) return trackNoCmp;
    return a.title.compareTo(b.title);
  }

  int _compareTracksForAlbum(Track a, Track b) {
    final trackNoA = a.trackNumber ?? 0;
    final trackNoB = b.trackNumber ?? 0;
    final trackNoCmp = trackNoA.compareTo(trackNoB);
    if (trackNoCmp != 0) return trackNoCmp;
    return a.title.compareTo(b.title);
  }

  Map<String, Object?> _containerItem({
    required String id,
    required String title,
    String? subtitle,
  }) {
    return <String, Object?>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'isPlayable': false,
      'isContainer': true,
    };
  }

  Map<String, Object?> _playableItem({
    required String id,
    required String title,
    String? subtitle,
  }) {
    return <String, Object?>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'isPlayable': true,
      'isContainer': false,
    };
  }

  String _encodePlayId({required String nodeId, required String trackId}) {
    return 'play:${_b64(nodeId)}:${_b64(trackId)}';
  }

  _PlayIdParts? _decodePlayId(String id) {
    if (!id.startsWith('play:')) {
      return null;
    }
    final parts = id.substring('play:'.length).split(':');
    if (parts.length < 2) {
      return null;
    }
    final nodeId = _decodeB64(parts[0]);
    final trackId = _decodeB64(parts[1]);
    if (nodeId == null || trackId == null) {
      return null;
    }
    return _PlayIdParts(nodeId: nodeId, trackId: trackId);
  }

  String _b64(String value) {
    return base64UrlEncode(utf8.encode(value));
  }

  String? _decodeB64(String value) {
    try {
      return utf8.decode(base64Url.decode(value));
    } catch (_) {
      return null;
    }
  }
}

class _PlayIdParts {
  const _PlayIdParts({required this.nodeId, required this.trackId});

  final String nodeId;
  final String trackId;
}
