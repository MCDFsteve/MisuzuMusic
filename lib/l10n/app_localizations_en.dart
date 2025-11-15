// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get settingsAppearanceSubtitle =>
      'Customize the app\'s look and theme';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutSubtitle =>
      'See the project name, version, and repository link';

  @override
  String get settingsDeveloperTitle => 'Developer Options';

  @override
  String get settingsDeveloperSubtitle => 'Access debugging tools';

  @override
  String get settingsUnknownVersion => 'Unknown version';

  @override
  String get settingsProjectNameLabel => 'App Name';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsRepositoryLabel => 'GitHub Repository';

  @override
  String get settingsDeveloperTerminalTitle => 'Terminal Output';

  @override
  String get settingsDeveloperTerminalSubtitle =>
      'View real-time print and debugPrint logs';

  @override
  String get settingsDeveloperLogExplanation =>
      'Shows every print/debugPrint since launch. Quickly search or filter.';

  @override
  String get settingsDeveloperClearSearch => 'Clear search';

  @override
  String get settingsDeveloperSearchHint =>
      'Search log content or timestamps...';

  @override
  String get settingsDeveloperEmptyLogs => 'No output is available yet.';

  @override
  String get settingsDeveloperNoFilterResult =>
      'No logs match the current filters.';

  @override
  String get settingsDeveloperLogFilterAll => 'All';

  @override
  String get settingsDeveloperLogFilterInfo => 'Only info logs';

  @override
  String get settingsDeveloperLogFilterError => 'Only errors';

  @override
  String settingsDeveloperLogCount(int total, int filtered) {
    return 'Total $total entries, $filtered after filters.';
  }

  @override
  String get settingsThemeModeLabel => 'Theme mode';

  @override
  String get settingsThemeModeLight => 'Light';

  @override
  String get settingsThemeModeDark => 'Dark';

  @override
  String get settingsThemeModeSystem => 'System';

  @override
  String get settingsLanguageLabel => 'App language';

  @override
  String get settingsLanguageDescription => 'Change the interface language';

  @override
  String get settingsLanguageSystem => 'Follow system';

  @override
  String get settingsLanguageChinese => 'Simplified Chinese';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String settingsAboutProjectLine(Object name) {
    return 'Project name: $name';
  }

  @override
  String settingsAboutVersionLine(Object version) {
    return 'Version: $version';
  }

  @override
  String settingsAboutRepositoryLine(Object url) {
    return 'GitHub: $url';
  }

  @override
  String settingsRepositoryOpenFailed(Object url) {
    return 'Unable to open $url';
  }

  @override
  String get actionClear => 'Clear';

  @override
  String get actionClose => 'Close';

  @override
  String get navLibrary => 'Library';

  @override
  String get navPlaylists => 'Song Lists';

  @override
  String get navOnlineTracks => 'Online Tracks';

  @override
  String get navQueue => 'Queue';

  @override
  String get navSettings => 'Settings';

  @override
  String get glassHeaderBackTooltip => 'Go back';

  @override
  String get glassHeaderLogoutTooltip => 'Sign out';

  @override
  String get glassHeaderSortTooltip => 'Change sort order';

  @override
  String get glassHeaderCreatePlaylistTooltip => 'Create playlist';

  @override
  String get glassHeaderSelectFolderTooltip => 'Pick music folder';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowClose => 'Close';

  @override
  String get glassHeaderSortTitle => 'Choose sort order';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get homeBackTooltipDefault => 'Go back';

  @override
  String get homeBackTooltipLibrary => 'Back to library';

  @override
  String get homeBackTooltipPlaylists => 'Back to playlist list';

  @override
  String get homeBackTooltipNetease => 'Back to online playlists';

  @override
  String get homeLogoutTooltipDefault => 'Sign out';

  @override
  String get homeLogoutTooltipNetease => 'Sign out of online service';

  @override
  String get homePullCloudPlaylistTitle => 'Import cloud playlist';

  @override
  String get homePullCloudPlaylistConfirm => 'Import';

  @override
  String get homePullCloudPlaylistDescription =>
      'Enter the cloud playlist ID (min 5 characters, letters/numbers/underscore).';

  @override
  String homePullCloudPlaylistSuccess(Object cloudId) {
    return 'Imported cloud playlist (ID: $cloudId)';
  }

  @override
  String get homePullCloudPlaylistProgress => 'Importing cloud playlist...';

  @override
  String get homePullCloudPlaylistAddCurrent =>
      'Playlist imported and current track added';

  @override
  String get homePullCloudPlaylistAlready =>
      'Playlist imported; track already existed';

  @override
  String get actionOk => 'OK';

  @override
  String get homeAddToPlaylistTitle => 'Add to playlist';

  @override
  String get homeAddToPlaylistEmpty => 'No tracks available to add';

  @override
  String get homeAddToPlaylistFailed => 'Failed to add to playlist';

  @override
  String get playlistDefaultName => 'Playlist';

  @override
  String get homeAddToPlaylistExists =>
      'Selected tracks already exist in the playlist';

  @override
  String homeAddToPlaylistSummary(int count, Object playlist) {
    return 'Added $count tracks to “$playlist”';
  }

  @override
  String homeAddToPlaylistSummaryWithSkipped(Object base, int skipped) {
    return '$base ($skipped already existed)';
  }

  @override
  String get homeSongMissingArtist => 'This track has no artist info';

  @override
  String get homeLibraryNotReady => 'Library is still loading';

  @override
  String get homeArtistNotFound => 'Artist not found in library';

  @override
  String get homeSongMissingAlbum => 'This track has no album info';

  @override
  String get homeAlbumNotFound => 'Album not found in library';

  @override
  String homeSongLabel(Object title) {
    return 'Song: $title';
  }

  @override
  String homeArtistLabel(Object name) {
    return 'Artist: $name';
  }

  @override
  String homeArtistDescription(int count) {
    return '$count tracks';
  }

  @override
  String homeAlbumLabel(Object title) {
    return 'Album: $title';
  }

  @override
  String homeAlbumDescription(Object artist, int count) {
    return '$artist • $count tracks';
  }

  @override
  String homeSearchQuerySuggestion(Object query) {
    return 'Search “$query”';
  }

  @override
  String get homeSearchQueryDescription =>
      'Continue searching across all content';

  @override
  String get homeArtistNotFoundDialog => 'No songs found for this artist';

  @override
  String get homeAlbumNotFoundDialog => 'No songs found for this album';

  @override
  String get homeOnlineMusicLabel => 'Online music';

  @override
  String get homeQueueLabel => 'Play queue';

  @override
  String homeLibraryStats(int total, int hours, int minutes) {
    return '$total tracks · $hours h $minutes m';
  }

  @override
  String get homeOnlineNotLoggedIn => 'Not signed in to online music';

  @override
  String get homeOnlinePlaylists => 'Online playlists';

  @override
  String homeOnlineStats(int total) {
    return '$total online tracks';
  }

  @override
  String get homeMysteryCodeInvalid => 'Invalid code';

  @override
  String get homeSelectFolderTitle => 'Choose music folder';

  @override
  String homeScanningFolder(Object name) {
    return 'Scanning folder: $name';
  }

  @override
  String homeScanningMisuzuFolder(Object folder) {
    return 'Scanning MisuzuMusic/$folder';
  }

  @override
  String get homeMisuzuRootName => 'MisuzuMusic (root)';

  @override
  String get homeMisuzuRootDescription => 'Scan the entire MisuzuMusic folder';

  @override
  String homeMisuzuFilesPath(Object folder) {
    return 'Files path: MisuzuMusic/$folder';
  }

  @override
  String get homePickMisuzuFolderTitle => 'Pick MisuzuMusic folder';

  @override
  String get homeMisuzuFilesHint =>
      'Files path: On My iPhone > Misuzu Music > MisuzuMusic';

  @override
  String homeMisuzuSubfolderCount(int count) {
    return '$count subfolders detected';
  }

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get homeMisuzuNoSubfolders =>
      'No subfolders detected yet. You can still pick the MisuzuMusic root.';

  @override
  String get homeWebDavLibrary => 'WebDAV library';

  @override
  String homeWebDavScanSummary(int count) {
    return 'Added $count new tracks';
  }

  @override
  String homeWebDavScanSummaryWithSource(int count, Object source) {
    return 'Added $count new tracks\nSource: $source';
  }

  @override
  String get homeScanCompletedTitle => 'Scan complete';

  @override
  String homeScanCompletedMessage(Object message) {
    return '✅ Scan completed! $message';
  }

  @override
  String get homeErrorTitle => 'Error occurred';
}
