import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/repositories/playback_history_repository.dart';

class PlaybackHistoryRepositoryImpl implements PlaybackHistoryRepository {
  PlaybackHistoryRepositoryImpl(this._preferences)
      : _historySubject = BehaviorSubject<List<PlaybackHistoryEntry>>.seeded(const []);

  static const int _maxEntries = 200;

  final SharedPreferences _preferences;
  final BehaviorSubject<List<PlaybackHistoryEntry>> _historySubject;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    final entries = _readFromPreferences();
    _historySubject.add(entries);
  }

  List<PlaybackHistoryEntry> _readFromPreferences() {
    final stored = _preferences.getString(AppConstants.settingsPlaybackHistory);
    if (stored == null || stored.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) {
        return const [];
      }
      final entries = <PlaybackHistoryEntry>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        try {
          entries.add(_entryFromMap(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Skip malformed entry
        }
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(List<PlaybackHistoryEntry> entries) async {
    final encoded = jsonEncode(entries.map(_entryToMap).toList());
    await _preferences.setString(AppConstants.settingsPlaybackHistory, encoded);
  }

  Map<String, dynamic> _entryToMap(PlaybackHistoryEntry entry) {
    return {
      'playedAt': entry.playedAt.toIso8601String(),
      'track': _trackToMap(entry.track),
    };
  }

  PlaybackHistoryEntry _entryFromMap(Map<String, dynamic> map) {
    final playedAtString = map['playedAt'] as String?;
    final playedAt = DateTime.tryParse(playedAtString ?? '') ?? DateTime.now();
    final trackMap = map['track'];
    if (trackMap is! Map<String, dynamic>) {
      throw const FormatException('Invalid track payload');
    }
    return PlaybackHistoryEntry(
      track: _trackFromMap(trackMap),
      playedAt: playedAt,
    );
  }

  Map<String, dynamic> _trackToMap(Track track) {
    return {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'filePath': track.filePath,
      'durationMs': track.duration.inMilliseconds,
      'dateAdded': track.dateAdded.toIso8601String(),
      'artworkPath': track.artworkPath,
      'trackNumber': track.trackNumber,
      'year': track.year,
      'genre': track.genre,
    };
  }

  Track _trackFromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      filePath: map['filePath'] as String,
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
      dateAdded: DateTime.tryParse(map['dateAdded'] as String? ?? '') ?? DateTime.now(),
      artworkPath: map['artworkPath'] as String?,
      trackNumber: (map['trackNumber'] as num?)?.toInt(),
      year: (map['year'] as num?)?.toInt(),
      genre: map['genre'] as String?,
    );
  }

  List<PlaybackHistoryEntry> _sortAndLimit(List<PlaybackHistoryEntry> entries, int? limit) {
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
  Future<void> recordPlay(Track track, DateTime playedAt) async {
    await _ensureInitialized();
    final history = List<PlaybackHistoryEntry>.from(_historySubject.value);
    history.removeWhere((entry) => entry.track.id == track.id);
    history.insert(0, PlaybackHistoryEntry(track: track, playedAt: playedAt));
    final limited = _sortAndLimit(history, _maxEntries);
    _historySubject.add(limited);
    await _persist(limited);
  }

  @override
  Future<List<PlaybackHistoryEntry>> getHistory({int limit = 100}) async {
    await _ensureInitialized();
    return _sortAndLimit(_historySubject.value, limit);
  }

  @override
  Stream<List<PlaybackHistoryEntry>> watchHistory({int? limit}) async* {
    await _ensureInitialized();
    yield* _historySubject.stream.map((entries) => _sortAndLimit(entries, limit));
  }

  @override
  Future<void> clearHistory() async {
    await _ensureInitialized();
    _historySubject.add(const []);
    await _preferences.remove(AppConstants.settingsPlaybackHistory);
  }
}
