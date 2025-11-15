import 'dart:async';
import 'package:rxdart/rxdart.dart';

import '../../core/storage/binary_config_store.dart';
import '../../core/storage/sandbox_path_codec.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/repositories/playback_history_repository.dart';

class PlaybackHistoryRepositoryImpl implements PlaybackHistoryRepository {
  PlaybackHistoryRepositoryImpl(this._configStore, this._sandboxPathCodec)
    : _historySubject = BehaviorSubject<List<PlaybackHistoryEntry>>.seeded(
        const [],
      );

  static const int _maxEntries = 200;

  final BinaryConfigStore _configStore;
  final SandboxPathCodec _sandboxPathCodec;
  final BehaviorSubject<List<PlaybackHistoryEntry>> _historySubject;
  final StreamController<Track> _trackUpdateController =
      StreamController<Track>.broadcast();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _configStore.init();
    _initialized = true;
    final entries = await _readFromPreferences();
    _historySubject.add(entries);
  }

  Future<List<PlaybackHistoryEntry>> _readFromPreferences() async {
    final stored = _configStore.getValue<dynamic>(StorageKeys.playbackHistory);
    if (stored is! List) {
      return const [];
    }

    final entries = <PlaybackHistoryEntry>[];
    for (final item in stored) {
      Map<String, dynamic>? map;
      if (item is Map<String, dynamic>) {
        map = item;
      } else if (item is Map) {
        map = Map<String, dynamic>.from(item);
      }
      if (map == null) {
        continue;
      }
      try {
        entries.add(await _entryFromMap(map));
      } catch (_) {
        // ignore malformed entry
      }
    }
    return entries;
  }

  Future<void> _persist(List<PlaybackHistoryEntry> entries) async {
    final encoded = <Map<String, dynamic>>[];
    for (final entry in entries) {
      encoded.add(await _entryToMap(entry));
    }
    await _configStore.setValue(StorageKeys.playbackHistory, encoded);
  }

  Future<Map<String, dynamic>> _entryToMap(PlaybackHistoryEntry entry) async {
    return {
      'playedAt': entry.playedAt.toIso8601String(),
      'track': await _trackToMap(entry.track),
      'playCount': entry.playCount,
      'fingerprint': entry.fingerprint,
    };
  }

  Future<PlaybackHistoryEntry> _entryFromMap(Map<String, dynamic> map) async {
    final playedAtString = map['playedAt'] as String?;
    final playedAt = DateTime.tryParse(playedAtString ?? '') ?? DateTime.now();
    final trackMap = map['track'];
    if (trackMap is! Map<String, dynamic>) {
      throw const FormatException('Invalid track payload');
    }
    final playCount = (map['playCount'] as num?)?.toInt() ?? 1;
    final fingerprint = map['fingerprint'] as String?;
    return PlaybackHistoryEntry(
      track: await _trackFromMap(trackMap),
      playedAt: playedAt,
      playCount: playCount,
      fingerprint: fingerprint,
    );
  }

  Future<Map<String, dynamic>> _trackToMap(Track track) async {
    final encodedFilePath = await _sandboxPathCodec.encode(track.filePath);
    String? encodedArtwork;
    final artworkPath = track.artworkPath;
    if (artworkPath != null && artworkPath.isNotEmpty) {
      encodedArtwork = await _sandboxPathCodec.encode(artworkPath);
    }

    return {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'filePath': encodedFilePath,
      'durationMs': track.duration.inMilliseconds,
      'dateAdded': track.dateAdded.toIso8601String(),
      'artworkPath': encodedArtwork ?? track.artworkPath,
      'trackNumber': track.trackNumber,
      'year': track.year,
      'genre': track.genre,
      'sourceType': track.sourceType.name,
      'sourceId': track.sourceId,
      'remotePath': track.remotePath,
      'httpHeaders': track.httpHeaders,
      'contentHash': track.contentHash,
    };
  }

  Future<Track> _trackFromMap(Map<String, dynamic> map) async {
    final sourceTypeName = map['sourceType'] as String?;
    final sourceType = sourceTypeName == null
        ? TrackSourceType.local
        : TrackSourceType.values.firstWhere(
            (type) => type.name == sourceTypeName,
            orElse: () => TrackSourceType.local,
          );
    final headers = map['httpHeaders'];
    Map<String, String>? httpHeaders;
    if (headers is Map) {
      httpHeaders = headers.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
    final storedFilePath = map['filePath'] as String;
    final decodedFilePath = await _sandboxPathCodec.decode(storedFilePath);
    final storedArtwork = map['artworkPath'] as String?;
    String? decodedArtwork;
    if (storedArtwork != null && storedArtwork.isNotEmpty) {
      decodedArtwork = await _sandboxPathCodec.decode(storedArtwork);
    }
    return Track(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      filePath: decodedFilePath,
      duration: Duration(
        milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0,
      ),
      dateAdded:
          DateTime.tryParse(map['dateAdded'] as String? ?? '') ??
          DateTime.now(),
      artworkPath: decodedArtwork,
      trackNumber: (map['trackNumber'] as num?)?.toInt(),
      year: (map['year'] as num?)?.toInt(),
      genre: map['genre'] as String?,
      sourceType: sourceType,
      sourceId: map['sourceId'] as String?,
      remotePath: map['remotePath'] as String?,
      httpHeaders: httpHeaders,
      contentHash: map['contentHash'] as String?,
    );
  }

  List<PlaybackHistoryEntry> _sortAndLimit(
    List<PlaybackHistoryEntry> entries,
    int? limit,
  ) {
    final sorted = List<PlaybackHistoryEntry>.from(entries)
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    if (limit != null && limit < sorted.length) {
      return sorted.take(limit).toList();
    }
    if (sorted.length > _maxEntries) {
      return sorted.take(_maxEntries).toList();
    }
    return sorted;
  }

  @override
  Future<void> recordPlay(
    Track track,
    DateTime playedAt, {
    String? fingerprint,
  }) async {
    await _ensureInitialized();
    final history = List<PlaybackHistoryEntry>.from(_historySubject.value);
    final key = fingerprint ?? track.id;
    final existingIndex = history.indexWhere((entry) {
      if (entry.fingerprint != null) {
        return entry.fingerprint == key;
      }
      return entry.track.id == track.id;
    });

    if (existingIndex != -1) {
      final existing = history.removeAt(existingIndex);
      final updated = existing.copyWith(
        track: track,
        playedAt: playedAt,
        playCount: existing.playCount + 1,
        fingerprint: existing.fingerprint ?? key,
      );
      history.insert(0, updated);
    } else {
      history.insert(
        0,
        PlaybackHistoryEntry(
          track: track,
          playedAt: playedAt,
          playCount: 1,
          fingerprint: key,
        ),
      );
    }
    final limited = _sortAndLimit(history, _maxEntries);
    _historySubject.add(limited);
    await _persist(limited);
    _emitTrackUpdate(track);
  }

  @override
  Future<List<PlaybackHistoryEntry>> getHistory({int limit = 100}) async {
    await _ensureInitialized();
    return _sortAndLimit(_historySubject.value, limit);
  }

  @override
  Stream<List<PlaybackHistoryEntry>> watchHistory({int? limit}) async* {
    await _ensureInitialized();
    yield* _historySubject.stream.map(
      (entries) => _sortAndLimit(entries, limit),
    );
  }

  @override
  Future<void> clearHistory() async {
    await _ensureInitialized();
    _historySubject.add(const []);
    await _configStore.remove(StorageKeys.playbackHistory);
  }

  @override
  Future<void> updateTrackMetadata(Track track) async {
    await _ensureInitialized();
    final current = List<PlaybackHistoryEntry>.from(_historySubject.value);
    bool changed = false;

    for (int i = 0; i < current.length; i++) {
      final entry = current[i];
      if (entry.track.id != track.id) {
        continue;
      }
      if (entry.track == track) {
        continue;
      }
      current[i] = entry.copyWith(track: track);
      changed = true;
    }

    if (!changed) {
      return;
    }

    final limited = _sortAndLimit(current, _maxEntries);
    _historySubject.add(limited);
    await _persist(limited);
    _emitTrackUpdate(track);
  }

  @override
  Stream<Track> watchTrackUpdates() => _trackUpdateController.stream;

  void _emitTrackUpdate(Track track) {
    try {
      _trackUpdateController.add(track);
    } catch (_) {
      // ignore
    }
  }
}
