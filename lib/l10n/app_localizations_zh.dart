// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settingsAppearanceTitle => '外观';

  @override
  String get settingsAppearanceSubtitle => '自定义应用的外观和主题';

  @override
  String get settingsAboutTitle => '关于';

  @override
  String get settingsAboutSubtitle => '了解项目名称、版本号与仓库链接';

  @override
  String get settingsDeveloperTitle => '开发者选项';

  @override
  String get settingsDeveloperSubtitle => '访问调试输出等工具';

  @override
  String get settingsUnknownVersion => '未知版本';

  @override
  String get settingsProjectNameLabel => '项目名称';

  @override
  String get settingsVersionLabel => '版本号';

  @override
  String get settingsRepositoryLabel => 'GitHub 仓库';

  @override
  String get settingsDeveloperTerminalTitle => '终端输出';

  @override
  String get settingsDeveloperTerminalSubtitle => '查看 print 和 debugPrint 的实时日志';

  @override
  String get settingsDeveloperLogExplanation =>
      '展示应用启动以来所有 print 与 debugPrint 输出，可快速搜索或过滤。';

  @override
  String get settingsDeveloperClearSearch => '清除搜索';

  @override
  String get settingsDeveloperSearchHint => '搜索日志内容或时间戳...';

  @override
  String get settingsDeveloperEmptyLogs => '当前没有可显示的输出。';

  @override
  String get settingsDeveloperNoFilterResult => '没有匹配筛选条件的日志。';

  @override
  String get settingsDeveloperLogFilterAll => '全部';

  @override
  String get settingsDeveloperLogFilterInfo => '仅普通输出';

  @override
  String get settingsDeveloperLogFilterError => '仅错误';

  @override
  String settingsDeveloperLogCount(int total, int filtered) {
    return '总计 $total 条，筛选后 $filtered 条。';
  }

  @override
  String get settingsThemeModeLabel => '主题模式';

  @override
  String get settingsThemeModeLight => '浅色';

  @override
  String get settingsThemeModeDark => '深色';

  @override
  String get settingsThemeModeSystem => '系统';

  @override
  String get settingsLanguageLabel => '界面语言';

  @override
  String get settingsLanguageDescription => '切换界面文本语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => '英语';

  @override
  String settingsAboutProjectLine(Object name) {
    return '项目名称：$name';
  }

  @override
  String settingsAboutVersionLine(Object version) {
    return '版本号：$version';
  }

  @override
  String settingsAboutRepositoryLine(Object url) {
    return 'GitHub：$url';
  }

  @override
  String settingsRepositoryOpenFailed(Object url) {
    return '无法打开链接 $url';
  }

  @override
  String get actionClear => '清空';

  @override
  String get actionClose => '关闭';
}
