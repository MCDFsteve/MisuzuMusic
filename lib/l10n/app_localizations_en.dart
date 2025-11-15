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
}
