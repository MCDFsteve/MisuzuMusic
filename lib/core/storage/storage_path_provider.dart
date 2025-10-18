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

    final documentsDir = await getApplicationDocumentsDirectory();
    final targetPath = p.join(documentsDir.path, subdirectory);
    final targetDir = Directory(targetPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    _cachedBaseDir = targetDir;
    return targetDir;
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
