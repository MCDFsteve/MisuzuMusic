// Core constants for the Misuzu Music application
class AppConstants {
  // App Information
  static const String appName = 'Misuzu Music';
  static const String version = '1.0.0';

  // Audio Formats
  static const List<String> supportedAudioFormats = [
    '.mp3',
    '.flac',
    '.aac',
    '.wav',
    '.ogg',
    '.m4a',
  ];

  // Database
  static const String dbName = 'misuzu_music.db';
  static const int dbVersion = 1;

  // Cache
  static const String artworkCacheDir = 'artwork_cache';
  static const String lyricsCacheDir = 'lyrics_cache';
  static const String neteaseApiBaseUrl = 'http://43.128.47.234:3000';
  static const String cloudPlaylistEndpoint =
      'https://nipaplay.aimes-soft.com/cloud_playlist.php';
  static const String remoteLyricsEndpoint =
      'https://nipaplay.aimes-soft.com/lyrics_service.php';


  // Settings Keys
  static const String settingsVolume = 'volume';
  static const String settingsMusicFolderPath = 'music_folder_path';
  static const String settingsShowLyricsAnnotation = 'show_lyrics_annotation';
  static const String settingsAnnotationFontSize = 'annotation_font_size';
  static const String settingsPlayMode = 'play_mode';
  static const String settingsPlaybackQueue = 'playback_queue';
  static const String settingsPlaybackIndex = 'playback_index';
  static const String settingsPlaybackPosition = 'playback_position_ms';
  static const String settingsPlaybackHistory = 'playback_history_v1';

  // Japanese Text Processing
  static const String mecabDictPath = 'assets/mecab_dict';
}

enum PlayMode {
  repeatAll,
  repeatOne,
  shuffle,
}

enum PlayerState {
  playing,
  paused,
  stopped,
  loading,
}

enum TextType {
  kanji,
  katakana,
  hiragana,
  other,
}

enum TrackSortMode {
  titleAZ,
  titleZA,
  addedNewest,
  addedOldest,
}

extension TrackSortModeExtension on TrackSortMode {
  String get displayName {
    switch (this) {
      case TrackSortMode.titleAZ:
        return '字母排序（A-Z）';
      case TrackSortMode.titleZA:
        return '字母排序（Z-A）';
      case TrackSortMode.addedNewest:
        return '添加时间（从新到旧）';
      case TrackSortMode.addedOldest:
        return '添加时间（从旧到新）';
    }
  }

  String toStorageString() {
    return name;
  }

  static TrackSortMode fromStorageString(String? value) {
    if (value == null) return TrackSortMode.titleAZ;
    return TrackSortMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => TrackSortMode.titleAZ,
    );
  }
}
