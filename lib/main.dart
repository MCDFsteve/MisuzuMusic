import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'core/di/dependency_injection.dart';
import 'core/theme/theme_controller.dart';
import 'domain/services/audio_player_service.dart';
import 'domain/usecases/lyrics_usecases.dart';
import 'presentation/desktop/desktop_lyrics_controller.dart';
import 'presentation/desktop/desktop_lyrics_window.dart';
import 'presentation/pages/home_page.dart';

Future<void> _configureWindow() async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return;
  }

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1067, 600),
    minimumSize: Size(1067, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

bool _isDesktopLyricsEntry(List<String> args) {
  if (args.length < 3) {
    return false;
  }
  if (args[0] != 'multi_window') {
    return false;
  }
  try {
    final Map<String, dynamic> payload =
        jsonDecode(args[2]) as Map<String, dynamic>;
    return payload['entry'] == 'desktop_lyrics';
  } catch (_) {
    return false;
  }
}

Map<String, dynamic> _parseInitialArgs(List<String> args) {
  if (args.length < 3) {
    return const {};
  }
  try {
    return Map<String, dynamic>.from(
      jsonDecode(args[2]) as Map<String, dynamic>,
    );
  } catch (_) {
    return const {};
  }
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktopLyricsEntry(args)) {
    final int windowId = int.tryParse(args[1]) ?? 0;
    final Map<String, dynamic> initialArgs = _parseInitialArgs(args);
    await runDesktopLyricsWindow(windowId, initialArgs);
    return;
  }

  await _configureWindow();
  await DependencyInjection.init();

  DesktopLyricsController desktopLyricsController;
  if (sl.isRegistered<DesktopLyricsController>()) {
    desktopLyricsController = sl<DesktopLyricsController>();
  } else {
    desktopLyricsController = DesktopLyricsController(
      audioPlayerService: sl<AudioPlayerService>(),
      findLyricsFile: sl<FindLyricsFile>(),
      loadLyricsFromFile: sl<LoadLyricsFromFile>(),
      fetchOnlineLyrics: sl<FetchOnlineLyrics>(),
      getLyrics: sl<GetLyrics>(),
    );
    sl.registerSingleton<DesktopLyricsController>(desktopLyricsController);
  }
  await desktopLyricsController.init();

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
