import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'core/di/dependency_injection.dart';
import 'core/theme/theme_controller.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/desktop_lyrics/desktop_lyrics_window_app.dart';
import 'presentation/desktop_lyrics/desktop_lyrics_window_manager.dart';
import 'presentation/desktop_lyrics/desktop_lyrics_server.dart';
import 'presentation/developer/developer_log_collector.dart';

Future<void> _configureMainWindow() async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return;
  }

  final bool isMacOS = Platform.isMacOS;
  final bool isWindows = Platform.isWindows;
  final bool isLinux = Platform.isLinux;

  final windowOptions = wm.WindowOptions(
    size: const Size(1067, 600),
    minimumSize: const Size(1067, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: (isMacOS || isWindows) ? wm.TitleBarStyle.hidden : null,
    windowButtonVisibility: isMacOS,
  );

  await wm.windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (isWindows || isLinux) {
      try {
        await wm.windowManager.setAsFrameless();
      } catch (error) {
        debugPrint('跳过 setAsFrameless: $error');
      }
    }
    await wm.windowManager.show();
    await wm.windowManager.focus();
  });
}

Future<void> main(List<String> args) async {
  final logCollector = DeveloperLogCollector.instance;
  logCollector.initialize();

  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (_maybeHandleSubWindow(args)) {
        return;
      }

      final bool isSupportedDesktop =
          Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      if (isSupportedDesktop) {
        await wm.windowManager.ensureInitialized();
        DesktopLyricsWindowManager.instance.initialize();
        await DesktopLyricsServer.instance.start();
        await _configureMainWindow();
      }

      await DependencyInjection.init();

      runApp(const MisuzuMusicApp());
    },
    (error, stackTrace) {
      logCollector.addError(error, stackTrace);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (!logCollector.isSuppressingPrints) {
          logCollector.addMessage(line);
        }
        parent.print(zone, line);
      },
    ),
  );
}

bool _maybeHandleSubWindow(List<String> args) {
  if (args.isEmpty || args.first != 'multi_window') {
    return false;
  }

  if (args.length < 2) {
    return false;
  }

  final windowId = int.tryParse(args[1]);
  if (windowId == null) {
    return false;
  }

  final payload = args.length > 2 && args[2].isNotEmpty
      ? jsonDecode(args[2]) as Map<String, dynamic>
      : const <String, dynamic>{};

  final kind = payload['kind'] as String?;
  if (kind == 'lyrics') {
    final controller = WindowController.fromWindowId(windowId);
    unawaited(runDesktopLyricsWindow(controller, payload));
    return true;
  }

  return false;
}

class MisuzuMusicApp extends StatelessWidget {
  const MisuzuMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = sl<ThemeController>();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final materialBrightness = switch (themeController.themeMode) {
          ThemeMode.dark => Brightness.dark,
          ThemeMode.light => Brightness.light,
          ThemeMode.system =>
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
        };

        // Windows 平台使用微软雅黑，避免字体显示不一致
        final fontFamily = Platform.isWindows ? 'Microsoft YaHei' : null;

        final materialTheme = ThemeData(
          useMaterial3: true,
          brightness: materialBrightness,
          fontFamily: fontFamily,
          colorScheme: materialBrightness == Brightness.dark
              ? const ColorScheme.dark(
                  primary: Color(0xFF3E73FF),
                  secondary: Color(0xFF3E73FF),
                )
              : const ColorScheme.light(
                  primary: Color(0xFF1B66FF),
                  secondary: Color(0xFF1B66FF),
                ),
        );

        // Windows 平台为 MacosThemeData 设置微软雅黑字体
        final macosLightTheme = Platform.isWindows
            ? MacosThemeData.light().copyWith(
                typography: _createWindowsTypography(
                  MacosThemeData.light().typography,
                ),
              )
            : MacosThemeData.light();

        final macosDarkTheme = Platform.isWindows
            ? MacosThemeData.dark().copyWith(
                typography: _createWindowsTypography(
                  MacosThemeData.dark().typography,
                ),
              )
            : MacosThemeData.dark();

        return MacosApp(
          title: 'Misuzu Music',
          debugShowCheckedModeBanner: false,
          theme: macosLightTheme,
          darkTheme: macosDarkTheme,
          themeMode: themeController.themeMode,
          home: const HomePage(),
          builder: (context, child) {
            return Theme(
              data: materialTheme,
              child: ScaffoldMessenger(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Material(
                    type: MaterialType.transparency,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 为 Windows 平台创建使用微软雅黑字体的 MacosTypography
MacosTypography _createWindowsTypography(MacosTypography original) {
  const fontFamily = 'Microsoft YaHei';
  return MacosTypography.raw(
    largeTitle: original.largeTitle.copyWith(fontFamily: fontFamily),
    title1: original.title1.copyWith(fontFamily: fontFamily),
    title2: original.title2.copyWith(fontFamily: fontFamily),
    title3: original.title3.copyWith(fontFamily: fontFamily),
    headline: original.headline.copyWith(fontFamily: fontFamily),
    subheadline: original.subheadline.copyWith(fontFamily: fontFamily),
    body: original.body.copyWith(fontFamily: fontFamily),
    callout: original.callout.copyWith(fontFamily: fontFamily),
    footnote: original.footnote.copyWith(fontFamily: fontFamily),
    caption1: original.caption1.copyWith(fontFamily: fontFamily),
    caption2: original.caption2.copyWith(fontFamily: fontFamily),
  );
}
