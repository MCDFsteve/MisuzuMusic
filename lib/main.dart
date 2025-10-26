import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:window_manager_plus/window_manager_plus.dart';

import 'core/di/dependency_injection.dart';
import 'core/theme/theme_controller.dart';
import 'presentation/desktop/desktop_lyrics_controller.dart';
import 'presentation/desktop/desktop_lyrics_window.dart';
import 'presentation/pages/home_page.dart';

Future<void> _configureMainWindow() async {
  if (!(Platform.isMacOS || Platform.isWindows)) {
    return;
  }

  final bool isMacOS = Platform.isMacOS;
  final windowOptions = WindowOptions(
    size: Size(1067, 600),
    minimumSize: Size(1067, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: isMacOS,
  );

  await WindowManagerPlus.current.waitUntilReadyToShow(windowOptions, () async {
    await WindowManagerPlus.current.show();
    await WindowManagerPlus.current.focus();
  });
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool isSupportedDesktop = Platform.isMacOS || Platform.isWindows;
  final int windowId = isSupportedDesktop && args.isNotEmpty
      ? int.tryParse(args[0]) ?? 0
      : 0;

  if (isSupportedDesktop) {
    await WindowManagerPlus.ensureInitialized(windowId);

    final List<String> windowArgs = args.length > 1 ? args.sublist(1) : const [];
    if (windowId != 0 && windowArgs.isNotEmpty && windowArgs.first == 'desktop_lyrics') {
      final String? rawState = windowArgs.length > 1 ? windowArgs[1] : null;
      final Map<String, dynamic> initialState;
      if (rawState == null || rawState.isEmpty) {
        initialState = const {};
      } else {
        final decoded = jsonDecode(rawState);
        initialState = decoded is Map<String, dynamic>
            ? Map<String, dynamic>.from(decoded)
            : const {};
      }
      await runDesktopLyricsWindow(windowId, initialState);
      return;
    }

    await _configureMainWindow();
  }

  await DependencyInjection.init();

  if (isSupportedDesktop && sl.isRegistered<DesktopLyricsController>()) {
    await sl<DesktopLyricsController>().init();
  }

  runApp(const MisuzuMusicApp());
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
          ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
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
                typography: _createWindowsTypography(MacosThemeData.light().typography),
              )
            : MacosThemeData.light();

        final macosDarkTheme = Platform.isWindows
            ? MacosThemeData.dark().copyWith(
                typography: _createWindowsTypography(MacosThemeData.dark().typography),
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
