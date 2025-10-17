import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'dart:ui' as ui;

import '../../../core/di/dependency_injection.dart';
import '../../../core/theme/theme_controller.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = sl<ThemeController>();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final mode = themeController.themeMode;

        if (defaultTargetPlatform == TargetPlatform.macOS) {
          return _MacOSSettingsView(
            currentMode: mode,
            onChanged: themeController.setThemeMode,
          );
        }

        return _MobileSettingsView(
          currentMode: mode,
          onChanged: themeController.setThemeMode,
        );
      },
    );
  }
}

class _MacOSSettingsView extends StatelessWidget {
  const _MacOSSettingsView({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
          sliver: SliverToBoxAdapter(
            child: _SettingsCard(
              isDarkMode: isDarkMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsSection(
                    title: '外观',
                    subtitle: '自定义应用的外观和主题',
                    icon: CupertinoIcons.paintbrush_fill,
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
          ),
        ),
      ],
    );
  }
}

class _MobileSettingsView extends StatelessWidget {
  const _MobileSettingsView({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          sliver: SliverToBoxAdapter(
            child: _SettingsCard(
              isDarkMode: isDarkMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsSection(
                    title: '外观',
                    subtitle: '自定义应用的外观和主题',
                    icon: CupertinoIcons.paintbrush_fill,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 20),
                  _MobileThemeModeControl(
                    currentMode: currentMode,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
    required this.isDarkMode,
  });

  final Widget child;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
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
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDarkMode,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.6);
    final iconColor = isDarkMode
        ? Colors.white.withOpacity(0.8)
        : Colors.black.withOpacity(0.7);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
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
  late MacosTabController _controller;

  static const _tabs = <MacosTab>[
    MacosTab(label: '浅色'),
    MacosTab(label: '深色'),
    MacosTab(label: '系统'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = MacosTabController(
      initialIndex: _modeToIndex(widget.currentMode),
      length: _tabs.length,
    )..addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant _ThemeModeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _modeToIndex(widget.currentMode);
    if (_controller.index != index) {
      _controller.index = index;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final mode = _indexToMode(_controller.index);
    if (mode != widget.currentMode) {
      widget.onChanged(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '主题模式',
            style: theme.typography.body.copyWith(
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: MacosSegmentedControl(
            tabs: _tabs,
            controller: _controller,
          ),
        ),
      ],
    );
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

class _MobileThemeModeControl extends StatelessWidget {
  const _MobileThemeModeControl({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '主题模式',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...ThemeMode.values.map((mode) => _ThemeOption(
              mode: mode,
              isSelected: mode == currentMode,
              onTap: () => onChanged(mode),
              isDarkMode: isDarkMode,
            )),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final title = _getModeTitle(mode);
    final description = _getModeDescription(mode);
    final icon = _getModeIcon(mode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1))
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black.withOpacity(0.6),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 20,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : Colors.black.withOpacity(0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getModeTitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  String _getModeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '使用浅色主题';
      case ThemeMode.dark:
        return '使用深色主题';
      case ThemeMode.system:
        return '根据系统设置自动切换';
    }
  }

  IconData _getModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return CupertinoIcons.sun_max_fill;
      case ThemeMode.dark:
        return CupertinoIcons.moon_fill;
      case ThemeMode.system:
        return CupertinoIcons.gear_alt_fill;
    }
  }
}
