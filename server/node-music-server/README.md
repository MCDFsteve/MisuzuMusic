# Misuzu Music Server

🎵 A modern, feature-rich Node.js music streaming server with automatic file processing, metadata extraction, and a beautiful web interface.

## Features

✨ **Core Features**
- 🎼 **Automatic Music Library Scanning** - Monitors and indexes your music files automatically
- 🎵 **Streaming Support** - Full HTTP Range request support for smooth playback
- 🔍 **Full-Text Search** - Fast search across titles, artists, albums, and genres
- 🖼️ **Cover Art Management** - Automatic extraction and processing of album artwork
- 📊 **Rich Metadata** - Extracts comprehensive audio metadata using music-metadata
- 🎨 **Beautiful Web UI** - Modern, responsive web interface for browsing and playing music
- 🔄 **Real-time File Watching** - Automatically detects new, modified, or removed files
- 📱 **RESTful API** - Complete API for integration with Flutter and other clients

🎯 **Technical Features**
- SQLite database with full-text search (FTS5)
- WebP image processing for covers and thumbnails
- Concurrent file processing for fast scanning
- CORS and security headers configured
- Rate limiting and authentication support
- Graceful shutdown handling

## Installation

### Prerequisites

- Node.js 16+
- npm or yarn
- ffmpeg and ffprobe (optional, for enhanced metadata extraction)

### Install ffmpeg (Optional)

**macOS:**
```bash
brew install ffmpeg
```

**Ubuntu/Debian:**
```bash
sudo apt install ffmpeg
```

**Windows:**
Download from [ffmpeg.org](https://ffmpeg.org/download.html)

### Setup

1. **Navigate to the server directory:**
```bash
cd server/node-music-server
```

2. **Install dependencies:**
```bash
npm install
```

3. **Configure the server:**

Edit `config/config.js` to set your music library path:
```javascript
music: {
  rootPath: '/path/to/your/music/library',
  // ...
}
```

Or use environment variables (create a `.env` file):
```bash
MUSIC_ROOT=/path/to/your/music/library
PORT=3000
API_KEY=your-secret-key
```

4. **Start the server:**
```bash
# Production
npm start

# Development (with auto-reload)
npm run dev
```

The server will:
- Initialize the database
- Perform an initial scan of your music library
- Start the web server on http://localhost:3000
- Begin watching for file changes

## Usage

### Web Interface

Open your browser and navigate to:
```
http://localhost:3000
```

Features:
- Browse your music library
- Search for tracks, artists, or albums
- Play music directly in the browser
- View statistics
- Trigger manual library scans

### API Endpoints

#### Tracks
- `GET /api/tracks` - Get all tracks (with pagination)
- `GET /api/tracks/:id` - Get single track
- `GET /api/search?q=query` - Search tracks
- `POST /api/tracks/:id/play` - Record play

#### Library
- `GET /api/artists` - Get all artists
- `GET /api/albums` - Get all albums
- `GET /api/genres` - Get all genres
- `GET /api/stats` - Get library statistics

#### Scanning
- `POST /api/scan` - Trigger full library scan
- `GET /api/scan/status` - Get scan status

#### Streaming
- `GET /stream/:id` - Stream audio (supports Range requests)
- `GET /assets/cover/:id` - Get cover image
- `GET /assets/thumbnail/:id` - Get thumbnail

#### Health
- `GET /api/health` - Server health check

### Flutter Integration

Add the server URL to your Flutter app:

```dart
final baseUrl = 'http://localhost:3000';

// Fetch tracks
final response = await http.get('$baseUrl/api/tracks');
final tracks = Track.fromJsonList(json.decode(response.body)['data']['tracks']);

// Stream audio
final audioPlayer = AudioPlayer();
await audioPlayer.setUrl('$baseUrl/stream/${track.id}');
```

## Configuration

### Music Library Settings

```javascript
music: {
  rootPath: '/path/to/music',              // Music library root
  supportedFormats: ['.mp3', '.flac', ...], // Audio formats
  maxFileSize: 100 * 1024 * 1024            // Max file size (100MB)
}
```

### Scanner Settings

```javascript
scanner: {
  autoScanOnStart: true,    // Auto-scan on startup
  scanInterval: 300000,     // Scan interval (5 min)
  batchSize: 50,            // Files per batch
  concurrency: 5            // Concurrent processing
}
```

### Security Settings

```javascript
security: {
  apiKey: 'your-secret-key', // API key for authentication
  enableAuth: false,         // Enable/disable auth
  cors: {
    origin: '*',             // CORS origin
    credentials: true
  }
}
```

## File Structure

```
node-music-server/
├── app.js                  # Main application entry
├── package.json            # Dependencies
├── config/
│   └── config.js          # Configuration
├── src/
│   ├── middleware/        # Express middleware
│   ├── models/            # Data models
│   ├── routes/            # API routes
│   │   ├── api.js        # REST API
│   │   ├── stream.js     # Audio streaming
│   │   └── assets.js     # Images/covers
│   └── services/
│       ├── database.js    # SQLite operations
│       ├── metadata.js    # Metadata extraction
│       └── scanner.js     # File scanner
├── public/
│   └── index.html        # Web UI
└── data/
    └── music.db          # SQLite database (auto-created)
```

## Database Schema

### tracks
- Comprehensive track information
- File paths and metadata
- Play statistics
- Cover art paths

### play_history
- Playback history tracking
- Duration played
- Timestamps

### playlists (ready for implementation)
- Custom playlists
- Track associations

## Supported Audio Formats

- MP3
- FLAC
- WAV
- M4A / AAC
- OGG Vorbis
- Opus
- WavPack (.wv)
- APE

## Performance

- **Initial Scan**: ~500 files in 30-60 seconds (with metadata extraction)
- **Database Queries**: <10ms for most operations
- **Search**: Full-text search across 10,000+ tracks in <50ms
- **Streaming**: Efficient chunked transfer with Range support

## Troubleshooting

### Port Already in Use
```bash
# Change port in config.js or use environment variable
PORT=3001 npm start
```

### Permission Errors
```bash
# Ensure music directory is readable
chmod -R 755 /path/to/music
```

### Database Locked
```bash
# Stop all server instances
# Delete data/music.db
# Restart server
```

### Missing Covers
- Ensure ffmpeg is installed
- Check that audio files contain embedded artwork
- Place cover.jpg/folder.jpg in album directories

## Development

### Running in Development Mode
```bash
npm run dev
```

### Running Tests (coming soon)
```bash
npm test
```

### Building for Production
```bash
npm start
```

Use PM2 for production deployment:
```bash
npm install -g pm2
pm2 start app.js --name misuzu-music
pm2 save
pm2 startup
```

## API Authentication

Enable authentication in `config/config.js`:

```javascript
security: {
  enableAuth: true,
  apiKey: 'your-secret-key'
}
```

Include API key in requests:
```bash
curl -H "X-API-Key: your-secret-key" http://localhost:3000/api/tracks
```

Or via query parameter:
```
http://localhost:3000/api/tracks?apiKey=your-secret-key
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - feel free to use this in your projects!

## Credits

Built with:
- Express.js - Web framework
- better-sqlite3 - SQLite database
- music-metadata - Metadata extraction
- chokidar - File watching
- sharp - Image processing

---

Made with ❤️ for Misuzu Music