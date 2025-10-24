const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const mime = require('mime-types');
const { dbService } = require('../services');

/**
 * GET /assets/cover/:id
 * 获取封面图片
 */
router.get('/cover/:id', async (req, res) => {
  try {
    const track = await dbService.getTrackById(req.params.id);

    if (!track || !track.coverPath) {
      return res.status(404).json({
        success: false,
        message: 'Cover not found'
      });
    }

    const coverPath = track.coverPath;

    // 检查文件是否存在
    if (!fs.existsSync(coverPath)) {
      return res.status(404).json({
        success: false,
        message: 'Cover file not found on disk'
      });
    }

    const stat = fs.statSync(coverPath);
    const mimeType = mime.lookup(coverPath) || 'image/webp';

    res.status(200).set({
      'Content-Length': stat.size,
      'Content-Type': mimeType,
      'Cache-Control': 'public, max-age=31536000' // 1年缓存
    });

    const stream = fs.createReadStream(coverPath);
    stream.on('error', (error) => {
      console.error('Cover stream error:', error);
      if (!res.headersSent) {
        res.status(500).end();
      }
    });

    stream.pipe(res);
  } catch (error) {
    console.error('Cover error:', error);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Failed to serve cover',
        error: error.message
      });
    }
  }
});

/**
 * GET /assets/thumbnail/:id
 * 获取缩略图
 */
router.get('/thumbnail/:id', async (req, res) => {
  try {
    const track = await dbService.getTrackById(req.params.id);

    if (!track || !track.thumbnailPath) {
      return res.status(404).json({
        success: false,
        message: 'Thumbnail not found'
      });
    }

    const thumbnailPath = track.thumbnailPath;

    // 检查文件是否存在
    if (!fs.existsSync(thumbnailPath)) {
      return res.status(404).json({
        success: false,
        message: 'Thumbnail file not found on disk'
      });
    }

    const stat = fs.statSync(thumbnailPath);
    const mimeType = mime.lookup(thumbnailPath) || 'image/webp';

    res.status(200).set({
      'Content-Length': stat.size,
      'Content-Type': mimeType,
      'Cache-Control': 'public, max-age=31536000' // 1年缓存
    });

    const stream = fs.createReadStream(thumbnailPath);
    stream.on('error', (error) => {
      console.error('Thumbnail stream error:', error);
      if (!res.headersSent) {
        res.status(500).end();
      }
    });

    stream.pipe(res);
  } catch (error) {
    console.error('Thumbnail error:', error);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: 'Failed to serve thumbnail',
        error: error.message
      });
    }
  }
});

/**
 * GET /assets/cover/path
 * 直接通过路径获取封面（用于外部封面文件）
 */
router.get('/cover/path', async (req, res) => {
  try {
    const { path: coverPath } = req.query;

    if (!coverPath) {
      return res.status(400).json({
        success: false,
        message: 'Path parameter is required'
      });
    }

    // 安全检查：防止目录遍历攻击
    const resolvedPath = path.resolve(coverPath);
    if (!fs.existsSync(resolvedPath)) {
      return res.status(404).json({
        success: false,
        message: 'File not found'
      });
    }

    const stat = fs.statSync(resolvedPath);
    const mimeType = mime.lookup(resolvedPath) || 'image/jpeg';

    res.status(200).set({
      'Content-Length': stat.size,
      'Content-Type': mimeType,
      'Cache-Control': 'public, max-age=31536000'
    });

    const stream = fs.createReadStream(resolvedPath);
    stream.pipe(res);
  } catch (error) {
    console.error('Cover path error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to serve cover',
      error: error.message
    });
  }
});

module.exports = router;