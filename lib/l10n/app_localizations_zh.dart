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
  String get librarySearchPlaceholder => '搜索歌曲、艺术家或专辑...';

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
  String get actionSave => '保存';

  @override
  String get actionDelete => '删除';

  @override
  String get actionRemove => '移除';

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
  String get sortModeTitleAZ => '字母排序（A-Z）';

  @override
  String get sortModeTitleZA => '字母排序（Z-A）';

  @override
  String get sortModeAddedNewest => '添加时间（从新到旧）';

  @override
  String get sortModeAddedOldest => '添加时间（从旧到新）';

  @override
  String get sortModeArtistAZ => '歌手名（A-Z）';

  @override
  String get sortModeArtistZA => '歌手名（Z-A）';

  @override
  String get sortModeAlbumAZ => '专辑名（A-Z）';

  @override
  String get sortModeAlbumZA => '专辑名（Z-A）';

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
  String homeMisuzuFilesHint(Object filesRoot) {
    return 'Files 路径：$filesRoot > Misuzu Music > MisuzuMusic';
  }

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

  @override
  String get libraryMountDialogTitle => '选择挂载方式';

  @override
  String get libraryMountOptionAppFolderTitle => 'MisuzuMusic 文件夹';

  @override
  String get libraryMountOptionAppFolderDescription =>
      '浏览 Files App 中的 MisuzuMusic 目录，避免重复占用空间。';

  @override
  String get libraryMountOptionLocalTitle => '挂载本地文件夹';

  @override
  String get libraryMountOptionLocalDescription => '从磁盘选择文件夹并扫描其中的音乐文件。';

  @override
  String get libraryMountOptionMysteryTitle => '神秘代码';

  @override
  String get libraryMountOptionWebDavTitle => '挂载 WebDAV';

  @override
  String get libraryMountOptionWebDavDescription => '连接到 WebDAV 服务器以流式传输或下载音乐。';

  @override
  String get libraryMountInfoCardTitle => '通过 MisuzuMusic 文件夹导入';

  @override
  String libraryMountInfoCardDescription(Object filesRoot) {
    return 'iOS 会将外部文件复制到应用沙盒中，为避免空间占用，请按照以下步骤：\n1）在「文件」App 中进入「$filesRoot」> Misuzu Music。\n2）打开 MisuzuMusic 文件夹，并将包含歌曲的文件夹拷贝进去。\n3）返回 Misuzu Music，选择 MisuzuMusic 文件夹开始扫描。';
  }

  @override
  String get filesRootOnMyIphone => '我的 iPhone';

  @override
  String get filesRootOnMyIpad => '我的 iPad';

  @override
  String get libraryMountMysteryDialogTitle => '输入神秘代码';

  @override
  String get libraryMountMysteryCodeFieldLabel => '神秘代码';

  @override
  String get libraryMountMysteryCodeEmptyError => '请输入神秘代码';

  @override
  String get libraryMountConfirmButton => '确认挂载';

  @override
  String get playlistCreationModeTitle => '选择新建方式';

  @override
  String get playlistCreationModeLocalTitle => '本地新建歌单';

  @override
  String get playlistCreationModeLocalDescription => '使用本地存储，立即编辑歌单名称和内容。';

  @override
  String get playlistCreationModeCloudTitle => '拉取云歌单';

  @override
  String get playlistCreationModeCloudDescription => '根据云端 ID 下载现有歌单并导入本地。';

  @override
  String get playlistCreationCloudIdLabel => '云端ID';

  @override
  String get playlistCreationCloudIdHint => '至少 5 位，仅限字母/数字/下划线';

  @override
  String get playlistEditorTitleCreate => '新建歌单';

  @override
  String get playlistEditorTitleEdit => '编辑歌单';

  @override
  String get playlistEditorCoverLabel => '封面';

  @override
  String get playlistEditorSelectImage => '选择图片';

  @override
  String get playlistEditorNameLabel => '歌单名称';

  @override
  String get playlistEditorNamePlaceholder => '请输入歌单名称';

  @override
  String get playlistEditorDescriptionLabel => '简介';

  @override
  String get playlistEditorDescriptionPlaceholder => '介绍一下这个歌单吧';

  @override
  String get playlistEditorDeleteButton => '删除歌单';

  @override
  String get playlistEditorNameRequired => '歌单名称不能为空';

  @override
  String get playlistEditorSaveFailed => '保存失败';

  @override
  String get playlistEditorCreateFailed => '创建歌单失败';

  @override
  String get playlistEditorDeleteFailed => '删除歌单失败';

  @override
  String playlistEditorDeleteConfirmTitle(Object playlistName) {
    return '确定删除“$playlistName”吗？';
  }

  @override
  String get playlistEditorDeleteConfirmMessage => '该歌单将被永久移除，包含的歌曲不会删除。';

  @override
  String get playlistEditorDeleteDialogTitle => '删除歌单';

  @override
  String get contextMenuViewArtist => '查看歌手';

  @override
  String get contextMenuViewAlbum => '查看专辑';

  @override
  String get contextMenuAddToPlaylist => '添加到歌单';

  @override
  String get contextMenuRemoveFromPlaylist => '从歌单删除';

  @override
  String get contextMenuAddToOnlinePlaylist => '添加到网络歌曲歌单...';

  @override
  String get contextMenuOpenPlaylist => '打开歌单';

  @override
  String get contextMenuEditPlaylist => '编辑歌单';

  @override
  String get contextMenuConfigureAutosync => '自动同步设置...';

  @override
  String get contextMenuUploadPlaylist => '上传到云';

  @override
  String get contextMenuRemove => '移除';

  @override
  String get contextMenuAddAllToPlaylist => '全部添加到歌单';

  @override
  String get playlistRemoveTrackTitle => '从歌单移除歌曲？';

  @override
  String playlistRemoveTrackMessage(Object title) {
    return '“$title” 将从当前歌单移除，但文件和其它歌单不会受到影响。';
  }

  @override
  String get songDetailEditDialogTitle => '编辑歌曲详情';

  @override
  String songDetailEditDialogSubtitle(Object trackTitle, Object trackArtist) {
    return '曲目：$trackTitle · $trackArtist';
  }

  @override
  String get songDetailEditDialogDescription => '保存后将同步到服务器，可随时再次编辑。';

  @override
  String get songDetailEditDialogHint => '填写歌曲背景、制作人员、翻译或任何想展示的信息...';

  @override
  String get songDetailSaveSuccessTitle => '保存成功';

  @override
  String get songDetailSaveSuccessCreated => '已创建歌曲详情。';

  @override
  String get songDetailSaveSuccessUpdated => '歌曲详情已更新。';

  @override
  String get songDetailSaveFailureTitle => '保存失败';

  @override
  String songDetailSaveFailureMessage(Object error) {
    return '保存歌曲详情失败：$error';
  }

  @override
  String get songDetailLoadErrorTitle => '加载失败';

  @override
  String get songDetailEmptyTitle => '暂无歌曲详情';

  @override
  String get songDetailEmptyDescription => '使用下方“编辑详情”撰写内容后会自动保存在服务器。';

  @override
  String get songDetailSectionTitle => '歌曲详情';

  @override
  String get songDetailSavingLabel => '保存中...';

  @override
  String get songDetailEditButton => '编辑详情';
}
