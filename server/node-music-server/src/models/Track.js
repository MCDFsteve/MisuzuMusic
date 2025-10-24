class Track {
  constructor(data = {}) {
    this.id = data.id || null;
    this.title = data.title || '';
    this.artist = data.artist || null;
    this.album = data.album || null;
    this.albumArtist = data.albumArtist || null;
    this.genre = data.genre || null;
    this.year = data.year || null;
    this.track = data.track || null;
    this.disc = data.disc || null;
    this.duration = data.duration || null;
    this.bitrate = data.bitrate || null;
    this.sampleRate = data.sampleRate || null;
    this.channels = data.channels || null;
    this.codecName = data.codecName || null;
    this.formatName = data.formatName || null;
    this.fileSize = data.fileSize || null;
    this.filePath = data.filePath || '';
    this.relativePath = data.relativePath || '';
    this.fileName = data.fileName || '';
    this.fileExtension = data.fileExtension || '';
    this.coverPath = data.coverPath || null;
    this.thumbnailPath = data.thumbnailPath || null;
    this.lastModified = data.lastModified || null;
    this.dateAdded = data.dateAdded || new Date().toISOString();
    this.playCount = data.playCount || 0;
    this.lastPlayed = data.lastPlayed || null;
    this.tags = data.tags || {};
  }

  // 从数据库行创建Track实例
  static fromDbRow(row) {
    return new Track({
      id: row.id,
      title: row.title,
      artist: row.artist,
      album: row.album,
      albumArtist: row.album_artist,
      genre: row.genre,
      year: row.year,
      track: row.track_number,
      disc: row.disc_number,
      duration: row.duration,
      bitrate: row.bitrate,
      sampleRate: row.sample_rate,
      channels: row.channels,
      codecName: row.codec_name,
      formatName: row.format_name,
      fileSize: row.file_size,
      filePath: row.file_path,
      relativePath: row.relative_path,
      fileName: row.file_name,
      fileExtension: row.file_extension,
      coverPath: row.cover_path,
      thumbnailPath: row.thumbnail_path,
      lastModified: row.last_modified,
      dateAdded: row.date_added,
      playCount: row.play_count,
      lastPlayed: row.last_played,
      tags: row.tags ? JSON.parse(row.tags) : {}
    });
  }

  // 转换为数据库格式
  toDbRow() {
    return {
      id: this.id,
      title: this.title,
      artist: this.artist,
      album: this.album,
      album_artist: this.albumArtist,
      genre: this.genre,
      year: this.year,
      track_number: this.track,
      disc_number: this.disc,
      duration: this.duration,
      bitrate: this.bitrate,
      sample_rate: this.sampleRate,
      channels: this.channels,
      codec_name: this.codecName,
      format_name: this.formatName,
      file_size: this.fileSize,
      file_path: this.filePath,
      relative_path: this.relativePath,
      file_name: this.fileName,
      file_extension: this.fileExtension,
      cover_path: this.coverPath,
      thumbnail_path: this.thumbnailPath,
      last_modified: this.lastModified,
      date_added: this.dateAdded,
      play_count: this.playCount,
      last_played: this.lastPlayed,
      tags: JSON.stringify(this.tags)
    };
  }

  // 转换为API响应格式
  toApiResponse() {
    return {
      id: this.id,
      title: this.title,
      artist: this.artist,
      album: this.album,
      albumArtist: this.albumArtist,
      genre: this.genre,
      year: this.year,
      track: this.track,
      disc: this.disc,
      duration: this.duration,
      bitrate: this.bitrate,
      sampleRate: this.sampleRate,
      channels: this.channels,
      codecName: this.codecName,
      formatName: this.formatName,
      fileSize: this.fileSize,
      relativePath: this.relativePath,
      fileName: this.fileName,
      fileExtension: this.fileExtension,
      coverPath: this.coverPath,
      thumbnailPath: this.thumbnailPath,
      lastModified: this.lastModified,
      dateAdded: this.dateAdded,
      playCount: this.playCount,
      lastPlayed: this.lastPlayed,
      tags: this.tags,
      // 生成流媒体URL
      streamUrl: `/stream/${this.id}`,
      coverUrl: this.coverPath ? `/assets/cover/${this.id}` : null,
      thumbnailUrl: this.thumbnailPath ? `/assets/thumbnail/${this.id}` : null
    };
  }

  // 验证数据
  validate() {
    const errors = [];

    if (!this.title || this.title.trim() === '') {
      errors.push('Title is required');
    }

    if (!this.filePath || this.filePath.trim() === '') {
      errors.push('File path is required');
    }

    if (this.duration !== null && (typeof this.duration !== 'number' || this.duration < 0)) {
      errors.push('Duration must be a positive number');
    }

    if (this.year !== null && (typeof this.year !== 'number' || this.year < 1000 || this.year > new Date().getFullYear() + 10)) {
      errors.push('Year must be a valid year');
    }

    return errors;
  }

  // 格式化持续时间
  get formattedDuration() {
    if (!this.duration) return null;

    const minutes = Math.floor(this.duration / 60);
    const seconds = Math.floor(this.duration % 60);
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  // 格式化文件大小
  get formattedFileSize() {
    if (!this.fileSize) return null;

    const units = ['B', 'KB', 'MB', 'GB'];
    let size = this.fileSize;
    let unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return `${size.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
  }

  // 格式化比特率
  get formattedBitrate() {
    if (!this.bitrate) return null;
    return `${Math.round(this.bitrate / 1000)} kbps`;
  }
}

module.exports = Track;