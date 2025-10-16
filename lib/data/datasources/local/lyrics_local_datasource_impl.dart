import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/exceptions.dart';
import '../../models/lyrics_models.dart';
import 'database_helper.dart';
import 'lyrics_local_datasource.dart';

class LyricsLocalDataSourceImpl implements LyricsLocalDataSource {
  final DatabaseHelper _databaseHelper;
  final SharedPreferences _sharedPreferences;

  static const String _lyricsSettingsKey = 'lyrics_settings';

  LyricsLocalDataSourceImpl(this._databaseHelper, this._sharedPreferences);

  @override
  Future<LyricsModel?> getLyricsByTrackId(String trackId) async {
    try {
      final maps = await _databaseHelper.query(
        'lyrics',
        where: 'track_id = ?',
        whereArgs: [trackId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return LyricsModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw DatabaseException('Failed to get lyrics: ${e.toString()}');
    }
  }

  @override
  Future<void> insertLyrics(LyricsModel lyrics) async {
    try {
      await _databaseHelper.insert('lyrics', lyrics.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert lyrics: ${e.toString()}');
    }
  }

  @override
  Future<void> updateLyrics(LyricsModel lyrics) async {
    try {
      await _databaseHelper.update(
        'lyrics',
        lyrics.toMap(),
        where: 'track_id = ?',
        whereArgs: [lyrics.trackId],
      );
    } catch (e) {
      throw DatabaseException('Failed to update lyrics: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteLyrics(String trackId) async {
    try {
      await _databaseHelper.delete(
        'lyrics',
        where: 'track_id = ?',
        whereArgs: [trackId],
      );
    } catch (e) {
      throw DatabaseException('Failed to delete lyrics: ${e.toString()}');
    }
  }

  @override
  Future<bool> hasLyrics(String trackId) async {
    try {
      final maps = await _databaseHelper.query(
        'lyrics',
        columns: ['track_id'],
        where: 'track_id = ?',
        whereArgs: [trackId],
        limit: 1,
      );
      return maps.isNotEmpty;
    } catch (e) {
      throw DatabaseException('Failed to check lyrics existence: ${e.toString()}');
    }
  }

  @override
  Future<LyricsSettingsModel> getLyricsSettings() async {
    try {
      final settingsJson = _sharedPreferences.getString(_lyricsSettingsKey);
      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        return LyricsSettingsModel.fromMap(settingsMap);
      }
      // Return default settings
      return const LyricsSettingsModel();
    } catch (e) {
      throw DatabaseException('Failed to get lyrics settings: ${e.toString()}');
    }
  }

  @override
  Future<void> saveLyricsSettings(LyricsSettingsModel settings) async {
    try {
      final settingsJson = json.encode(settings.toMap());
      await _sharedPreferences.setString(_lyricsSettingsKey, settingsJson);
    } catch (e) {
      throw DatabaseException('Failed to save lyrics settings: ${e.toString()}');
    }
  }
}