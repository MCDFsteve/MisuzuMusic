import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _databaseName = 'misuzu_music.db';
  static const int _databaseVersion = 1;

  // Singleton pattern
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      throw DatabaseException('Failed to initialize database: ${e.toString()}');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      // Create tracks table
      await db.execute('''
        CREATE TABLE tracks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          artist TEXT NOT NULL,
          album TEXT NOT NULL,
          file_path TEXT UNIQUE NOT NULL,
          duration_ms INTEGER NOT NULL,
          date_added INTEGER NOT NULL,
          artwork_path TEXT,
          track_number INTEGER,
          year INTEGER,
          genre TEXT
        )
      ''');

      // Create playlists table
      await db.execute('''
        CREATE TABLE playlists (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create playlist_tracks table
      await db.execute('''
        CREATE TABLE playlist_tracks (
          playlist_id TEXT NOT NULL,
          track_id TEXT NOT NULL,
          position INTEGER NOT NULL,
          PRIMARY KEY (playlist_id, track_id),
          FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
          FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
        )
      ''');

      // Create lyrics table
      await db.execute('''
        CREATE TABLE lyrics (
          track_id TEXT PRIMARY KEY,
          content TEXT NOT NULL,
          format TEXT NOT NULL,
          FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_tracks_artist ON tracks(artist)');
      await db.execute('CREATE INDEX idx_tracks_album ON tracks(album)');
      await db.execute('CREATE INDEX idx_tracks_title ON tracks(title)');
      await db.execute('CREATE INDEX idx_tracks_date_added ON tracks(date_added)');
      await db.execute('CREATE INDEX idx_playlist_tracks_playlist_id ON playlist_tracks(playlist_id)');
      await db.execute('CREATE INDEX idx_playlist_tracks_position ON playlist_tracks(position)');

      // Create full-text search virtual table for tracks
      await db.execute('''
        CREATE VIRTUAL TABLE tracks_fts USING fts5(
          title,
          artist,
          album,
          genre,
          content=tracks,
          content_rowid=rowid
        )
      ''');

      // Create triggers to keep FTS table in sync
      await db.execute('''
        CREATE TRIGGER tracks_fts_insert AFTER INSERT ON tracks BEGIN
          INSERT INTO tracks_fts(rowid, title, artist, album, genre)
          VALUES (new.rowid, new.title, new.artist, new.album, new.genre);
        END
      ''');

      await db.execute('''
        CREATE TRIGGER tracks_fts_delete AFTER DELETE ON tracks BEGIN
          INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, genre)
          VALUES ('delete', old.rowid, old.title, old.artist, old.album, old.genre);
        END
      ''');

      await db.execute('''
        CREATE TRIGGER tracks_fts_update AFTER UPDATE ON tracks BEGIN
          INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, genre)
          VALUES ('delete', old.rowid, old.title, old.artist, old.album, old.genre);
          INSERT INTO tracks_fts(rowid, title, artist, album, genre)
          VALUES (new.rowid, new.title, new.artist, new.album, new.genre);
        END
      ''');

    } catch (e) {
      throw DatabaseException('Failed to create database tables: ${e.toString()}');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here when version changes
    try {
      // Example migration logic:
      // if (oldVersion < 2) {
      //   await db.execute('ALTER TABLE tracks ADD COLUMN new_column TEXT');
      // }
    } catch (e) {
      throw DatabaseException('Failed to upgrade database: ${e.toString()}');
    }
  }

  // Generic query methods
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      return await db.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw DatabaseException('Query failed: ${e.toString()}');
    }
  }

  Future<int> insert(String table, Map<String, Object?> values) async {
    try {
      final db = await database;
      return await db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      throw DatabaseException('Insert failed: ${e.toString()}');
    }
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final db = await database;
      return await db.update(table, values, where: where, whereArgs: whereArgs);
    } catch (e) {
      throw DatabaseException('Update failed: ${e.toString()}');
    }
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final db = await database;
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      throw DatabaseException('Delete failed: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    try {
      final db = await database;
      return await db.rawQuery(sql, arguments);
    } catch (e) {
      throw DatabaseException('Raw query failed: ${e.toString()}');
    }
  }

  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    try {
      final db = await database;
      return await db.rawInsert(sql, arguments);
    } catch (e) {
      throw DatabaseException('Raw insert failed: ${e.toString()}');
    }
  }

  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    try {
      final db = await database;
      return await db.rawUpdate(sql, arguments);
    } catch (e) {
      throw DatabaseException('Raw update failed: ${e.toString()}');
    }
  }

  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    try {
      final db = await database;
      return await db.rawDelete(sql, arguments);
    } catch (e) {
      throw DatabaseException('Raw delete failed: ${e.toString()}');
    }
  }

  // Transaction support
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    try {
      final db = await database;
      return await db.transaction(action);
    } catch (e) {
      throw DatabaseException('Transaction failed: ${e.toString()}');
    }
  }

  // Batch operations
  Future<List<Object?>> batch(void Function(Batch batch) operations) async {
    try {
      final db = await database;
      final batch = db.batch();
      operations(batch);
      return await batch.commit();
    } catch (e) {
      throw DatabaseException('Batch operation failed: ${e.toString()}');
    }
  }

  // Full-text search
  Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT tracks.* FROM tracks
        JOIN tracks_fts ON tracks.rowid = tracks_fts.rowid
        WHERE tracks_fts MATCH ?
        ORDER BY rank
      ''', [query]);
    } catch (e) {
      throw DatabaseException('Search failed: ${e.toString()}');
    }
  }

  // Database maintenance
  Future<void> vacuum() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
    } catch (e) {
      throw DatabaseException('Vacuum failed: ${e.toString()}');
    }
  }

  Future<void> analyze() async {
    try {
      final db = await database;
      await db.execute('ANALYZE');
    } catch (e) {
      throw DatabaseException('Analyze failed: ${e.toString()}');
    }
  }

  Future<int> getDatabaseSize() async {
    try {
      final db = await database;
      final result = await db.rawQuery('PRAGMA page_count');
      final pageCount = result.first['page_count'] as int;

      final pageSizeResult = await db.rawQuery('PRAGMA page_size');
      final pageSize = pageSizeResult.first['page_size'] as int;

      return pageCount * pageSize;
    } catch (e) {
      throw DatabaseException('Failed to get database size: ${e.toString()}');
    }
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Delete database
  Future<void> deleteDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);
      await databaseFactory.deleteDatabase(path);
      _database = null;
    } catch (e) {
      throw DatabaseException('Failed to delete database: ${e.toString()}');
    }
  }
}