import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'core/di/dependency_injection.dart';
import 'core/theme/theme_controller.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window configuration (hidden title bar on all desktop platforms)
  await _configureWindow();

  // Initialize dependency injection
  await DependencyInjection.init();

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

        final materialTheme = ThemeData(
          useMaterial3: true,
          fontFamily: Platform.isWindows ? "微软雅黑" : null,
          brightness: materialBrightness,
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

        return MacosApp(
          title: 'Misuzu Music',
          debugShowCheckedModeBanner: false,
          theme: MacosThemeData.light(),
          darkTheme: MacosThemeData.dark(),
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
