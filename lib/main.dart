import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:macos_ui/macos_ui.dart';

import 'core/di/dependency_injection.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await DependencyInjection.init();

  runApp(const MisuzuMusicApp());
}

class MisuzuMusicApp extends StatelessWidget {
  const MisuzuMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 根据平台选择不同的UI框架
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return MacosApp(
        title: 'Misuzu Music',
        debugShowCheckedModeBanner: false,
        theme: MacosThemeData.light(),
        darkTheme: MacosThemeData.dark(),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      );
    } else {
      // 其他平台使用Material Design
      return MaterialApp(
        title: 'Misuzu Music',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      );
    }
  }
}
