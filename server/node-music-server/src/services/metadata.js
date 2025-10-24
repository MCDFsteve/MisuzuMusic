const mm = require('music-metadata');
const path = require('path');
const fs = require('fs').promises;
const sharp = require('sharp');
const config = require('../../config/config');

class MetadataService {
  constructor() {
    this.supportedFormats = config.music.supportedFormats;
  }

  /**
   * 从音频文件提取元数据
   */
  async extractMetadata(filePath) {
    try {
      const metadata = await mm.parseFile(filePath, {
        duration: true,
        skipCovers: false
      });

      const fileStats = await fs.stat(filePath);
      const relativePath = this.getRelativePath(filePath);

      const track = {
        title: metadata.common.title || path.basename(filePath, path.extname(filePath)),
        artist: metadata.common.artist || null,
        album: metadata.common.album || null,
        albumArtist: metadata.common.albumartist || null,
        genre: metadata.common.genre ? metadata.common.genre.join(', ') : null,
        year: metadata.common.year || null,
        track: metadata.common.track?.no || null,
        disc: metadata.common.disk?.no || null,
        duration: metadata.format.duration || null,
        bitrate: metadata.format.bitrate || null,
        sampleRate: metadata.format.sampleRate || null,
        channels: metadata.format.numberOfChannels || null,
        codecName: metadata.format.codec || null,
        formatName: metadata.format.container || null,
        fileSize: fileStats.size,
        filePath: filePath,
        relativePath: relativePath,
        fileName: path.basename(filePath),
        fileExtension: path.extname(filePath),
        lastModified: fileStats.mtime.toISOString(),
        tags: this.extractAllTags(metadata.common)
      };

      // 提取封面
      if (metadata.common.picture && metadata.common.picture.length > 0) {
        const coverPaths = await this.extractCover(filePath, metadata.common.picture[0]);
        track.coverPath = coverPaths.cover;
        track.thumbnailPath = coverPaths.thumbnail;
      } else {
        // 查找外部封面文件
        const externalCover = await this.findExternalCover(path.dirname(filePath));
        if (externalCover) {
          const coverPaths = await this.processCoverImage(externalCover, filePath);
          track.coverPath = coverPaths.cover;
          track.thumbnailPath = coverPaths.thumbnail;
        }
      }

      return track;
    } catch (error) {
      console.error(`Failed to extract metadata from ${filePath}:`, error);
      throw error;
    }
  }

  /**
   * 提取所有标签
   */
  extractAllTags(common) {
    const tags = {};
    const excludeFields = ['title', 'artist', 'album', 'albumartist', 'genre', 'year', 'track', 'disk', 'picture'];

    for (const [key, value] of Object.entries(common)) {
      if (!excludeFields.includes(key) && value !== undefined && value !== null) {
        tags[key] = value;
      }
    }

    return tags;
  }

  /**
   * 提取并处理封面图片
   */
  async extractCover(audioFilePath, picture) {
    try {
      const coverDir = path.join(path.dirname(audioFilePath), '.covers');
      await fs.mkdir(coverDir, { recursive: true });

      const baseName = path.basename(audioFilePath, path.extname(audioFilePath));
      const coverPath = path.join(coverDir, `${baseName}.cover.${config.images.format}`);
      const thumbnailPath = path.join(coverDir, `${baseName}.thumb.${config.images.format}`);

      // 生成封面
      await sharp(picture.data)
        .resize(config.images.coverMaxSize, config.images.coverMaxSize, {
          fit: 'inside',
          withoutEnlargement: true
        })
        .webp({ quality: config.images.quality })
        .toFile(coverPath);

      // 生成缩略图
      await sharp(picture.data)
        .resize(config.images.thumbnailSize, config.images.thumbnailSize, {
          fit: 'cover'
        })
        .webp({ quality: config.images.quality })
        .toFile(thumbnailPath);

      return {
        cover: coverPath,
        thumbnail: thumbnailPath
      };
    } catch (error) {
      console.error('Failed to extract cover:', error);
      return { cover: null, thumbnail: null };
    }
  }

  /**
   * 查找外部封面文件
   */
  async findExternalCover(directory) {
    const coverNames = ['cover', 'folder', 'front', 'album', 'artwork'];
    const extensions = ['.jpg', '.jpeg', '.png', '.webp'];

    for (const name of coverNames) {
      for (const ext of extensions) {
        const coverPath = path.join(directory, name + ext);
        try {
          await fs.access(coverPath);
          return coverPath;
        } catch {
          // 文件不存在，继续搜索
        }
      }
    }

    // 查找目录中的第一个图片文件
    try {
      const files = await fs.readdir(directory);
      for (const file of files) {
        const ext = path.extname(file).toLowerCase();
        if (extensions.includes(ext)) {
          return path.join(directory, file);
        }
      }
    } catch (error) {
      console.error('Error reading directory:', error);
    }

    return null;
  }

  /**
   * 处理外部封面图片
   */
  async processCoverImage(imagePath, audioFilePath) {
    try {
      const coverDir = path.join(path.dirname(audioFilePath), '.covers');
      await fs.mkdir(coverDir, { recursive: true });

      const baseName = path.basename(audioFilePath, path.extname(audioFilePath));
      const coverPath = path.join(coverDir, `${baseName}.cover.${config.images.format}`);
      const thumbnailPath = path.join(coverDir, `${baseName}.thumb.${config.images.format}`);

      // 生成封面
      await sharp(imagePath)
        .resize(config.images.coverMaxSize, config.images.coverMaxSize, {
          fit: 'inside',
          withoutEnlargement: true
        })
        .webp({ quality: config.images.quality })
        .toFile(coverPath);

      // 生成缩略图
      await sharp(imagePath)
        .resize(config.images.thumbnailSize, config.images.thumbnailSize, {
          fit: 'cover'
        })
        .webp({ quality: config.images.quality })
        .toFile(thumbnailPath);

      return {
        cover: coverPath,
        thumbnail: thumbnailPath
      };
    } catch (error) {
      console.error('Failed to process cover image:', error);
      return { cover: null, thumbnail: null };
    }
  }

  /**
   * 检查是否为支持的音频文件
   */
  isSupportedAudioFile(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    return this.supportedFormats.includes(ext);
  }

  /**
   * 获取相对路径
   */
  getRelativePath(filePath) {
    const rootPath = path.resolve(config.music.rootPath);
    const absPath = path.resolve(filePath);

    if (absPath.startsWith(rootPath)) {
      return absPath.substring(rootPath.length).replace(/\\/g, '/');
    }

    return filePath;
  }

  /**
   * 批量提取元数据
   */
  async extractMetadataBatch(filePaths, onProgress = null) {
    const results = [];
    const errors = [];

    for (let i = 0; i < filePaths.length; i++) {
      try {
        const metadata = await this.extractMetadata(filePaths[i]);
        results.push(metadata);

        if (onProgress) {
          onProgress({
            current: i + 1,
            total: filePaths.length,
            file: filePaths[i],
            success: true
          });
        }
      } catch (error) {
        errors.push({
          file: filePaths[i],
          error: error.message
        });

        if (onProgress) {
          onProgress({
            current: i + 1,
            total: filePaths.length,
            file: filePaths[i],
            success: false,
            error: error.message
          });
        }
      }
    }

    return { results, errors };
  }

  /**
   * 验证音频文件
   */
  async validateAudioFile(filePath) {
    try {
      // 检查文件是否存在
      await fs.access(filePath);

      // 检查文件扩展名
      if (!this.isSupportedAudioFile(filePath)) {
        return {
          valid: false,
          error: 'Unsupported file format'
        };
      }

      // 检查文件大小
      const stats = await fs.stat(filePath);
      if (stats.size === 0) {
        return {
          valid: false,
          error: 'File is empty'
        };
      }

      if (stats.size > config.music.maxFileSize) {
        return {
          valid: false,
          error: 'File is too large'
        };
      }

      // 尝试读取元数据
      try {
        await mm.parseFile(filePath, { duration: false, skipCovers: true });
      } catch (error) {
        return {
          valid: false,
          error: 'Invalid or corrupted audio file'
        };
      }

      return { valid: true };
    } catch (error) {
      return {
        valid: false,
        error: error.message
      };
    }
  }

  /**
   * 更新文件的元数据（写入文件）
   */
  async updateFileMetadata(filePath, metadata) {
    // 注意：这需要使用node-id3或类似的库来写入元数据
    // music-metadata只支持读取，不支持写入
    // 这里仅作为接口预留
    throw new Error('Writing metadata is not implemented yet');
  }
}

module.exports = new MetadataService();