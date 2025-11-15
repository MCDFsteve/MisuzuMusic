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

  @override
  String get navLibrary => '音乐库';

  @override
  String get navPlaylists => '歌单';

  @override
  String get navOnlineTracks => '网络歌曲';

  @override
  String get navQueue => '播放队列';

  @override
  String get navSettings => '设置';

  @override
  String get glassHeaderBackTooltip => '返回上一层';

  @override
  String get glassHeaderLogoutTooltip => '退出登录';

  @override
  String get glassHeaderSortTooltip => '切换排序方式';

  @override
  String get glassHeaderCreatePlaylistTooltip => '新建歌单';

  @override
  String get glassHeaderSelectFolderTooltip => '选择音乐文件夹';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowRestore => '还原';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowClose => '关闭';

  @override
  String get glassHeaderSortTitle => '选择排序方式';

  @override
  String get actionCancel => '取消';

  @override
  String get homeBackTooltipDefault => '返回上一层';

  @override
  String get homeBackTooltipLibrary => '返回音乐库';

  @override
  String get homeBackTooltipPlaylists => '返回歌单列表';

  @override
  String get homeBackTooltipNetease => '返回网络歌曲歌单列表';

  @override
  String get homeLogoutTooltipDefault => '退出登录';

  @override
  String get homeLogoutTooltipNetease => '退出网络歌曲登录';

  @override
  String get homePullCloudPlaylistTitle => '拉取云歌单';

  @override
  String get homePullCloudPlaylistConfirm => '拉取';

  @override
  String get homePullCloudPlaylistDescription =>
      '输入云端歌单的 ID，至少 5 位，支持字母、数字和下划线。';

  @override
  String homePullCloudPlaylistSuccess(Object cloudId) {
    return '已拉取云歌单（ID: $cloudId）';
  }

  @override
  String get homePullCloudPlaylistProgress => '正在拉取云歌单...';

  @override
  String get homePullCloudPlaylistAddCurrent => '已拉取云歌单并添加当前歌曲';

  @override
  String get homePullCloudPlaylistAlready => '云歌单已拉取，歌曲已存在于该歌单';

  @override
  String get actionOk => '好的';

  @override
  String get homeAddToPlaylistTitle => '添加到歌单';

  @override
  String get homeAddToPlaylistEmpty => '当前没有可添加的歌曲';

  @override
  String get homeAddToPlaylistFailed => '添加到歌单失败';

  @override
  String get playlistDefaultName => '歌单';

  @override
  String get homeAddToPlaylistExists => '所选歌曲已存在于歌单';

  @override
  String homeAddToPlaylistSummary(int count, Object playlist) {
    return '已添加 $count 首歌曲到歌单 “$playlist”';
  }

  @override
  String homeAddToPlaylistSummaryWithSkipped(Object base, int skipped) {
    return '$base（$skipped 首已存在）';
  }

  @override
  String get homeSongMissingArtist => '该歌曲缺少歌手信息';

  @override
  String get homeLibraryNotReady => '音乐库尚未加载完成';

  @override
  String get homeArtistNotFound => '音乐库中未找到该歌手';

  @override
  String get homeSongMissingAlbum => '该歌曲缺少专辑信息';

  @override
  String get homeAlbumNotFound => '音乐库中未找到该专辑';

  @override
  String homeSongLabel(Object title) {
    return '歌曲：$title';
  }

  @override
  String homeArtistLabel(Object name) {
    return '歌手：$name';
  }

  @override
  String homeArtistDescription(int count) {
    return '共 $count 首歌曲';
  }

  @override
  String homeAlbumLabel(Object title) {
    return '专辑：$title';
  }

  @override
  String homeAlbumDescription(Object artist, int count) {
    return '$artist • $count 首';
  }

  @override
  String homeSearchQuerySuggestion(Object query) {
    return '搜索“$query”';
  }

  @override
  String get homeSearchQueryDescription => '在全部内容中继续查找';

  @override
  String get homeArtistNotFoundDialog => '未找到该歌手的歌曲';

  @override
  String get homeAlbumNotFoundDialog => '未找到该专辑的歌曲';

  @override
  String get homeOnlineMusicLabel => '网络歌曲';

  @override
  String get homeQueueLabel => '播放队列';

  @override
  String homeLibraryStats(int total, int hours, int minutes) {
    return '共 $total 首歌曲 · $hours 小时 $minutes 分钟';
  }

  @override
  String get homeOnlineNotLoggedIn => '未登录网络歌曲';

  @override
  String get homeOnlinePlaylists => '网络歌曲歌单';

  @override
  String homeOnlineStats(int total) {
    return '网络歌曲共 $total 首歌曲';
  }

  @override
  String get homeMysteryCodeInvalid => '神秘代码不正确';

  @override
  String get homeSelectFolderTitle => '选择音乐文件夹';

  @override
  String homeScanningFolder(Object name) {
    return '正在扫描文件夹: $name';
  }

  @override
  String homeScanningMisuzuFolder(Object folder) {
    return '正在扫描 MisuzuMusic/$folder';
  }

  @override
  String get homeMisuzuRootName => 'MisuzuMusic（根目录）';

  @override
  String get homeMisuzuRootDescription => '扫描整个 MisuzuMusic 文件夹';

  @override
  String homeMisuzuFilesPath(Object folder) {
    return 'Files 路径：MisuzuMusic/$folder';
  }

  @override
  String get homePickMisuzuFolderTitle => '选择 MisuzuMusic 文件夹';

  @override
  String get homeMisuzuFilesHint =>
      'Files 路径：我的 iPhone > Misuzu Music > MisuzuMusic';

  @override
  String homeMisuzuSubfolderCount(int count) {
    return '当前 MisuzuMusic 中共有 $count 个子文件夹';
  }

  @override
  String get actionRefresh => '刷新';

  @override
  String get homeMisuzuNoSubfolders => '暂未检测到子文件夹，也可以直接选择 MisuzuMusic 根目录。';

  @override
  String get homeWebDavLibrary => 'WebDAV 音乐库';

  @override
  String homeWebDavScanSummary(int count) {
    return '添加了 $count 首新歌曲';
  }

  @override
  String homeWebDavScanSummaryWithSource(int count, Object source) {
    return '添加了 $count 首新歌曲\n来源: $source';
  }

  @override
  String get homeScanCompletedTitle => '扫描完成';

  @override
  String homeScanCompletedMessage(Object message) {
    return '✅ 扫描完成！$message';
  }

  @override
  String get homeErrorTitle => '发生错误';
}
