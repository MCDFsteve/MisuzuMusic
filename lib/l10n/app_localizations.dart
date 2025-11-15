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

  /// No description provided for @navLibrary.
  ///
  /// In zh, this message translates to:
  /// **'音乐库'**
  String get navLibrary;

  /// No description provided for @navPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get navPlaylists;

  /// No description provided for @navOnlineTracks.
  ///
  /// In zh, this message translates to:
  /// **'网络歌曲'**
  String get navOnlineTracks;

  /// No description provided for @navQueue.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get navQueue;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @glassHeaderBackTooltip.
  ///
  /// In zh, this message translates to:
  /// **'返回上一层'**
  String get glassHeaderBackTooltip;

  /// No description provided for @glassHeaderLogoutTooltip.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get glassHeaderLogoutTooltip;

  /// No description provided for @glassHeaderSortTooltip.
  ///
  /// In zh, this message translates to:
  /// **'切换排序方式'**
  String get glassHeaderSortTooltip;

  /// No description provided for @glassHeaderCreatePlaylistTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新建歌单'**
  String get glassHeaderCreatePlaylistTooltip;

  /// No description provided for @glassHeaderSelectFolderTooltip.
  ///
  /// In zh, this message translates to:
  /// **'选择音乐文件夹'**
  String get glassHeaderSelectFolderTooltip;

  /// No description provided for @windowMinimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get windowMinimize;

  /// No description provided for @windowRestore.
  ///
  /// In zh, this message translates to:
  /// **'还原'**
  String get windowRestore;

  /// No description provided for @windowMaximize.
  ///
  /// In zh, this message translates to:
  /// **'最大化'**
  String get windowMaximize;

  /// No description provided for @windowClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get windowClose;

  /// No description provided for @glassHeaderSortTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择排序方式'**
  String get glassHeaderSortTitle;

  /// No description provided for @actionCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// No description provided for @homeBackTooltipDefault.
  ///
  /// In zh, this message translates to:
  /// **'返回上一层'**
  String get homeBackTooltipDefault;

  /// No description provided for @homeBackTooltipLibrary.
  ///
  /// In zh, this message translates to:
  /// **'返回音乐库'**
  String get homeBackTooltipLibrary;

  /// No description provided for @homeBackTooltipPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'返回歌单列表'**
  String get homeBackTooltipPlaylists;

  /// No description provided for @homeBackTooltipNetease.
  ///
  /// In zh, this message translates to:
  /// **'返回网络歌曲歌单列表'**
  String get homeBackTooltipNetease;

  /// No description provided for @homeLogoutTooltipDefault.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get homeLogoutTooltipDefault;

  /// No description provided for @homeLogoutTooltipNetease.
  ///
  /// In zh, this message translates to:
  /// **'退出网络歌曲登录'**
  String get homeLogoutTooltipNetease;

  /// No description provided for @homePullCloudPlaylistTitle.
  ///
  /// In zh, this message translates to:
  /// **'拉取云歌单'**
  String get homePullCloudPlaylistTitle;

  /// No description provided for @homePullCloudPlaylistConfirm.
  ///
  /// In zh, this message translates to:
  /// **'拉取'**
  String get homePullCloudPlaylistConfirm;

  /// No description provided for @homePullCloudPlaylistDescription.
  ///
  /// In zh, this message translates to:
  /// **'输入云端歌单的 ID，至少 5 位，支持字母、数字和下划线。'**
  String get homePullCloudPlaylistDescription;

  /// No description provided for @homePullCloudPlaylistSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已拉取云歌单（ID: {cloudId}）'**
  String homePullCloudPlaylistSuccess(Object cloudId);

  /// No description provided for @homePullCloudPlaylistProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在拉取云歌单...'**
  String get homePullCloudPlaylistProgress;

  /// No description provided for @homePullCloudPlaylistAddCurrent.
  ///
  /// In zh, this message translates to:
  /// **'已拉取云歌单并添加当前歌曲'**
  String get homePullCloudPlaylistAddCurrent;

  /// No description provided for @homePullCloudPlaylistAlready.
  ///
  /// In zh, this message translates to:
  /// **'云歌单已拉取，歌曲已存在于该歌单'**
  String get homePullCloudPlaylistAlready;

  /// No description provided for @actionOk.
  ///
  /// In zh, this message translates to:
  /// **'好的'**
  String get actionOk;

  /// No description provided for @homeAddToPlaylistTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加到歌单'**
  String get homeAddToPlaylistTitle;

  /// No description provided for @homeAddToPlaylistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可添加的歌曲'**
  String get homeAddToPlaylistEmpty;

  /// No description provided for @homeAddToPlaylistFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加到歌单失败'**
  String get homeAddToPlaylistFailed;

  /// No description provided for @playlistDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get playlistDefaultName;

  /// No description provided for @homeAddToPlaylistExists.
  ///
  /// In zh, this message translates to:
  /// **'所选歌曲已存在于歌单'**
  String get homeAddToPlaylistExists;

  /// No description provided for @homeAddToPlaylistSummary.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {count} 首歌曲到歌单 “{playlist}”'**
  String homeAddToPlaylistSummary(int count, Object playlist);

  /// No description provided for @homeAddToPlaylistSummaryWithSkipped.
  ///
  /// In zh, this message translates to:
  /// **'{base}（{skipped} 首已存在）'**
  String homeAddToPlaylistSummaryWithSkipped(Object base, int skipped);

  /// No description provided for @homeSongMissingArtist.
  ///
  /// In zh, this message translates to:
  /// **'该歌曲缺少歌手信息'**
  String get homeSongMissingArtist;

  /// No description provided for @homeLibraryNotReady.
  ///
  /// In zh, this message translates to:
  /// **'音乐库尚未加载完成'**
  String get homeLibraryNotReady;

  /// No description provided for @homeArtistNotFound.
  ///
  /// In zh, this message translates to:
  /// **'音乐库中未找到该歌手'**
  String get homeArtistNotFound;

  /// No description provided for @homeSongMissingAlbum.
  ///
  /// In zh, this message translates to:
  /// **'该歌曲缺少专辑信息'**
  String get homeSongMissingAlbum;

  /// No description provided for @homeAlbumNotFound.
  ///
  /// In zh, this message translates to:
  /// **'音乐库中未找到该专辑'**
  String get homeAlbumNotFound;

  /// No description provided for @homeSongLabel.
  ///
  /// In zh, this message translates to:
  /// **'歌曲：{title}'**
  String homeSongLabel(Object title);

  /// No description provided for @homeArtistLabel.
  ///
  /// In zh, this message translates to:
  /// **'歌手：{name}'**
  String homeArtistLabel(Object name);

  /// No description provided for @homeArtistDescription.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 首歌曲'**
  String homeArtistDescription(int count);

  /// No description provided for @homeAlbumLabel.
  ///
  /// In zh, this message translates to:
  /// **'专辑：{title}'**
  String homeAlbumLabel(Object title);

  /// No description provided for @homeAlbumDescription.
  ///
  /// In zh, this message translates to:
  /// **'{artist} • {count} 首'**
  String homeAlbumDescription(Object artist, int count);

  /// No description provided for @homeSearchQuerySuggestion.
  ///
  /// In zh, this message translates to:
  /// **'搜索“{query}”'**
  String homeSearchQuerySuggestion(Object query);

  /// No description provided for @homeSearchQueryDescription.
  ///
  /// In zh, this message translates to:
  /// **'在全部内容中继续查找'**
  String get homeSearchQueryDescription;

  /// No description provided for @homeArtistNotFoundDialog.
  ///
  /// In zh, this message translates to:
  /// **'未找到该歌手的歌曲'**
  String get homeArtistNotFoundDialog;

  /// No description provided for @homeAlbumNotFoundDialog.
  ///
  /// In zh, this message translates to:
  /// **'未找到该专辑的歌曲'**
  String get homeAlbumNotFoundDialog;

  /// No description provided for @homeOnlineMusicLabel.
  ///
  /// In zh, this message translates to:
  /// **'网络歌曲'**
  String get homeOnlineMusicLabel;

  /// No description provided for @homeQueueLabel.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get homeQueueLabel;

  /// No description provided for @homeLibraryStats.
  ///
  /// In zh, this message translates to:
  /// **'共 {total} 首歌曲 · {hours} 小时 {minutes} 分钟'**
  String homeLibraryStats(int total, int hours, int minutes);

  /// No description provided for @homeOnlineNotLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录网络歌曲'**
  String get homeOnlineNotLoggedIn;

  /// No description provided for @homeOnlinePlaylists.
  ///
  /// In zh, this message translates to:
  /// **'网络歌曲歌单'**
  String get homeOnlinePlaylists;

  /// No description provided for @homeOnlineStats.
  ///
  /// In zh, this message translates to:
  /// **'网络歌曲共 {total} 首歌曲'**
  String homeOnlineStats(int total);

  /// No description provided for @homeMysteryCodeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'神秘代码不正确'**
  String get homeMysteryCodeInvalid;

  /// No description provided for @homeSelectFolderTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择音乐文件夹'**
  String get homeSelectFolderTitle;

  /// No description provided for @homeScanningFolder.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描文件夹: {name}'**
  String homeScanningFolder(Object name);

  /// No description provided for @homeScanningMisuzuFolder.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描 MisuzuMusic/{folder}'**
  String homeScanningMisuzuFolder(Object folder);

  /// No description provided for @homeMisuzuRootName.
  ///
  /// In zh, this message translates to:
  /// **'MisuzuMusic（根目录）'**
  String get homeMisuzuRootName;

  /// No description provided for @homeMisuzuRootDescription.
  ///
  /// In zh, this message translates to:
  /// **'扫描整个 MisuzuMusic 文件夹'**
  String get homeMisuzuRootDescription;

  /// No description provided for @homeMisuzuFilesPath.
  ///
  /// In zh, this message translates to:
  /// **'Files 路径：MisuzuMusic/{folder}'**
  String homeMisuzuFilesPath(Object folder);

  /// No description provided for @homePickMisuzuFolderTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择 MisuzuMusic 文件夹'**
  String get homePickMisuzuFolderTitle;

  /// No description provided for @homeMisuzuFilesHint.
  ///
  /// In zh, this message translates to:
  /// **'Files 路径：我的 iPhone > Misuzu Music > MisuzuMusic'**
  String get homeMisuzuFilesHint;

  /// No description provided for @homeMisuzuSubfolderCount.
  ///
  /// In zh, this message translates to:
  /// **'当前 MisuzuMusic 中共有 {count} 个子文件夹'**
  String homeMisuzuSubfolderCount(int count);

  /// No description provided for @actionRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get actionRefresh;

  /// No description provided for @homeMisuzuNoSubfolders.
  ///
  /// In zh, this message translates to:
  /// **'暂未检测到子文件夹，也可以直接选择 MisuzuMusic 根目录。'**
  String get homeMisuzuNoSubfolders;

  /// No description provided for @homeWebDavLibrary.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 音乐库'**
  String get homeWebDavLibrary;

  /// No description provided for @homeWebDavScanSummary.
  ///
  /// In zh, this message translates to:
  /// **'添加了 {count} 首新歌曲'**
  String homeWebDavScanSummary(int count);

  /// No description provided for @homeWebDavScanSummaryWithSource.
  ///
  /// In zh, this message translates to:
  /// **'添加了 {count} 首新歌曲\n来源: {source}'**
  String homeWebDavScanSummaryWithSource(int count, Object source);

  /// No description provided for @homeScanCompletedTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成'**
  String get homeScanCompletedTitle;

  /// No description provided for @homeScanCompletedMessage.
  ///
  /// In zh, this message translates to:
  /// **'✅ 扫描完成！{message}'**
  String homeScanCompletedMessage(Object message);

  /// No description provided for @homeErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'发生错误'**
  String get homeErrorTitle;
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
