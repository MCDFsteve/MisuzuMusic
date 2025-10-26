const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs').promises;
const config = require('../../config/config');
const { Track } = require('../models');

class DatabaseService {
  constructor() {
    this.db = null;
    this.isInitialized = false;
  }

  async init() {
    try {
      // 确保数据目录存在
      const dbDir = path.dirname(config.database.path);
      await fs.mkdir(dbDir, { recursive: true });

      // 打开数据库连接
      this.db = new Database(config.database.path, config.database.options);

      // 设置数据库配置
      this.db.pragma('journal_mode = WAL');
      this.db.pragma('foreign_keys = ON');
      this.db.pragma('synchronous = NORMAL');
      this.db.pragma('cache_size = 1000');
      this.db.pragma('temp_store = memory');

      // 创建表
      await this.createTables();

      // 创建索引
      await this.createIndexes();

      this.isInitialized = true;
      console.log('✅ Database initialized successfully');
    } catch (error) {
      console.error('❌ Database initialization failed:', error);
      throw error;
    }
  }

  createTables() {
    // 创建tracks表
    const createTracksTable = `
      CREATE TABLE IF NOT EXISTS tracks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT,
        album TEXT,
        album_artist TEXT,
        genre TEXT,
        year INTEGER,
        track_number INTEGER,
        disc_number INTEGER,
        duration REAL,
        bitrate INTEGER,
        sample_rate INTEGER,
        channels INTEGER,
        codec_name TEXT,
        format_name TEXT,
        file_size INTEGER,
        file_path TEXT NOT NULL UNIQUE,
        relative_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_extension TEXT,
        cover_path TEXT,
        thumbnail_path TEXT,
        last_modified TEXT,
        date_added TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        play_count INTEGER DEFAULT 0,
        last_played TEXT,
        tags TEXT DEFAULT '{}',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `;

    // 创建播放历史表
    const createPlayHistoryTable = `
      CREATE TABLE IF NOT EXISTS play_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_id TEXT NOT NULL,
        played_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        duration_played REAL,
        FOREIGN KEY (track_id) REFERENCES tracks (id) ON DELETE CASCADE
      )
    `;

    // 创建播放列表表
    const createPlaylistsTable = `
      CREATE TABLE IF NOT EXISTS playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        cover_path TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `;

    // 创建播放列表曲目关联表
    const createPlaylistTracksTable = `
      CREATE TABLE IF NOT EXISTS playlist_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT NOT NULL,
        track_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        added_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE,
        FOREIGN KEY (track_id) REFERENCES tracks (id) ON DELETE CASCADE,
        UNIQUE (playlist_id, track_id)
      )
    `;

    // 创建扫描历史表
    const createScanHistoryTable = `
      CREATE TABLE IF NOT EXISTS scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        files_scanned INTEGER DEFAULT 0,
        files_added INTEGER DEFAULT 0,
        files_updated INTEGER DEFAULT 0,
        files_removed INTEGER DEFAULT 0,
        errors TEXT DEFAULT '[]',
        status TEXT DEFAULT 'running'
      )
    `;

    this.db.exec(createTracksTable);
    this.db.exec(createPlayHistoryTable);
    this.db.exec(createPlaylistsTable);
    this.db.exec(createPlaylistTracksTable);
    this.db.exec(createScanHistoryTable);
  }

  createIndexes() {
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks (artist)',
      'CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks (album)',
      'CREATE INDEX IF NOT EXISTS idx_tracks_genre ON tracks (genre)',
      'CREATE INDEX IF NOT EXISTS idx_tracks_year ON tracks (year)',
      'CREATE INDEX IF NOT EXISTS idx_tracks_title ON tracks (title)',
      'CREATE INDEX IF NOT EXISTS idx_tracks_file_path ON tracks (file_path)',
      'CREATE INDEX IF NOT EXISTS idx_tracks_date_added ON tracks (date_added)',
      'CREATE INDEX IF NOT EXISTS idx_play_history_track_id ON play_history (track_id)',
      'CREATE INDEX IF NOT EXISTS idx_play_history_played_at ON play_history (played_at)',
      'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_id ON playlist_tracks (playlist_id)',
      'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_position ON playlist_tracks (playlist_id, position)',

      // 全文搜索索引
      'CREATE VIRTUAL TABLE IF NOT EXISTS tracks_fts USING fts5(title, artist, album, genre, content=tracks, content_rowid=rowid)',

      // 触发器保持FTS索引同步
      `CREATE TRIGGER IF NOT EXISTS tracks_fts_insert AFTER INSERT ON tracks BEGIN
        INSERT INTO tracks_fts(rowid, title, artist, album, genre) VALUES (new.rowid, new.title, new.artist, new.album, new.genre);
      END`,

      `CREATE TRIGGER IF NOT EXISTS tracks_fts_delete AFTER DELETE ON tracks BEGIN
        INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, genre) VALUES ('delete', old.rowid, old.title, old.artist, old.album, old.genre);
      END`,

      `CREATE TRIGGER IF NOT EXISTS tracks_fts_update AFTER UPDATE ON tracks BEGIN
        INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, genre) VALUES ('delete', old.rowid, old.title, old.artist, old.album, old.genre);
        INSERT INTO tracks_fts(rowid, title, artist, album, genre) VALUES (new.rowid, new.title, new.artist, new.album, new.genre);
      END`
    ];

    indexes.forEach(sql => {
      try {
        this.db.exec(sql);
      } catch (error) {
        console.warn('Index creation warning:', error.message);
      }
    });
  }

  // Track CRUD operations
  async createTrack(trackData) {
    const track = new Track(trackData);
    const errors = track.validate();

    if (errors.length > 0) {
      throw new Error(`Validation failed: ${errors.join(', ')}`);
    }

    // 生成ID
    if (!track.id) {
      track.id = this.generateId();
    }

    const stmt = this.db.prepare(`
      INSERT INTO tracks (
        id, title, artist, album, album_artist, genre, year, track_number, disc_number,
        duration, bitrate, sample_rate, channels, codec_name, format_name, file_size,
        file_path, relative_path, file_name, file_extension, cover_path, thumbnail_path,
        last_modified, date_added, play_count, last_played, tags
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    `);

    const row = track.toDbRow();
    stmt.run(
      row.id, row.title, row.artist, row.album, row.album_artist, row.genre, row.year,
      row.track_number, row.disc_number, row.duration, row.bitrate, row.sample_rate,
      row.channels, row.codec_name, row.format_name, row.file_size, row.file_path,
      row.relative_path, row.file_name, row.file_extension, row.cover_path,
      row.thumbnail_path, row.last_modified, row.date_added, row.play_count,
      row.last_played, row.tags
    );

    return track;
  }

  async getTrackById(id) {
    const stmt = this.db.prepare('SELECT * FROM tracks WHERE id = ?');
    const row = stmt.get(id);
    return row ? Track.fromDbRow(row) : null;
  }

  async getTrackByPath(filePath) {
    const stmt = this.db.prepare('SELECT * FROM tracks WHERE file_path = ?');
    const row = stmt.get(filePath);
    return row ? Track.fromDbRow(row) : null;
  }

  async getAllTracks(options = {}) {
    const { limit = 1000, offset = 0, orderBy = 'date_added', orderDir = 'DESC' } = options;

    const validOrderBy = ['title', 'artist', 'album', 'year', 'duration', 'date_added', 'play_count'];
    const validOrderDir = ['ASC', 'DESC'];

    const order = validOrderBy.includes(orderBy) ? orderBy : 'date_added';
    const direction = validOrderDir.includes(orderDir.toUpperCase()) ? orderDir.toUpperCase() : 'DESC';

    const stmt = this.db.prepare(`
      SELECT * FROM tracks
      ORDER BY ${order} ${direction}
      LIMIT ? OFFSET ?
    `);

    const rows = stmt.all(limit, offset);
    return rows.map(row => Track.fromDbRow(row));
  }

  async searchTracks(query, options = {}) {
    const { limit = 100, offset = 0 } = options;

    const stmt = this.db.prepare(`
      SELECT t.* FROM tracks t
      JOIN tracks_fts fts ON t.rowid = fts.rowid
      WHERE tracks_fts MATCH ?
      ORDER BY rank
      LIMIT ? OFFSET ?
    `);

    const rows = stmt.all(query, limit, offset);
    return rows.map(row => Track.fromDbRow(row));
  }

  async updateTrack(id, trackData) {
    const existingTrack = await this.getTrackById(id);
    if (!existingTrack) {
      throw new Error('Track not found');
    }

    const updatedTrack = new Track({ ...existingTrack, ...trackData, id });
    const errors = updatedTrack.validate();

    if (errors.length > 0) {
      throw new Error(`Validation failed: ${errors.join(', ')}`);
    }

    const stmt = this.db.prepare(`
      UPDATE tracks SET
        title = ?, artist = ?, album = ?, album_artist = ?, genre = ?, year = ?,
        track_number = ?, disc_number = ?, duration = ?, bitrate = ?, sample_rate = ?,
        channels = ?, codec_name = ?, format_name = ?, file_size = ?, file_path = ?,
        relative_path = ?, file_name = ?, file_extension = ?, cover_path = ?,
        thumbnail_path = ?, last_modified = ?, play_count = ?, last_played = ?,
        tags = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `);

    const row = updatedTrack.toDbRow();
    stmt.run(
      row.title, row.artist, row.album, row.album_artist, row.genre, row.year,
      row.track_number, row.disc_number, row.duration, row.bitrate, row.sample_rate,
      row.channels, row.codec_name, row.format_name, row.file_size, row.file_path,
      row.relative_path, row.file_name, row.file_extension, row.cover_path,
      row.thumbnail_path, row.last_modified, row.play_count, row.last_played,
      row.tags, id
    );

    return updatedTrack;
  }

  async deleteTrack(id) {
    const stmt = this.db.prepare('DELETE FROM tracks WHERE id = ?');
    const result = stmt.run(id);
    return result.changes > 0;
  }

  async deleteTrackByPath(filePath) {
    const stmt = this.db.prepare('DELETE FROM tracks WHERE file_path = ?');
    const result = stmt.run(filePath);
    return result.changes > 0;
  }

  // 统计方法
  async getTracksCount() {
    const stmt = this.db.prepare('SELECT COUNT(*) as count FROM tracks');
    return stmt.get().count;
  }

  async getArtists() {
    const stmt = this.db.prepare('SELECT DISTINCT artist FROM tracks WHERE artist IS NOT NULL ORDER BY artist');
    return stmt.all().map(row => row.artist);
  }

  async getAlbums() {
    const stmt = this.db.prepare('SELECT DISTINCT album FROM tracks WHERE album IS NOT NULL ORDER BY album');
    return stmt.all().map(row => row.album);
  }

  async getGenres() {
    const stmt = this.db.prepare('SELECT DISTINCT genre FROM tracks WHERE genre IS NOT NULL ORDER BY genre');
    return stmt.all().map(row => row.genre);
  }

  // 播放历史
  async recordPlay(trackId, durationPlayed = null) {
    const stmt = this.db.prepare(`
      INSERT INTO play_history (track_id, duration_played)
      VALUES (?, ?)
    `);
    stmt.run(trackId, durationPlayed);

    // 更新曲目播放次数
    const updateStmt = this.db.prepare(`
      UPDATE tracks SET
        play_count = play_count + 1,
        last_played = CURRENT_TIMESTAMP
      WHERE id = ?
    `);
    updateStmt.run(trackId);
  }

  // 扫描历史
  async createScanRecord() {
    const stmt = this.db.prepare(`
      INSERT INTO scan_history (started_at)
      VALUES (datetime('now'))
    `);
    const result = stmt.run();
    return result.lastInsertRowid;
  }

  async updateScanRecord(scanId, data) {
    const fields = [];
    const values = [];

    Object.entries(data).forEach(([key, value]) => {
      fields.push(`${key} = ?`);
      values.push(typeof value === 'object' ? JSON.stringify(value) : value);
    });

    if (fields.length === 0) return;

    const stmt = this.db.prepare(`
      UPDATE scan_history SET ${fields.join(', ')}
      WHERE id = ?
    `);
    stmt.run(...values, scanId);
  }

  // 工具方法
  generateId() {
    return require('crypto').randomUUID();
  }

  async close() {
    if (this.db) {
      this.db.close();
      this.db = null;
      this.isInitialized = false;
    }
  }

  // 事务支持
  transaction(fn) {
    return this.db.transaction(fn);
  }

  // 备份数据库
  async backup(backupPath) {
    return new Promise((resolve, reject) => {
      this.db.backup(backupPath)
        .then(() => resolve())
        .catch(reject);
    });
  }
}

module.exports = new DatabaseService();