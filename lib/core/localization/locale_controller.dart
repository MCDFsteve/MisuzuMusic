import 'package:flutter/widgets.dart';

import '../storage/binary_config_store.dart';
import '../storage/storage_keys.dart';

class LocaleController extends ChangeNotifier {
  LocaleController(this._configStore);

  final BinaryConfigStore _configStore;

  static const String _systemToken = 'system';

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    await _configStore.init();
    final stored = _configStore.getValue<String>(StorageKeys.locale);
    if (stored == null || stored == _systemToken) {
      _locale = null;
      return;
    }

    try {
      _locale = _decode(stored);
      notifyListeners();
    } catch (_) {
      _locale = null;
    }
  }

  Future<void> setLocale(Locale? locale) async {
    final next = _normalize(locale);
    final currentCode = _encodeWithSystem(_locale);
    final nextCode = _encodeWithSystem(next);
    if (currentCode == nextCode) {
      return;
    }

    _locale = next;
    if (next == null) {
      await _configStore.setValue(StorageKeys.locale, _systemToken);
    } else {
      await _configStore.setValue(StorageKeys.locale, _encode(next));
    }
    notifyListeners();
  }

  Locale? _normalize(Locale? locale) {
    if (locale == null) {
      return null;
    }

    switch (locale.languageCode) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        return Locale(locale.languageCode, locale.countryCode);
    }
  }

  String _encodeWithSystem(Locale? locale) {
    return locale == null ? _systemToken : _encode(locale);
  }

  String _encode(Locale locale) {
    final buffer = StringBuffer(locale.languageCode);
    final countryCode = locale.countryCode;
    if (countryCode != null && countryCode.isNotEmpty) {
      buffer
        ..write('_')
        ..write(countryCode);
    }
    return buffer.toString();
  }

  Locale _decode(String value) {
    final separatorIndex = value.indexOf('_');
    if (separatorIndex == -1) {
      return Locale(value);
    }
    final languageCode = value.substring(0, separatorIndex);
    final countryCode = value.substring(separatorIndex + 1);
    return Locale(languageCode, countryCode);
  }
}
