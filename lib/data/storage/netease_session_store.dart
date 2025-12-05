import 'dart:convert';
import 'dart:io';

import '../../core/storage/storage_path_provider.dart';
import '../models/netease_models.dart';

class NeteaseSessionStore {
  NeteaseSessionStore(this._pathProvider);

  static const String _fileName = 'netease_session.json';

  final StoragePathProvider _pathProvider;

  Future<File> _resolveFile() async {
    return _pathProvider.resolveFile(_fileName);
  }

  Future<NeteaseCachePayload> loadCache() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return NeteaseCachePayload.empty();
      }
      final bytes = await file.readAsBytes();
      return NeteaseCachePayload.fromBytes(bytes);
    } catch (e) {
      //print('⚠️ NeteaseSessionStore: 读取缓存失败 -> $e');
      return NeteaseCachePayload.empty();
    }
  }

  Future<void> saveCache(NeteaseCachePayload payload) async {
    try {
      final file = await _resolveFile();
      final jsonBytes = utf8.encode(jsonEncode(payload.toJson()));
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsBytes(jsonBytes, flush: true);
      await tmpFile.rename(file.path);
    } catch (e) {
      //print('⚠️ NeteaseSessionStore: 写入缓存失败 -> $e');
    }
  }

  Future<void> clear() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      //print('⚠️ NeteaseSessionStore: 清理缓存失败 -> $e');
    }
  }
}
