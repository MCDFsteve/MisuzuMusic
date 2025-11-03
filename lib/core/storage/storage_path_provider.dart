import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoragePathProvider {
  StoragePathProvider({this.subdirectory = 'MisuzuMusic'});

  final String subdirectory;

  Directory? _cachedBaseDir;

  Future<Directory> ensureBaseDir() async {
    if (_cachedBaseDir != null) {
      return _cachedBaseDir!;
    }

    final targetDir = await _targetDirectory();
    if (!await targetDir.exists()) {
      final migratedDir = await _tryMigrateFromLegacy(targetDir);
      if (migratedDir != null) {
        _cachedBaseDir = migratedDir;
        return migratedDir;
      }

      await targetDir.create(recursive: true);
    }

    _cachedBaseDir = targetDir;
    return targetDir;
  }

  Future<Directory> _targetDirectory() async {
    final dataHome = await _resolveDataHome();
    final targetPath = p.join(dataHome.path, subdirectory);
    return Directory(targetPath);
  }

  Future<Directory?> _tryMigrateFromLegacy(Directory targetDir) async {
    final legacyDir = await _legacyDirectory();
    if (legacyDir == null || !await legacyDir.exists()) {
      return null;
    }

    try {
      await targetDir.parent.create(recursive: true);
      await legacyDir.rename(targetDir.path);
      return targetDir;
    } on FileSystemException {
      // rename may fail across volumes; fallback to copy
    }

    try {
      await targetDir.create(recursive: true);
      await _copyDirectory(legacyDir, targetDir);
      try {
        await legacyDir.delete(recursive: true);
      } catch (e) {
        stderr.writeln('⚠️ StoragePathProvider: 删除旧目录失败 -> $e');
      }
      return targetDir;
    } catch (e) {
      stderr.writeln('⚠️ StoragePathProvider: 迁移旧目录失败 -> $e');
      return null;
    }
  }

  Future<Directory?> _legacyDirectory() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      return Directory(p.join(documentsDir.path, subdirectory));
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _resolveDataHome() async {
    if (Platform.isLinux) {
      final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
      if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
        return Directory(xdgDataHome);
      }
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(p.join(home, '.local', 'share'));
      }
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(appData);
      }
    }

    // Fallback to the platform-provided application support directory.
    return await getApplicationSupportDirectory();
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        final newFile = File(newPath);
        await newFile.parent.create(recursive: true);
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newDir = Directory(newPath);
        if (!await newDir.exists()) {
          await newDir.create(recursive: true);
        }
        await _copyDirectory(entity, newDir);
      }
    }
  }

  Future<String> databasePath({String fileName = 'misuzu_music.db'}) async {
    final baseDir = await ensureBaseDir();
    return p.join(baseDir.path, fileName);
  }

  Future<File> configFile({String fileName = 'config.msz'}) async {
    final baseDir = await ensureBaseDir();
    return File(p.join(baseDir.path, fileName));
  }

  Future<File> resolveFile(String relativePath) async {
    final baseDir = await ensureBaseDir();
    return File(p.join(baseDir.path, relativePath));
  }
}
