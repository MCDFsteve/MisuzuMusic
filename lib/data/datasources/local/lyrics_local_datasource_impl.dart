import '../../../core/error/exceptions.dart';
import '../../../core/storage/binary_config_store.dart';
import '../../../core/storage/storage_keys.dart';
import '../../models/lyrics_models.dart';
import 'database_helper.dart';
import 'lyrics_local_datasource.dart';

class LyricsLocalDataSourceImpl implements LyricsLocalDataSource {
  final DatabaseHelper _databaseHelper;
  final BinaryConfigStore _configStore;

  static const String _lyricsSettingsKey = StorageKeys.lyricsSettings;

  LyricsLocalDataSourceImpl(this._databaseHelper, this._configStore);

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
      await _configStore.init();
      final raw = _configStore.getValue<dynamic>(_lyricsSettingsKey);
      if (raw is Map<String, dynamic>) {
        return LyricsSettingsModel.fromMap(raw);
      }
      if (raw is Map) {
        return LyricsSettingsModel.fromMap(Map<String, dynamic>.from(raw));
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
      await _configStore.setValue(_lyricsSettingsKey, settings.toMap());
    } catch (e) {
      throw DatabaseException('Failed to save lyrics settings: ${e.toString()}');
    }
  }
}
