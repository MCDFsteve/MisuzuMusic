# Misuzu Music 技术设计文档

## 技术栈选择

### 核心框架
- **Flutter**: 跨平台UI框架，支持原生性能
- **Dart**: 主要开发语言

### 状态管理
- **Flutter BLoC**: 业务逻辑组件，实现状态管理
- **Equatable**: 简化状态比较

### 音频处理
- **just_audio**: Flutter音频播放库
- **audio_metadata_reader**: 音频元数据读取
- **audio_waveforms**: 音频波形显示

### 文件系统
- **path_provider**: 获取系统路径
- **file_picker**: 文件夹选择
- **permission_handler**: 权限管理

### 数据存储
- **sqflite**: SQLite数据库
- **shared_preferences**: 配置存储
- **hive**: 高性能缓存存储

### 日语处理
- **mecab_dart**: MeCab形态素解析器Dart绑定
- **kana_kit**: 假名转换工具
- **japanese**: 日语文本处理

### 平台特定UI
- **flutter_platform_widgets**: 平台自适应组件
- **macos_ui**: macOS风格UI组件
- **fluent_ui**: Windows Fluent Design组件

## 核心模块设计

### 1. 音频引擎模块

```dart
// 音频播放器抽象接口
abstract class AudioPlayer {
  Future<void> play(String filePath);
  Future<void> pause();
  Future<void> stop();
  Future<void> seekTo(Duration position);
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<PlayerState> get playerStateStream;
}

// 音频播放器实现
class JustAudioPlayerImpl implements AudioPlayer {
  final ju.AudioPlayer _player;
  // 实现接口方法...
}
```

### 2. 歌词处理模块

```dart
// 歌词解析器
class LyricsParser {
  List<LyricsLine> parseLrc(String lrcContent);
  List<LyricsLine> parseText(String textContent);
}

// 日语注音处理器
class JapaneseAnnotator {
  List<AnnotatedText> annotate(String text);
  String kanjiToHiragana(String kanji);
  String katakanaToHiragana(String katakana);
}

// 注音文本结构
class AnnotatedText {
  final String original;     // 原文
  final String annotation;   // 注音
  final TextType type;       // 文本类型（汉字/片假名/平假名/其他）
}
```

### 3. 音乐库管理模块

```dart
// 音乐库扫描器
class MusicLibraryScanner {
  Future<List<Track>> scanDirectory(String path);
  Future<void> watchDirectory(String path);
  Stream<LibraryChange> get libraryChangeStream;
}

// 元数据提取器
class MetadataExtractor {
  Future<TrackMetadata> extractMetadata(String filePath);
  Future<Uint8List?> extractArtwork(String filePath);
}

// 音乐库仓库
class MusicLibraryRepository {
  Future<List<Track>> getAllTracks();
  Future<List<Artist>> getAllArtists();
  Future<List<Album>> getAllAlbums();
  Future<List<Track>> searchTracks(String query);
}
```

### 4. 平台适配模块

```dart
// 平台UI工厂
abstract class PlatformUIFactory {
  Widget createButton({required String text, required VoidCallback onPressed});
  Widget createSlider({required double value, required ValueChanged<double> onChanged});
  Widget createNavigationBar({required List<PlatformNavItem> items});
}

// macOS UI工厂
class MacOSUIFactory implements PlatformUIFactory {
  @override
  Widget createButton({required String text, required VoidCallback onPressed}) {
    return MacosButton(
      text: text,
      onPressed: onPressed,
    );
  }
  // 其他方法实现...
}
```

## 数据模型设计

### 核心实体

```dart
// 音轨实体
class Track extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Duration duration;
  final DateTime? dateAdded;
  final String? artworkPath;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.duration,
    this.dateAdded,
    this.artworkPath,
  });

  @override
  List<Object?> get props => [id, title, artist, album, filePath, duration];
}

// 歌词行实体
class LyricsLine extends Equatable {
  final Duration timestamp;
  final String text;
  final List<AnnotatedText> annotatedText;

  const LyricsLine({
    required this.timestamp,
    required this.text,
    required this.annotatedText,
  });

  @override
  List<Object> get props => [timestamp, text, annotatedText];
}
```

### 状态模型

```dart
// 播放器状态
class PlayerState extends Equatable {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final PlayMode playMode;
  final double volume;

  const PlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playMode = PlayMode.sequence,
    this.volume = 1.0,
  });

  @override
  List<Object?> get props => [currentTrack, isPlaying, position, duration, playMode, volume];
}

// 歌词状态
class LyricsState extends Equatable {
  final List<LyricsLine> lyrics;
  final int? currentLineIndex;
  final bool showAnnotation;
  final double annotationFontSize;

  const LyricsState({
    this.lyrics = const [],
    this.currentLineIndex,
    this.showAnnotation = true,
    this.annotationFontSize = 14.0,
  });

  @override
  List<Object?> get props => [lyrics, currentLineIndex, showAnnotation, annotationFontSize];
}
```

## BLoC架构设计

### 播放器BLoC

```dart
// 播放器事件
abstract class PlayerEvent extends Equatable {}

class PlayTrack extends PlayerEvent {
  final Track track;
  PlayTrack(this.track);
  @override
  List<Object> get props => [track];
}

class PausePlayer extends PlayerEvent {
  @override
  List<Object> get props => [];
}

class SeekTo extends PlayerEvent {
  final Duration position;
  SeekTo(this.position);
  @override
  List<Object> get props => [position];
}

// 播放器BLoC
class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioPlayer _audioPlayer;
  final LyricsRepository _lyricsRepository;

  PlayerBloc({
    required AudioPlayer audioPlayer,
    required LyricsRepository lyricsRepository,
  }) : _audioPlayer = audioPlayer,
       _lyricsRepository = lyricsRepository,
       super(const PlayerState()) {

    on<PlayTrack>(_onPlayTrack);
    on<PausePlayer>(_onPausePlayer);
    on<SeekTo>(_onSeekTo);
  }

  Future<void> _onPlayTrack(PlayTrack event, Emitter<PlayerState> emit) async {
    await _audioPlayer.play(event.track.filePath);
    emit(state.copyWith(currentTrack: event.track, isPlaying: true));
  }
}
```

## 数据库设计

### SQLite表结构

```sql
-- 音轨表
CREATE TABLE tracks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT NOT NULL,
  file_path TEXT UNIQUE NOT NULL,
  duration_ms INTEGER NOT NULL,
  date_added INTEGER,
  artwork_path TEXT
);

-- 播放列表表
CREATE TABLE playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- 播放列表音轨关联表
CREATE TABLE playlist_tracks (
  playlist_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  PRIMARY KEY (playlist_id, track_id),
  FOREIGN KEY (playlist_id) REFERENCES playlists(id),
  FOREIGN KEY (track_id) REFERENCES tracks(id)
);

-- 歌词表
CREATE TABLE lyrics (
  track_id TEXT PRIMARY KEY,
  content TEXT NOT NULL,
  format TEXT NOT NULL, -- 'lrc' or 'text'
  FOREIGN KEY (track_id) REFERENCES tracks(id)
);
```

## 性能优化策略

### 1. 内存管理
- 使用对象池管理频繁创建的对象
- 及时释放不再使用的音频资源
- 实现封面图片的LRU缓存

### 2. 音频性能
- 预加载下一首歌曲的元数据
- 使用音频流进行渐进式加载
- 实现音频缓冲区优化

### 3. UI性能
- 使用虚拟列表处理大量歌曲
- 实现图片懒加载和缓存
- 优化歌词滚动动画

### 4. 日语处理优化
- 缓存常用汉字的注音结果
- 使用后台线程进行文本分析
- 实现增量歌词注音处理

## 测试策略

### 单元测试
- 业务逻辑层100%覆盖率
- 日语处理模块重点测试
- 音频播放核心功能测试

### 集成测试
- 播放器与UI的集成测试
- 数据库操作集成测试
- 文件系统操作集成测试

### 平台测试
- 各平台UI适配测试
- 音频格式兼容性测试
- 性能基准测试

## 部署和分发

### 构建配置
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.3
  just_audio: ^0.9.34
  sqflite: ^2.3.0
  # 其他依赖...

dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.2
  bloc_test: ^9.1.4
```

### 平台特定配置
- **macOS**: 沙盒配置、音频权限
- **Windows**: 音频编解码器、文件关联
- **Linux**: 音频系统集成、桌面文件