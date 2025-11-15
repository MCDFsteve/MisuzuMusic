import 'dart:ui' as ui;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/modal_dialog.dart';
import '../../developer/developer_log_collector.dart';
import '../../widgets/common/adaptive_scrollbar.dart';
import '../../widgets/common/hover_glow_overlay.dart';

final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();
final Uri _repositoryUrl =
    Uri.parse('https://github.com/MCDFsteve/MisuzuMusic');

Future<void> _openRepository() async {
  final result = await launchUrl(
    _repositoryUrl,
    mode: LaunchMode.externalApplication,
  );
  if (!result) {
    debugPrint('无法打开 $_repositoryUrl');
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = sl<ThemeController>();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final mode = themeController.themeMode;

        return _UnifiedSettingsView(
          currentMode: mode,
          onChanged: themeController.setThemeMode,
        );
      },
    );
  }
}

class _UnifiedSettingsView extends StatelessWidget {
  const _UnifiedSettingsView({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    if (_isMobilePlatform(context)) {
      return _buildAdaptiveMobileSettings(context);
    }

    return _buildDesktopSettings(context);
  }

  bool _isMobilePlatform(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  Widget _buildDesktopSettings(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AdaptiveScrollbar(
      isDarkMode: isDarkMode,
      builder: (controller) {
        return CustomScrollView(
          controller: controller,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsCard(
                      isDarkMode: isDarkMode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsSection(
                            title: '外观',
                            subtitle: '自定义应用的外观和主题',
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 20),
                          _ThemeModeControl(
                            currentMode: currentMode,
                            onChanged: onChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SettingsCard(
                      isDarkMode: isDarkMode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsSection(
                            title: '关于',
                            subtitle: '了解项目名称、版本号与仓库链接',
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 20),
                          _AboutSection(packageInfoFuture: _packageInfoFuture),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SettingsCard(
                      isDarkMode: isDarkMode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsSection(
                            title: '开发者选项',
                            subtitle: '访问调试输出等工具',
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 20),
                          _DeveloperOptionsList(isDarkMode: isDarkMode),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdaptiveMobileSettings(BuildContext context) {
    const double extraBottomSpacing = 96;
    final mediaPadding = MediaQuery.of(context).padding;
    final bottomPadding = mediaPadding.bottom + 24 + extraBottomSpacing;
    final sections = <Widget>[
      _buildAdaptiveAppearanceSection(context),
      _buildAdaptiveAboutSection(context),
      _buildAdaptiveDeveloperSection(context),
    ];

    return SafeArea(
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPadding),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => sections[index],
      ),
    );
  }

  Widget _buildAdaptiveAppearanceSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final secondary = theme.textTheme.bodySmall?.color?.withOpacity(0.8) ??
        theme.colorScheme.onSurfaceVariant.withOpacity(0.8);

    return _SettingsCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '外观',
            locale: const Locale('zh-Hans', 'zh'),
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ) ??
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '自定义应用的外观和主题',
            locale: const Locale('zh-Hans', 'zh'),
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
          const SizedBox(height: 16),
          _ThemeModeControl(
            currentMode: currentMode,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveAboutSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return _SettingsCard(
      isDarkMode: isDarkMode,
      padding: EdgeInsets.zero,
      child: FutureBuilder<PackageInfo>(
        future: _packageInfoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final info = snapshot.data;
          final appName = info?.appName.isNotEmpty == true
              ? info!.appName
              : 'Misuzu Music';
          final version = info?.version ?? '未知版本';

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAdaptiveInfoTile(
                context,
                leading: const Icon(Icons.badge_outlined),
                title: '项目名称',
                subtitle: appName,
              ),
              _buildAdaptiveInfoTile(
                context,
                leading: const Icon(Icons.tag_outlined),
                title: '版本号',
                subtitle: version,
              ),
              _buildAdaptiveInfoTile(
                context,
                leading: const Icon(Icons.link_outlined),
                title: 'GitHub 仓库',
                subtitle: _repositoryUrl.toString(),
                trailing: const Icon(Icons.open_in_new),
                onTap: _openRepository,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdaptiveDeveloperSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return _SettingsCard(
      isDarkMode: isDarkMode,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAdaptiveInfoTile(
            context,
            leading: const Icon(Icons.terminal_outlined),
            title: '终端输出',
            subtitle: '查看 print 和 debugPrint 的实时日志',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTerminalOutputDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveInfoTile(
    BuildContext context, {
    required Widget leading,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final TextStyle titleStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ) ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
    final TextStyle subtitleStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurfaceVariant,
        );

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconTheme.merge(
            data: const IconThemeData(size: 24),
            child: leading,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  locale: const Locale('zh-Hans', 'zh'),
                  style: titleStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  locale: const Locale('zh-Hans', 'zh'),
                  style: subtitleStyle,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            IconTheme.merge(
              data: const IconThemeData(size: 20),
              child: trailing,
            ),
          ],
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: theme.colorScheme.primary.withOpacity(0.08),
          highlightColor: theme.colorScheme.primary.withOpacity(0.04),
          child: child,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
    required this.isDarkMode,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final bool isDarkMode;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final baseCard = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1C1C1E).withOpacity(0.3)
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.4)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    return HoverGlowOverlay(
      isDarkMode: isDarkMode,
      borderRadius: BorderRadius.circular(16),
      blurSigma: 0,
      child: SizedBox(width: double.infinity, child: baseCard),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.isDarkMode,
  });

  final String title;
  final String subtitle;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          locale: Locale("zh-Hans", "zh"),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: titleColor,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            locale: Locale("zh-Hans", "zh"),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: subtitleColor,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.packageInfoFuture});

  final Future<PackageInfo> packageInfoFuture;

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.maybeOf(context);
    final TextStyle bodyStyle = macTheme?.typography.body ??
        DefaultTextStyle.of(context).style ??
        const TextStyle(fontSize: 14);

    return FutureBuilder<PackageInfo>(
      future: packageInfoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final appName = info?.appName.isNotEmpty == true
            ? info!.appName
            : 'Misuzu Music';
        final version = info?.version ?? '未知版本';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('项目名称：$appName', style: bodyStyle),
            const SizedBox(height: 8),
            Text('版本号：$version', style: bodyStyle),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openRepository,
              child: Text(
                'GitHub：${_repositoryUrl.toString()}',
                style: bodyStyle,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DeveloperOptionsList extends StatelessWidget {
  const _DeveloperOptionsList({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DeveloperOptionTile(
          title: '终端输出',
          subtitle: '查看 print 和 debugPrint 的实时日志',
          icon: Icons.terminal,
          isDarkMode: isDarkMode,
          onTap: () => _showTerminalOutputDialog(context),
        ),
      ],
    );
  }
}

class _DeveloperOptionTile extends StatelessWidget {
  const _DeveloperOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDarkMode,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = isDarkMode
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final Color iconColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.75);
    final Color titleColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.black.withValues(alpha: 0.9);
    final Color subtitleColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: background,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        locale: Locale("zh-Hans", "zh"),
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        locale: Locale("zh-Hans", "zh"),
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: iconColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showTerminalOutputDialog(BuildContext context) async {
  final collector = DeveloperLogCollector.instance;

  await showPlaylistModalDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final macTheme = MacosTheme.maybeOf(dialogContext);
      final brightness = macTheme?.brightness ?? theme.brightness;
      final isDark = brightness == Brightness.dark;

      return PlaylistModalScaffold(
        title: '终端输出',
        maxWidth: 720,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        body: _DeveloperLogsDialog(
          collector: collector,
          isDarkMode: isDark,
        ),
        actions: [
          TextButton(
            onPressed: collector.clear,
            child: const Text('清空'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

enum _DeveloperLogFilter { all, info, error }

class _DeveloperLogsDialog extends StatefulWidget {
  const _DeveloperLogsDialog({
    required this.collector,
    required this.isDarkMode,
  });

  final DeveloperLogCollector collector;
  final bool isDarkMode;

  @override
  State<_DeveloperLogsDialog> createState() => _DeveloperLogsDialogState();
}

class _DeveloperLogsDialogState extends State<_DeveloperLogsDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  _DeveloperLogFilter _filter = _DeveloperLogFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _setFilter(_DeveloperLogFilter filter) {
    if (_filter == filter) {
      return;
    }
    setState(() {
      _filter = filter;
    });
  }

  List<DeveloperLogEntry> _filterEntries(List<DeveloperLogEntry> logs) {
    final query = _searchController.text.trim().toLowerCase();
    return logs.where((entry) {
      if (_filter == _DeveloperLogFilter.info &&
          entry.level != DeveloperLogLevel.info) {
        return false;
      }
      if (_filter == _DeveloperLogFilter.error &&
          entry.level != DeveloperLogLevel.error) {
        return false;
      }
      if (query.isNotEmpty &&
          !entry.message.toLowerCase().contains(query) &&
          !entry.formattedTimestamp().toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _filterDescription(_DeveloperLogFilter filter) {
    return switch (filter) {
      _DeveloperLogFilter.all => '全部',
      _DeveloperLogFilter.info => '仅普通输出',
      _DeveloperLogFilter.error => '仅错误',
    };
  }

  IconData _filterIcon(_DeveloperLogFilter filter) {
    return switch (filter) {
      _DeveloperLogFilter.all => Icons.list_alt,
      _DeveloperLogFilter.info => Icons.bubble_chart,
      _DeveloperLogFilter.error => Icons.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color logBackground = widget.isDarkMode
        ? const Color(0xFF111111)
        : const Color(0xFFF4F4F4);
    final Color borderColor = widget.isDarkMode
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final TextStyle baseLogStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.85),
      height: 1.35,
    );
    final TextStyle errorStyle = baseLogStyle.copyWith(
      color: const Color(0xFFFF4D4F),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaHeight = MediaQuery.of(context).size.height;
        final double fallbackHeight = mediaHeight * 0.7;
        final double boundedHeight = constraints.hasBoundedHeight &&
                constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : fallbackHeight;
        final double maxHeight = boundedHeight.clamp(340.0, mediaHeight * 0.9);
        final double logViewportHeight = (maxHeight - 220).clamp(160.0, 360.0);

        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '展示应用启动以来所有 print 与 debugPrint 输出，可快速搜索或过滤。',
              locale: Locale("zh-Hans", "zh"),
              style: TextStyle(
                fontSize: 12,
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.66)
                    : Colors.black.withValues(alpha: 0.64),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜索',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.requestFocus();
                        },
                      ),
                hintText: '搜索日志内容或时间戳...',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_DeveloperLogFilter>(
              segments: _DeveloperLogFilter.values
                  .map(
                    (filter) => ButtonSegment<_DeveloperLogFilter>(
                      value: filter,
                      label: Text(
                        _filterDescription(filter),
                        locale: Locale("zh-Hans", "zh"),
                      ),
                      icon: Icon(_filterIcon(filter), size: 16),
                    ),
                  )
                  .toList(growable: false),
              selected: <_DeveloperLogFilter>{_filter},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }
                _setFilter(selection.first);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: logViewportHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: logBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ValueListenableBuilder<List<DeveloperLogEntry>>(
                    valueListenable: widget.collector.logsListenable,
                    builder: (context, logs, _) {
                      final filtered = _filterEntries(logs);

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            logs.isEmpty
                                ? '当前没有可显示的输出。'
                                : '没有匹配筛选条件的日志。',
                            locale: Locale("zh-Hans", "zh"),
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      }

                      final textSpan = TextSpan(
                        children: [
                          for (final entry in filtered)
                            TextSpan(
                              text:
                                  '[${entry.formattedTimestamp()}] ${entry.message}\n',
                              style: entry.level == DeveloperLogLevel.error
                                  ? errorStyle
                                  : baseLogStyle,
                            ),
                        ],
                      );

                      return Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          primary: false,
                          padding: const EdgeInsets.all(16),
                          child: SelectableText.rich(
                            textSpan,
                            style: baseLogStyle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<List<DeveloperLogEntry>>(
              valueListenable: widget.collector.logsListenable,
              builder: (context, logs, _) {
                final filtered = _filterEntries(logs);
                return Text(
                  '总计 ${logs.length} 条，筛选后 ${filtered.length} 条。',
                  locale: Locale("zh-Hans", "zh"),
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.58)
                        : Colors.black.withValues(alpha: 0.58),
                  ),
                );
              },
            ),
          ],
        );

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: column,
          ),
        );
      },
    );
  }
}

class _ThemeModeControl extends StatefulWidget {
  const _ThemeModeControl({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  State<_ThemeModeControl> createState() => _ThemeModeControlState();
}

class _ThemeModeControlState extends State<_ThemeModeControl> {
  static const _tabs = ['浅色', '深色', '系统'];
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _modeToIndex(widget.currentMode);
  }

  @override
  void didUpdateWidget(covariant _ThemeModeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _modeToIndex(widget.currentMode);
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final macTheme = MacosTheme.maybeOf(context);
    final materialTheme = Theme.of(context);
    final isDarkMode =
        (macTheme?.brightness ?? materialTheme.brightness) == Brightness.dark;
    final platform = materialTheme.platform;
    final bool useAdaptiveSegments =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    final baseTextStyle = macTheme?.typography.body ??
        materialTheme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);

    final label = Text(
      '主题模式',
      locale: const Locale('zh-Hans', 'zh'),
      style: baseTextStyle.copyWith(
        fontWeight: FontWeight.w500,
        color: isDarkMode
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.8),
      ),
    );

    if (useAdaptiveSegments) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          const SizedBox(height: 12),
          AdaptiveSegmentedControl(
            labels: _tabs,
            selectedIndex: _currentIndex,
            onValueChanged: _handleTap,
            height: 34,
            shrinkWrap: true,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        const SizedBox(height: 8),
        Container(
          width: 252,
          height: 24,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                alignment: _alignmentForIndex(_currentIndex),
                child: FractionallySizedBox(
                  widthFactor: 1 / _tabs.length,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_tabs.length, (index) {
                  final label = _tabs[index];
                  final isSelected = index == _currentIndex;
                  return SizedBox(
                    width: 84,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _handleTap(index),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: baseTextStyle.copyWith(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? (isDarkMode
                                    ? Colors.white
                                    : Colors.black.withOpacity(0.85))
                                : (isDarkMode
                                    ? Colors.white.withOpacity(0.85)
                                    : Colors.black.withOpacity(0.75)),
                          ),
                          child: Text(label,locale: Locale("zh-Hans", "zh"),),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleTap(int index) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    final mode = _indexToMode(index);
    if (mode != widget.currentMode) {
      widget.onChanged(mode);
    }
  }

  Alignment _alignmentForIndex(int index) {
    if (_tabs.length == 1) {
      return Alignment.center;
    }
    final step = 2 / (_tabs.length - 1);
    return Alignment(-1 + (step * index), 0);
  }

  int _modeToIndex(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 0;
      case ThemeMode.dark:
        return 1;
      case ThemeMode.system:
      default:
        return 2;
    }
  }

  ThemeMode _indexToMode(int index) {
    switch (index) {
      case 0:
        return ThemeMode.light;
      case 1:
        return ThemeMode.dark;
      case 2:
      default:
        return ThemeMode.system;
    }
  }
}
