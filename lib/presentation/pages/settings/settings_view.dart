import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

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
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置',
                  style: MacosTheme.of(context).typography.largeTitle,
                ),
                const SizedBox(height: 24),
                _ThemeModeControl(
                  currentMode: mode,
                  onChanged: themeController.setThemeMode,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设置',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(CupertinoIcons.sun_max),
                  const SizedBox(width: 12),
                  const Text('主题模式'),
                  const Spacer(),
                  DropdownButton<ThemeMode>(
                    value: mode,
                    onChanged: (value) {
                      if (value != null) {
                        themeController.setThemeMode(value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('浅色模式'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('深色模式'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('跟随系统'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '主题模式',
          style: theme.typography.title3,
        ),
        const SizedBox(height: 8),
        Text(
          '选择浅色、深色或跟随系统',
          style: theme.typography.caption1.copyWith(
            color: MacosColors.systemGrayColor,
          ),
        ),
        const SizedBox(height: 12),
        MacosSegmentedControl(
          tabs: _tabs,
          controller: _controller,
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
