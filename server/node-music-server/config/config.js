const path = require('path');

const config = {
  // 服务器配置
  server: {
    port: process.env.PORT || 3301,
    host: process.env.HOST || '0.0.0.0'  // 监听所有网络接口
  },

  // 音乐库配置
  music: {
    // 音乐文件根目录
    rootPath: process.env.MUSIC_ROOT || '/root/data/disk1/music',
    // 支持的音频格式
    supportedFormats: ['.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.opus', '.wv', '.ape'],
    // 封面图片格式
    coverFormats: ['.jpg', '.jpeg', '.png', '.webp', '.bmp'],
    // 最大文件大小 (100MB)
    maxFileSize: 100 * 1024 * 1024
  },

  // 数据库配置
  database: {
    path: process.env.DB_PATH || path.join(__dirname, '..', 'data', 'music.db'),
    // SQLite配置
    options: {
      verbose: process.env.NODE_ENV === 'development' ? console.log : undefined,
      fileMustExist: false
    }
  },

  // 扫描配置
  scanner: {
    // 是否在启动时自动扫描
    autoScanOnStart: true,
    // 扫描间隔（毫秒）
    scanInterval: 5 * 60 * 1000, // 5分钟
    // 批处理大小
    batchSize: 50,
    // 并发处理数
    concurrency: 5
  },

  // 流式传输配置
  streaming: {
    // 缓冲区大小
    bufferSize: 64 * 1024, // 64KB
    // 是否启用范围请求
    enableRangeRequests: true,
    // 缓存控制
    cacheControl: 'public, max-age=3600'
  },

  // 安全配置
  security: {
    // API密钥
    apiKey: process.env.API_KEY || 'misuzu-music-key',
    // 是否启用认证
    enableAuth: process.env.ENABLE_AUTH === 'true',
    // CORS配置
    cors: {
      origin: process.env.CORS_ORIGIN || '*',
      credentials: true
    }
  },

  // 图片处理配置
  images: {
    // 封面图片最大尺寸
    coverMaxSize: 1024,
    // 缩略图尺寸
    thumbnailSize: 256,
    // 图片质量
    quality: 85,
    // 输出格式
    format: 'webp'
  },

  // 日志配置
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    format: process.env.NODE_ENV === 'production' ? 'combined' : 'dev'
  }
};

module.exports = config;