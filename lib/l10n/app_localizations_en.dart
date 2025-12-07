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
  String get librarySearchPlaceholder => 'Search songs, artists or albums...';

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
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRemove => 'Remove';

  @override
  String get navLibrary => 'Library';

  @override
  String get navPlaylists => 'Song Lists';

  @override
  String get navOnlineTracks => 'Online Tracks';

  @override
  String get navQueue => 'History';

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
  String get sortModeTitleAZ => 'Title (A-Z)';

  @override
  String get sortModeTitleZA => 'Title (Z-A)';

  @override
  String get sortModeAddedNewest => 'Added (newest first)';

  @override
  String get sortModeAddedOldest => 'Added (oldest first)';

  @override
  String get sortModeArtistAZ => 'Artist (A-Z)';

  @override
  String get sortModeArtistZA => 'Artist (Z-A)';

  @override
  String get sortModeAlbumAZ => 'Album (A-Z)';

  @override
  String get sortModeAlbumZA => 'Album (Z-A)';

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
  String get queueEmptyMessage => 'No tracks in queue';

  @override
  String get queueNowPlaying => 'Now playing';

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
  String get homeICloudRootName => 'iCloud Drive';

  @override
  String get homeICloudContainerMissing =>
      'Set AppConstants.iosICloudContainerId to your iCloud container ID before mounting from iCloud.';

  @override
  String get homeICloudNoSubfolders =>
      'No iCloud folders were found at this level.';

  @override
  String get homeICloudEmptyFolder =>
      'This folder doesn\'t contain any files yet.';

  @override
  String homeICloudFolderFileCount(int count) {
    return '$count items in this folder';
  }

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
  String homeMisuzuFilesHint(Object filesRoot) {
    return 'Files path: $filesRoot > Misuzu Music > MisuzuMusic';
  }

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

  @override
  String get libraryMountDialogTitle => 'Choose mount method';

  @override
  String get libraryMountOptionAppFolderTitle => 'MisuzuMusic folder';

  @override
  String get libraryMountOptionAppFolderDescription =>
      'Browse the MisuzuMusic directory in the Files app to avoid using extra storage.';

  @override
  String get libraryMountOptionLocalTitle => 'Mount local folder';

  @override
  String get libraryMountOptionLocalDescription =>
      'Pick a folder on disk and scan the music inside.';

  @override
  String get libraryMountOptionICloudTitle => 'Mount from iCloud';

  @override
  String get libraryMountOptionICloudDescription =>
      'Mount the MisuzuMusic folder stored in iCloud Drive to keep every device in sync.';

  @override
  String get libraryMountOptionMysteryTitle => 'Mystery code';

  @override
  String get libraryMountOptionWebDavTitle => 'Mount WebDAV';

  @override
  String get libraryMountOptionWebDavDescription =>
      'Connect to a WebDAV server to stream or download music.';

  @override
  String get libraryMountInfoCardTitle => 'Import via the MisuzuMusic folder';

  @override
  String libraryMountInfoCardDescription(Object filesRoot) {
    return 'iOS copies external files into the sandbox. To avoid using extra space, follow these steps:\n1) In the Files app, open $filesRoot > Misuzu Music.\n2) Open the MisuzuMusic folder and copy any folders containing songs into it.\n3) Return to Misuzu Music and select the MisuzuMusic folder to start scanning.';
  }

  @override
  String get filesRootOnMyIphone => 'On My iPhone';

  @override
  String get filesRootOnMyIpad => 'On My iPad';

  @override
  String get libraryMountMysteryDialogTitle => 'Enter mystery code';

  @override
  String get libraryMountMysteryCodeFieldLabel => 'Mystery code';

  @override
  String get libraryMountMysteryCodeEmptyError => 'Please enter a mystery code';

  @override
  String get libraryMountConfirmButton => 'Mount';

  @override
  String get playlistCreationModeTitle => 'Choose creation method';

  @override
  String get playlistCreationModeLocalTitle => 'Create local playlist';

  @override
  String get playlistCreationModeLocalDescription =>
      'Store the playlist locally and edit its name and content right away.';

  @override
  String get playlistCreationModeCloudTitle => 'Import cloud playlist';

  @override
  String get playlistCreationModeCloudDescription =>
      'Download an existing playlist by its cloud ID and import it locally.';

  @override
  String get playlistCreationCloudIdLabel => 'Cloud ID';

  @override
  String get playlistCreationCloudIdHint =>
      'At least 5 characters, letters/numbers/underscore';

  @override
  String get playlistEditorTitleCreate => 'New playlist';

  @override
  String get playlistEditorTitleEdit => 'Edit playlist';

  @override
  String get playlistEditorCoverLabel => 'Cover';

  @override
  String get playlistEditorSelectImage => 'Choose image';

  @override
  String get playlistEditorNameLabel => 'Playlist name';

  @override
  String get playlistEditorNamePlaceholder => 'Enter a playlist name';

  @override
  String get playlistEditorDescriptionLabel => 'Description';

  @override
  String get playlistEditorDescriptionPlaceholder => 'Describe this playlist';

  @override
  String get playlistEditorDeleteButton => 'Delete playlist';

  @override
  String get playlistEditorNameRequired => 'Playlist name cannot be empty';

  @override
  String get playlistEditorSaveFailed => 'Failed to save playlist';

  @override
  String get playlistEditorCreateFailed => 'Failed to create playlist';

  @override
  String get playlistEditorDeleteFailed => 'Failed to delete playlist';

  @override
  String playlistEditorDeleteConfirmTitle(Object playlistName) {
    return 'Delete \"$playlistName\"?';
  }

  @override
  String get playlistEditorDeleteConfirmMessage =>
      'This playlist will be removed permanently. Songs inside will stay in your library.';

  @override
  String get playlistEditorDeleteDialogTitle => 'Delete playlist';

  @override
  String get contextMenuViewArtist => 'View artist';

  @override
  String get contextMenuViewAlbum => 'View album';

  @override
  String get contextMenuPlayNext => 'Play next';

  @override
  String get contextMenuAddToQueue => 'Add to queue';

  @override
  String get contextMenuAddToPlaylist => 'Add to playlist';

  @override
  String get contextMenuRemoveFromPlaylist => 'Remove from playlist';

  @override
  String get contextMenuAddToOnlinePlaylist => 'Add to online playlist...';

  @override
  String get contextMenuOpenPlaylist => 'Open playlist';

  @override
  String get contextMenuEditPlaylist => 'Edit playlist';

  @override
  String get contextMenuConfigureAutosync => 'Auto-sync settings...';

  @override
  String get contextMenuUploadPlaylist => 'Upload to cloud';

  @override
  String get contextMenuRemove => 'Remove';

  @override
  String get contextMenuAddAllToPlaylist => 'Add all to playlist';

  @override
  String get playlistRemoveTrackTitle => 'Remove from playlist?';

  @override
  String playlistRemoveTrackMessage(Object title) {
    return '\"$title\" will be removed from this playlist, but the file and other playlists won\'t be affected.';
  }

  @override
  String get songDetailEditDialogTitle => 'Edit song detail';

  @override
  String songDetailEditDialogSubtitle(Object trackTitle, Object trackArtist) {
    return 'Track: $trackTitle · $trackArtist';
  }

  @override
  String get songDetailEditDialogDescription =>
      'The content syncs to the server and can be edited at any time.';

  @override
  String get songDetailEditDialogHint =>
      'Share background info, contributors, translations, or anything else...';

  @override
  String get songDetailSaveSuccessTitle => 'Saved';

  @override
  String get songDetailSaveSuccessCreated => 'Song detail created.';

  @override
  String get songDetailSaveSuccessUpdated => 'Song detail updated.';

  @override
  String get songDetailSaveFailureTitle => 'Save failed';

  @override
  String songDetailSaveFailureMessage(Object error) {
    return 'Failed to save song detail: $error';
  }

  @override
  String get songDetailLoadErrorTitle => 'Load failed';

  @override
  String get songDetailEmptyTitle => 'No song detail yet';

  @override
  String get songDetailEmptyDescription =>
      'Use \"Edit detail\" below to add content. It syncs automatically.';

  @override
  String get songDetailSectionTitle => 'Song detail';

  @override
  String get songDetailSavingLabel => 'Saving...';

  @override
  String get songDetailEditButton => 'Edit detail';
}
