import 'package:flutter/material.dart';

import '../storage/binary_config_store.dart';
import '../storage/storage_keys.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._configStore);

  final BinaryConfigStore _configStore;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    await _configStore.init();
    final stored = _configStore.getValue<String>(StorageKeys.themeMode);
    if (stored != null) {
      _themeMode = _decode(stored);
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _configStore.setValue(StorageKeys.themeMode, _encode(mode));
    notifyListeners();
  }

  String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  ThemeMode _decode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
