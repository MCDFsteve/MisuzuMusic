const express = require('express');
const router = express.Router();
const { dbService, scannerService, metadataService } = require('../services');

/**
 * GET /api/tracks
 * 获取所有曲目
 */
router.get('/tracks', async (req, res) => {
  try {
    const { limit, offset, orderBy, orderDir, search } = req.query;

    let tracks;

    if (search) {
      // 搜索曲目
      tracks = await dbService.searchTracks(search, {
        limit: parseInt(limit) || 100,
        offset: parseInt(offset) || 0
      });
    } else {
      // 获取所有曲目
      tracks = await dbService.getAllTracks({
        limit: parseInt(limit) || 1000,
        offset: parseInt(offset) || 0,
        orderBy: orderBy || 'date_added',
        orderDir: orderDir || 'DESC'
      });
    }

    const total = await dbService.getTracksCount();

    res.json({
      success: true,
      data: {
        tracks: tracks.map(t => t.toApiResponse()),
        total,
        limit: parseInt(limit) || 1000,
        offset: parseInt(offset) || 0
      }
    });
  } catch (error) {
    console.error('Get tracks error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get tracks',
      error: error.message
    });
  }
});

/**
 * GET /api/tracks/:id
 * 获取单个曲目
 */
router.get('/tracks/:id', async (req, res) => {
  try {
    const track = await dbService.getTrackById(req.params.id);

    if (!track) {
      return res.status(404).json({
        success: false,
        message: 'Track not found'
      });
    }

    res.json({
      success: true,
      data: track.toApiResponse()
    });
  } catch (error) {
    console.error('Get track error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get track',
      error: error.message
    });
  }
});

/**
 * POST /api/tracks/:id/play
 * 记录播放
 */
router.post('/tracks/:id/play', async (req, res) => {
  try {
    const { durationPlayed } = req.body;
    await dbService.recordPlay(req.params.id, durationPlayed);

    res.json({
      success: true,
      message: 'Play recorded'
    });
  } catch (error) {
    console.error('Record play error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to record play',
      error: error.message
    });
  }
});

/**
 * GET /api/artists
 * 获取所有艺术家
 */
router.get('/artists', async (req, res) => {
  try {
    const artists = await dbService.getArtists();

    res.json({
      success: true,
      data: artists
    });
  } catch (error) {
    console.error('Get artists error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get artists',
      error: error.message
    });
  }
});

/**
 * GET /api/albums
 * 获取所有专辑
 */
router.get('/albums', async (req, res) => {
  try {
    const albums = await dbService.getAlbums();

    res.json({
      success: true,
      data: albums
    });
  } catch (error) {
    console.error('Get albums error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get albums',
      error: error.message
    });
  }
});

/**
 * GET /api/genres
 * 获取所有流派
 */
router.get('/genres', async (req, res) => {
  try {
    const genres = await dbService.getGenres();

    res.json({
      success: true,
      data: genres
    });
  } catch (error) {
    console.error('Get genres error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get genres',
      error: error.message
    });
  }
});

/**
 * GET /api/stats
 * 获取统计信息
 */
router.get('/stats', async (req, res) => {
  try {
    const tracksCount = await dbService.getTracksCount();
    const artists = await dbService.getArtists();
    const albums = await dbService.getAlbums();
    const genres = await dbService.getGenres();
    const scannerStats = scannerService.getStats();

    res.json({
      success: true,
      data: {
        tracks: tracksCount,
        artists: artists.length,
        albums: albums.length,
        genres: genres.length,
        scanner: scannerStats
      }
    });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get stats',
      error: error.message
    });
  }
});

/**
 * POST /api/scan
 * 触发全量扫描
 */
router.post('/scan', async (req, res) => {
  try {
    if (scannerService.isScanning) {
      return res.status(409).json({
        success: false,
        message: 'Scan already in progress'
      });
    }

    // 异步执行扫描
    scannerService.performFullScan().catch(error => {
      console.error('Scan error:', error);
    });

    res.json({
      success: true,
      message: 'Scan started'
    });
  } catch (error) {
    console.error('Start scan error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to start scan',
      error: error.message
    });
  }
});

/**
 * GET /api/scan/status
 * 获取扫描状态
 */
router.get('/scan/status', (req, res) => {
  try {
    const stats = scannerService.getStats();

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Get scan status error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get scan status',
      error: error.message
    });
  }
});

/**
 * GET /api/search
 * 搜索曲目
 */
router.get('/search', async (req, res) => {
  try {
    const { q, limit, offset } = req.query;

    if (!q || q.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Search query is required'
      });
    }

    const tracks = await dbService.searchTracks(q, {
      limit: parseInt(limit) || 100,
      offset: parseInt(offset) || 0
    });

    res.json({
      success: true,
      data: {
        tracks: tracks.map(t => t.toApiResponse()),
        query: q,
        count: tracks.length
      }
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({
      success: false,
      message: 'Search failed',
      error: error.message
    });
  }
});

/**
 * GET /api/health
 * 健康检查
 */
router.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

module.exports = router;