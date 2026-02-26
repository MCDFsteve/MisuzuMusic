import 'package:flutter/foundation.dart';

import '../storage/binary_config_store.dart';
import '../storage/storage_keys.dart';

class OnlineMetadataController extends ChangeNotifier {
  OnlineMetadataController(this._configStore);

  final BinaryConfigStore _configStore;

  bool _autoFetchLyrics = true;
  bool _autoFetchArtwork = true;

  bool get autoFetchLyrics => _autoFetchLyrics;
  bool get autoFetchArtwork => _autoFetchArtwork;

  Future<void> load() async {
    await _configStore.init();
    final storedLyrics = _configStore.getValue<bool>(StorageKeys.autoFetchLyrics);
    final storedArtwork =
        _configStore.getValue<bool>(StorageKeys.autoFetchArtwork);
    final nextLyrics = storedLyrics ?? true;
    final nextArtwork = storedArtwork ?? true;
    if (_autoFetchLyrics != nextLyrics || _autoFetchArtwork != nextArtwork) {
      _autoFetchLyrics = nextLyrics;
      _autoFetchArtwork = nextArtwork;
      notifyListeners();
    }
  }

  Future<void> setAutoFetchLyrics(bool value) async {
    if (_autoFetchLyrics == value) return;
    _autoFetchLyrics = value;
    await _configStore.setValue(StorageKeys.autoFetchLyrics, value);
    notifyListeners();
  }

  Future<void> setAutoFetchArtwork(bool value) async {
    if (_autoFetchArtwork == value) return;
    _autoFetchArtwork = value;
    await _configStore.setValue(StorageKeys.autoFetchArtwork, value);
    notifyListeners();
  }
}
