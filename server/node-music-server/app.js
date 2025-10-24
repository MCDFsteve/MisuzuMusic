const express = require('express');
const path = require('path');
const config = require('./config/config');
const { setupMiddleware } = require('./src/middleware');
const routes = require('./src/routes');
const { dbService, scannerService } = require('./src/services');

class MisuzuMusicServer {
  constructor() {
    this.app = express();
    this.init();
  }

  async init() {
    try {
      console.log('🎵 Initializing Misuzu Music Server...');

      // 设置中间件
      this.setupMiddleware();

      // 设置路由
      this.setupRoutes();

      // 初始化数据库
      await this.initDatabase();

      // 启动文件扫描服务
      await this.initScanner();

      // 启动服务器
      this.start();
    } catch (error) {
      console.error('❌ Failed to initialize server:', error);
      process.exit(1);
    }
  }

  setupMiddleware() {
    setupMiddleware(this.app);
  }

  setupRoutes() {
    // 静态文件服务
    this.app.use(express.static(path.join(__dirname, 'public')));

    // API路由
    this.app.use('/api', routes.api);
    this.app.use('/stream', routes.stream);
    this.app.use('/assets', routes.assets);

    // 根路径重定向到首页
    this.app.get('/', (req, res) => {
      res.sendFile(path.join(__dirname, 'public', 'index.html'));
    });

    // 404处理
    this.app.use('*', (req, res) => {
      res.status(404).json({
        success: false,
        message: 'Route not found',
        path: req.originalUrl
      });
    });

    // 错误处理
    this.app.use((error, req, res, next) => {
      console.error('Server Error:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    });
  }

  async initDatabase() {
    console.log('📊 Initializing database...');
    await dbService.init();
    console.log('✅ Database initialized');
  }

  async initScanner() {
    if (config.scanner.autoScanOnStart) {
      console.log('🔍 Starting music scanner...');
      await scannerService.init();
      console.log('✅ Music scanner started');
    }
  }

  start() {
    const { port, host } = config.server;

    this.server = this.app.listen(port, host, () => {
      console.log(`
🎵 Misuzu Music Server is running!

📡 Server: http://${host}:${port}
🎼 Music Library: ${config.music.rootPath}
📊 Database: ${config.database.path}
🔍 Auto Scan: ${config.scanner.autoScanOnStart ? 'Enabled' : 'Disabled'}

Ready to rock! 🚀
      `);
    });

    // 优雅关闭
    this.setupGracefulShutdown();
  }

  setupGracefulShutdown() {
    const shutdown = async (signal) => {
      console.log(`\n🛑 Received ${signal}, shutting down gracefully...`);

      // 停止接受新连接
      this.server.close(async () => {
        console.log('📡 HTTP server closed');

        try {
          // 停止扫描服务
          await scannerService.stop();
          console.log('🔍 Scanner stopped');

          // 关闭数据库连接
          await dbService.close();
          console.log('📊 Database closed');

          console.log('✅ Server shutdown complete');
          process.exit(0);
        } catch (error) {
          console.error('❌ Error during shutdown:', error);
          process.exit(1);
        }
      });

      // 强制退出超时
      setTimeout(() => {
        console.error('⏰ Shutdown timeout, forcing exit...');
        process.exit(1);
      }, 10000);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  }
}

// 启动服务器
if (require.main === module) {
  new MisuzuMusicServer();
}

module.exports = MisuzuMusicServer;