import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义应用的外观和主题'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'了解项目名称、版本号与仓库链接'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsDeveloperTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发者选项'**
  String get settingsDeveloperTitle;

  /// No description provided for @settingsDeveloperSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'访问调试输出等工具'**
  String get settingsDeveloperSubtitle;

  /// No description provided for @settingsUnknownVersion.
  ///
  /// In zh, this message translates to:
  /// **'未知版本'**
  String get settingsUnknownVersion;

  /// No description provided for @settingsProjectNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'项目名称'**
  String get settingsProjectNameLabel;

  /// No description provided for @settingsVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'版本号'**
  String get settingsVersionLabel;

  /// No description provided for @settingsRepositoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库'**
  String get settingsRepositoryLabel;

  /// No description provided for @settingsDeveloperTerminalTitle.
  ///
  /// In zh, this message translates to:
  /// **'终端输出'**
  String get settingsDeveloperTerminalTitle;

  /// No description provided for @settingsDeveloperTerminalSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看 print 和 debugPrint 的实时日志'**
  String get settingsDeveloperTerminalSubtitle;

  /// No description provided for @settingsDeveloperLogExplanation.
  ///
  /// In zh, this message translates to:
  /// **'展示应用启动以来所有 print 与 debugPrint 输出，可快速搜索或过滤。'**
  String get settingsDeveloperLogExplanation;

  /// No description provided for @settingsDeveloperClearSearch.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get settingsDeveloperClearSearch;

  /// No description provided for @settingsDeveloperSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索日志内容或时间戳...'**
  String get settingsDeveloperSearchHint;

  /// No description provided for @settingsDeveloperEmptyLogs.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可显示的输出。'**
  String get settingsDeveloperEmptyLogs;

  /// No description provided for @settingsDeveloperNoFilterResult.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配筛选条件的日志。'**
  String get settingsDeveloperNoFilterResult;

  /// No description provided for @settingsDeveloperLogFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get settingsDeveloperLogFilterAll;

  /// No description provided for @settingsDeveloperLogFilterInfo.
  ///
  /// In zh, this message translates to:
  /// **'仅普通输出'**
  String get settingsDeveloperLogFilterInfo;

  /// No description provided for @settingsDeveloperLogFilterError.
  ///
  /// In zh, this message translates to:
  /// **'仅错误'**
  String get settingsDeveloperLogFilterError;

  /// No description provided for @settingsDeveloperLogCount.
  ///
  /// In zh, this message translates to:
  /// **'总计 {total} 条，筛选后 {filtered} 条。'**
  String settingsDeveloperLogCount(int total, int filtered);

  /// No description provided for @settingsThemeModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get settingsThemeModeLabel;

  /// No description provided for @settingsThemeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeModeLight;

  /// No description provided for @settingsThemeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeModeDark;

  /// No description provided for @settingsThemeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get settingsThemeModeSystem;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In zh, this message translates to:
  /// **'切换界面文本语言'**
  String get settingsLanguageDescription;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'英语'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsAboutProjectLine.
  ///
  /// In zh, this message translates to:
  /// **'项目名称：{name}'**
  String settingsAboutProjectLine(Object name);

  /// No description provided for @settingsAboutVersionLine.
  ///
  /// In zh, this message translates to:
  /// **'版本号：{version}'**
  String settingsAboutVersionLine(Object version);

  /// No description provided for @settingsAboutRepositoryLine.
  ///
  /// In zh, this message translates to:
  /// **'GitHub：{url}'**
  String settingsAboutRepositoryLine(Object url);

  /// No description provided for @settingsRepositoryOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接 {url}'**
  String settingsRepositoryOpenFailed(Object url);

  /// No description provided for @actionClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get actionClear;

  /// No description provided for @actionClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get actionClose;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
