import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'storage_path_provider.dart';

class BinaryConfigStore {
  BinaryConfigStore(this._pathProvider);

  static const List<int> _magic = [0x4d, 0x53, 0x5a, 0x43, 0x46, 0x47]; // "MSZCFG"
  static const int _version = 1;

  final StoragePathProvider _pathProvider;

  Map<String, dynamic> _cache = {};
  bool _initialized = false;
  Future<void>? _pendingFlush;

  Future<void> init() async {
    if (_initialized) return;
    final file = await _pathProvider.configFile();
    if (!await file.exists()) {
      _cache = {};
      _initialized = true;
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < _magic.length + 5) {
        throw const FormatException('Config file too small');
      }
      for (int i = 0; i < _magic.length; i++) {
        if (bytes[i] != _magic[i]) {
          throw const FormatException('Invalid config magic header');
        }
      }
      final version = bytes[_magic.length];
      if (version != _version) {
        throw FormatException('Unsupported config version: $version');
      }
      final lengthData = bytes.sublist(_magic.length + 1, _magic.length + 5);
      final length = ByteData.view(Uint8List.fromList(lengthData).buffer).getUint32(0, Endian.big);
      final payload = bytes.sublist(_magic.length + 5, _magic.length + 5 + length);
      final jsonString = utf8.decode(payload);
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        _cache = decoded;
      } else {
        throw const FormatException('Config payload is not a map');
      }
      _initialized = true;
    } catch (e) {
      // If anything goes wrong we reset to empty cache but keep existing file untouched
      _cache = {};
      _initialized = true;
      stderr.writeln('⚠️ Failed to read config, reverting to defaults: $e');
    }
  }

  T? getValue<T>(String key) {
    if (!_initialized) {
      throw StateError('BinaryConfigStore not initialized');
    }
    final value = _cache[key];
    return value is T ? value : null;
  }

  Future<void> setValue(String key, Object? value) async {
    await init();
    if (value == null) {
      _cache.remove(key);
    } else {
      _cache[key] = value;
    }
    await _scheduleFlush();
  }

  Future<void> remove(String key) async {
    await init();
    _cache.remove(key);
    await _scheduleFlush();
  }

  Future<void> clear() async {
    await init();
    _cache.clear();
    await _scheduleFlush();
  }

  Map<String, dynamic> dump() => Map<String, dynamic>.from(_cache);

  Future<void> _scheduleFlush() async {
    _pendingFlush ??= _flush();
    try {
      await _pendingFlush;
    } finally {
      _pendingFlush = null;
    }
  }

  Future<void> _flush() async {
    final file = await _pathProvider.configFile();
    final jsonString = json.encode(_cache);
    final payload = utf8.encode(jsonString);
    final header = <int>[]
      ..addAll(_magic)
      ..add(_version)
      ..addAll(_uint32ToBytes(payload.length));
    final bytes = Uint8List(header.length + payload.length)
      ..setAll(0, header)
      ..setAll(header.length, payload);

    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(file.path);
  }

  List<int> _uint32ToBytes(int value) {
    final buffer = ByteData(4);
    buffer.setUint32(0, value, Endian.big);
    return buffer.buffer.asUint8List();
  }
}
