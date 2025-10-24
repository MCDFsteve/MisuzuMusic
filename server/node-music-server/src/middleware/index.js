const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const config = require('../../config/config');

// 认证中间件
const authMiddleware = (req, res, next) => {
  if (!config.security.enableAuth) {
    return next();
  }

  const apiKey = req.headers['x-api-key'] || req.query.apiKey;

  if (!apiKey || apiKey !== config.security.apiKey) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized: Invalid or missing API key'
    });
  }

  next();
};

// 速率限制中间件
const rateLimitMiddleware = (req, res, next) => {
  // 简单的内存速率限制（生产环境建议使用Redis）
  const ip = req.ip;
  const now = Date.now();
  const windowMs = 15 * 60 * 1000; // 15分钟
  const maxRequests = 1000; // 最大请求数

  if (!rateLimitMiddleware.requests) {
    rateLimitMiddleware.requests = new Map();
  }

  const requests = rateLimitMiddleware.requests;
  const userRequests = requests.get(ip) || [];

  // 清理过期请求
  const validRequests = userRequests.filter(time => now - time < windowMs);

  if (validRequests.length >= maxRequests) {
    return res.status(429).json({
      success: false,
      message: 'Too many requests, please try again later'
    });
  }

  validRequests.push(now);
  requests.set(ip, validRequests);

  // 定期清理过期数据
  if (Math.random() < 0.01) { // 1%的概率清理
    const cutoff = now - windowMs;
    for (const [key, times] of requests.entries()) {
      const valid = times.filter(time => time > cutoff);
      if (valid.length === 0) {
        requests.delete(key);
      } else {
        requests.set(key, valid);
      }
    }
  }

  next();
};

// 错误处理中间件
const errorMiddleware = (error, req, res, next) => {
  console.error('Error:', error);

  // 文件不存在错误
  if (error.code === 'ENOENT') {
    return res.status(404).json({
      success: false,
      message: 'File not found'
    });
  }

  // 权限错误
  if (error.code === 'EACCES') {
    return res.status(403).json({
      success: false,
      message: 'Access denied'
    });
  }

  // 默认服务器错误
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? error.message : undefined
  });
};

// 请求日志中间件
const requestLogMiddleware = morgan(config.logging.format, {
  skip: (req, res) => {
    // 跳过静态文件和流请求的日志
    return req.url.startsWith('/stream/') || req.url.startsWith('/assets/');
  }
});

// 安全头中间件
const securityMiddleware = helmet({
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      mediaSrc: ["'self'", "blob:"],
      connectSrc: ["'self'"]
    }
  }
});

// CORS中间件
const corsMiddleware = cors({
  origin: config.security.cors.origin,
  credentials: config.security.cors.credentials,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key']
});

// 设置所有中间件
const setupMiddleware = (app) => {
  // 基础中间件
  app.use(compression());
  app.use(corsMiddleware);
  app.use(securityMiddleware);
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // 日志中间件
  app.use(requestLogMiddleware);

  // 自定义中间件
  app.use(rateLimitMiddleware);

  // API路由需要认证
  app.use('/api', authMiddleware);

  // 信任代理（如果在反向代理后面）
  app.set('trust proxy', 1);
};

module.exports = {
  setupMiddleware,
  authMiddleware,
  rateLimitMiddleware,
  errorMiddleware,
  requestLogMiddleware,
  securityMiddleware,
  corsMiddleware
};