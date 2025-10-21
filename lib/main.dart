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
        return MacosApp(
          title: 'Misuzu Music',
          debugShowCheckedModeBanner: false,
          theme: MacosThemeData.light(),
          darkTheme: MacosThemeData.dark(),
          themeMode: themeController.themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
