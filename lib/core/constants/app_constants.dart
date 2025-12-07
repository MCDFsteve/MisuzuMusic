import 'package:misuzu_music/l10n/app_localizations.dart';

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
  static const int dbVersion = 5;

  // Cache
  static const String artworkCacheDir = 'artwork_cache';
  static const String lyricsCacheDir = 'lyrics_cache';
  static const String neteaseApiBaseUrl = 'http://43.128.47.234:3000';
  static const String cloudPlaylistEndpoint =
      'https://nipaplay.aimes-soft.com/cloud_playlist.php';
  static const String remoteLyricsEndpoint =
      'https://nipaplay.aimes-soft.com/lyrics_service.php';
  static const String songDetailEndpoint =
      'https://nipaplay.aimes-soft.com/song_detail.php';
  static const String songIdMappingEndpoint =
      'https://nipaplay.aimes-soft.com/song_id_service.php';
  static const String iosICloudContainerId = 'iCloud.com.aimessoft.misuzumusic';

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

enum PlayMode { repeatAll, repeatOne, shuffle }

enum PlayerState { playing, paused, stopped, loading }

enum TextType { kanji, katakana, hiragana, other }

enum TrackSortMode {
  titleAZ,
  titleZA,
  addedNewest,
  addedOldest,
  artistAZ,
  artistZA,
  albumAZ,
  albumZA,
}

extension TrackSortModeExtension on TrackSortMode {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case TrackSortMode.titleAZ:
        return l10n.sortModeTitleAZ;
      case TrackSortMode.titleZA:
        return l10n.sortModeTitleZA;
      case TrackSortMode.addedNewest:
        return l10n.sortModeAddedNewest;
      case TrackSortMode.addedOldest:
        return l10n.sortModeAddedOldest;
      case TrackSortMode.artistAZ:
        return l10n.sortModeArtistAZ;
      case TrackSortMode.artistZA:
        return l10n.sortModeArtistZA;
      case TrackSortMode.albumAZ:
        return l10n.sortModeAlbumAZ;
      case TrackSortMode.albumZA:
        return l10n.sortModeAlbumZA;
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
