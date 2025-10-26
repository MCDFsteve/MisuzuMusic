const chokidar = require('chokidar');
const path = require('path');
const fs = require('fs').promises;
const config = require('../../config/config');
const metadataService = require('./metadata');
const dbService = require('./database');

class ScannerService {
  constructor() {
    this.watcher = null;
    this.isScanning = false;
    this.scanQueue = [];
    this.processingQueue = false;
    this.stats = {
      filesScanned: 0,
      filesAdded: 0,
      filesUpdated: 0,
      filesRemoved: 0,
      errors: []
    };
  }

  async init() {
    console.log(`🔍 Initializing scanner for: ${config.music.rootPath}`);

    // 确保音乐目录存在
    try {
      await fs.access(config.music.rootPath);
    } catch (error) {
      console.warn(`⚠️  Music directory does not exist, creating: ${config.music.rootPath}`);
      await fs.mkdir(config.music.rootPath, { recursive: true });
    }

    // 执行初始扫描
    if (config.scanner.autoScanOnStart) {
      await this.performFullScan();
    }

    // 启动文件监控
    this.startWatching();
  }

  /**
   * 执行完整扫描
   */
  async performFullScan() {
    if (this.isScanning) {
      console.log('⏳ Scan already in progress');
      return;
    }

    this.isScanning = true;
    this.resetStats();

    console.log('🔍 Starting full music library scan...');
    const startTime = Date.now();
    const scanId = await dbService.createScanRecord();

    try {
      // 获取所有音频文件
      const audioFiles = await this.findAudioFiles(config.music.rootPath);
      console.log(`📁 Found ${audioFiles.length} audio files`);

      // 获取数据库中已有的文件路径
      const existingTracks = await dbService.getAllTracks();
      const existingPaths = new Set(existingTracks.map(t => t.filePath));

      // 处理文件
      await this.processFileBatch(audioFiles);

      // 删除不存在的文件记录
      const currentPaths = new Set(audioFiles);
      for (const track of existingTracks) {
        if (!currentPaths.has(track.filePath)) {
          await dbService.deleteTrack(track.id);
          this.stats.filesRemoved++;
          console.log(`🗑️  Removed: ${track.relativePath}`);
        }
      }

      const duration = (Date.now() - startTime) / 1000;
      console.log(`
✅ Scan completed in ${duration.toFixed(2)}s
📊 Statistics:
   - Files scanned: ${this.stats.filesScanned}
   - Files added: ${this.stats.filesAdded}
   - Files updated: ${this.stats.filesUpdated}
   - Files removed: ${this.stats.filesRemoved}
   - Errors: ${this.stats.errors.length}
      `);

      // 更新扫描记录
      await dbService.updateScanRecord(scanId, {
        completed_at: new Date().toISOString(),
        files_scanned: this.stats.filesScanned,
        files_added: this.stats.filesAdded,
        files_updated: this.stats.filesUpdated,
        files_removed: this.stats.filesRemoved,
        errors: this.stats.errors,
        status: 'completed'
      });
    } catch (error) {
      console.error('❌ Scan failed:', error);
      await dbService.updateScanRecord(scanId, {
        status: 'failed',
        errors: [{ message: error.message, stack: error.stack }]
      });
      throw error;
    } finally {
      this.isScanning = false;
    }
  }

  /**
   * 递归查找音频文件
   */
  async findAudioFiles(directory, files = []) {
    try {
      const entries = await fs.readdir(directory, { withFileTypes: true });

      for (const entry of entries) {
        const fullPath = path.join(directory, entry.name);

        // 跳过隐藏文件和目录
        if (entry.name.startsWith('.')) {
          continue;
        }

        if (entry.isDirectory()) {
          await this.findAudioFiles(fullPath, files);
        } else if (entry.isFile() && metadataService.isSupportedAudioFile(fullPath)) {
          files.push(fullPath);
        }
      }
    } catch (error) {
      console.error(`Error reading directory ${directory}:`, error);
      this.stats.errors.push({ directory, error: error.message });
    }

    return files;
  }

  /**
   * 批量处理文件
   */
  async processFileBatch(files) {
    const batchSize = config.scanner.batchSize;

    for (let i = 0; i < files.length; i += batchSize) {
      const batch = files.slice(i, i + batchSize);
      await Promise.all(batch.map(file => this.processFile(file)));

      const progress = ((i + batch.length) / files.length * 100).toFixed(1);
      console.log(`📊 Progress: ${progress}% (${i + batch.length}/${files.length})`);
    }
  }

  /**
   * 处理单个文件
   */
  async processFile(filePath) {
    try {
      this.stats.filesScanned++;

      // 检查文件是否已在数据库中
      const existingTrack = await dbService.getTrackByPath(filePath);

      // 获取文件修改时间
      const stats = await fs.stat(filePath);
      const mtime = stats.mtime.toISOString();

      // 如果文件已存在且未修改，跳过
      if (existingTrack && existingTrack.lastModified === mtime) {
        return;
      }

      // 提取元数据
      const metadata = await metadataService.extractMetadata(filePath);

      if (existingTrack) {
        // 更新现有记录
        await dbService.updateTrack(existingTrack.id, metadata);
        this.stats.filesUpdated++;
        console.log(`🔄 Updated: ${metadata.relativePath}`);
      } else {
        // 创建新记录
        await dbService.createTrack(metadata);
        this.stats.filesAdded++;
        console.log(`✨ Added: ${metadata.relativePath}`);
      }
    } catch (error) {
      console.error(`❌ Failed to process ${filePath}:`, error.message);
      this.stats.errors.push({ file: filePath, error: error.message });
    }
  }

  /**
   * 启动文件监控
   */
  startWatching() {
    if (this.watcher) {
      console.log('👀 Watcher already running');
      return;
    }

    console.log('👀 Starting file watcher...');

    this.watcher = chokidar.watch(config.music.rootPath, {
      ignored: /(^|[\/\\])\../, // 忽略隐藏文件
      persistent: true,
      ignoreInitial: true, // 不触发初始文件的add事件
      awaitWriteFinish: {
        stabilityThreshold: 2000,
        pollInterval: 100
      }
    });

    this.watcher
      .on('add', path => this.onFileAdded(path))
      .on('change', path => this.onFileChanged(path))
      .on('unlink', path => this.onFileDeleted(path))
      .on('error', error => console.error('Watcher error:', error));

    console.log('✅ File watcher started');
  }

  /**
   * 文件添加事件
   */
  async onFileAdded(filePath) {
    if (!metadataService.isSupportedAudioFile(filePath)) {
      return;
    }

    console.log(`📂 New file detected: ${filePath}`);
    this.addToQueue(filePath);
  }

  /**
   * 文件修改事件
   */
  async onFileChanged(filePath) {
    if (!metadataService.isSupportedAudioFile(filePath)) {
      return;
    }

    console.log(`📝 File changed: ${filePath}`);
    this.addToQueue(filePath);
  }

  /**
   * 文件删除事件
   */
  async onFileDeleted(filePath) {
    if (!metadataService.isSupportedAudioFile(filePath)) {
      return;
    }

    console.log(`🗑️  File deleted: ${filePath}`);

    try {
      const deleted = await dbService.deleteTrackByPath(filePath);
      if (deleted) {
        console.log(`✅ Removed from database: ${filePath}`);
      }
    } catch (error) {
      console.error(`Failed to remove from database: ${filePath}`, error);
    }
  }

  /**
   * 添加到处理队列
   */
  addToQueue(filePath) {
    if (!this.scanQueue.includes(filePath)) {
      this.scanQueue.push(filePath);
      this.processQueueDebounced();
    }
  }

  /**
   * 处理队列（防抖）
   */
  processQueueDebounced() {
    if (this.queueTimeout) {
      clearTimeout(this.queueTimeout);
    }

    this.queueTimeout = setTimeout(() => {
      this.processQueue();
    }, 1000);
  }

  /**
   * 处理队列
   */
  async processQueue() {
    if (this.processingQueue || this.scanQueue.length === 0) {
      return;
    }

    this.processingQueue = true;
    const files = [...this.scanQueue];
    this.scanQueue = [];

    console.log(`🔄 Processing ${files.length} queued files...`);

    for (const file of files) {
      try {
        await this.processFile(file);
      } catch (error) {
        console.error(`Failed to process queued file ${file}:`, error);
      }
    }

    this.processingQueue = false;
  }

  /**
   * 停止文件监控
   */
  async stop() {
    if (this.watcher) {
      console.log('🛑 Stopping file watcher...');
      await this.watcher.close();
      this.watcher = null;
      console.log('✅ File watcher stopped');
    }
  }

  /**
   * 重置统计数据
   */
  resetStats() {
    this.stats = {
      filesScanned: 0,
      filesAdded: 0,
      filesUpdated: 0,
      filesRemoved: 0,
      errors: []
    };
  }

  /**
   * 获取统计数据
   */
  getStats() {
    return {
      ...this.stats,
      isScanning: this.isScanning,
      queueLength: this.scanQueue.length
    };
  }
}

module.exports = new ScannerService();