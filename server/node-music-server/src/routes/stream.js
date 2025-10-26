const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const mime = require('mime-types');
const { dbService } = require('../services');
const config = require('../../config/config');

/**
 * GET /stream/:id
 * 流式传输音频文件
 * 支持 Range 请求（断点续传）
 */
router.get('/:id', async (req, res) => {
  try {
    const track = await dbService.getTrackById(req.params.id);

    if (!track) {
      return res.status(404).json({
        success: false,
        message: 'Track not found'
      });
    }

    const audioPath = track.filePath;

    // 检查文件是否存在
    if (!fs.existsSync(audioPath)) {
      return res.status(404).json({
        success: false,
        message: 'Audio file not found on disk'
      });
    }

    const stat = fs.statSync(audioPath);
    const fileSize = stat.size;
    const mimeType = mime.lookup(audioPath) || 'audio/mpeg';

    // 处理 Range 请求
    const range = req.headers.range;

    if (range) {
      // 解析 Range 头
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
      const chunkSize = (end - start) + 1;

      // 验证范围
      if (start >= fileSize || end >= fileSize) {
        res.status(416).set({
          'Content-Range': `bytes */${fileSize}`
        });
        return res.end();
      }

      // 设置响应头
      res.status(206).set({
        'Content-Range': `bytes ${start}-${end}/${fileSize}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunkSize,
        'Content-Type': mimeType,
        'Cache-Control': config.streaming.cacheControl
      });

      // 创建文件流并传输
      const stream = fs.createReadStream(audioPath, { start, end });
      stream.on('error', (error) => {
        console.error('Stream error:', error);
        if (!res.headersSent) {
          res.status(500).end();
        }
      });

      stream.pipe(res);
    } else {
      // 完整文件传输
      res.status(200).set({
        'Content-Length': fileSize,
        'Content-Type': mimeType,
        'Accept-Ranges': 'bytes',
        'Cache-Control': config.streaming.cacheControl
      });

      const stream = fs.createReadStream(audioPath);
      stream.on('error', (error) => {
        console.error('Stream error:', error);
        if (!res.headersSent) {
          res.status(500).end();
        }
      });

      stream.pipe(res);
    }
  } catch (error) {
    console.error('Stream error:', error);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Failed to stream audio',
        error: error.message
      });
    }
  }
});

/**
 * HEAD /stream/:id
 * 获取音频文件头信息（用于预检）
 */
router.head('/:id', async (req, res) => {
  try {
    const track = await dbService.getTrackById(req.params.id);

    if (!track) {
      return res.status(404).end();
    }

    const audioPath = track.filePath;

    if (!fs.existsSync(audioPath)) {
      return res.status(404).end();
    }

    const stat = fs.statSync(audioPath);
    const mimeType = mime.lookup(audioPath) || 'audio/mpeg';

    res.status(200).set({
      'Content-Length': stat.size,
      'Content-Type': mimeType,
      'Accept-Ranges': 'bytes',
      'Cache-Control': config.streaming.cacheControl
    });

    res.end();
  } catch (error) {
    console.error('Head request error:', error);
    res.status(500).end();
  }
});

module.exports = router;