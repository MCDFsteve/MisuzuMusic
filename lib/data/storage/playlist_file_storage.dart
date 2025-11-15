import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/storage/sandbox_path_codec.dart';
import '../../core/storage/storage_path_provider.dart';
import '../models/music_models.dart';

class PlaylistFileStorage {
  PlaylistFileStorage(this._pathProvider, this._sandboxPathCodec);

  static const _magic = [0x6d, 0x73, 0x7a]; // 'msz'
  static const int _version = 1;

  final StoragePathProvider _pathProvider;
  final SandboxPathCodec _sandboxPathCodec;

  Future<Directory> _ensureDirectory() async {
    return _pathProvider.ensureBaseDir();
  }

  Future<List<PlaylistModel>> loadAllPlaylists() async {
    final dir = await _ensureDirectory();
    if (!await dir.exists()) {
      return const [];
    }

    final results = <PlaylistModel>[];
    await for (final entity in dir.list()) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (!name.startsWith('msz_') || !name.endsWith('.msz')) {
        continue;
      }
      final model = await _readPlaylistFile(entity);
      if (model != null) {
        results.add(model);
      }
    }

    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  Future<PlaylistModel?> loadPlaylist(String id) async {
    final file = await _fileForId(id);
    if (!await file.exists()) {
      return null;
    }
    return _readPlaylistFile(file);
  }

  Future<Uint8List?> exportPlaylistBytes(String id) async {
    final file = await _fileForId(id);
    if (!await file.exists()) {
      return null;
    }
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<PlaylistModel?> importPlaylistBytes(Uint8List bytes) async {
    final model = _parsePlaylistBytes(bytes);
    if (model == null) {
      return null;
    }
    final decoded = await _decodeStoredPaths(model);
    final file = await _fileForId(decoded.id);
    final normalizedBytes = await _encodePlaylistBytes(decoded);
    await file.writeAsBytes(normalizedBytes, flush: true);
    return decoded;
  }

  Future<void> savePlaylist(PlaylistModel playlist) async {
    final file = await _fileForId(playlist.id);
    final bytes = await _encodePlaylistBytes(playlist);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> deletePlaylist(String id) async {
    final file = await _fileForId(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _fileForId(String id) async {
    final dir = await _ensureDirectory();
    return File(p.join(dir.path, 'msz_$id.msz'));
  }

  Future<PlaylistModel?> _readPlaylistFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final parsed = _parsePlaylistBytes(bytes);
      if (parsed == null) {
        return null;
      }
      return _decodeStoredPaths(parsed);
    } catch (_) {
      return null;
    }
  }

  Future<PlaylistModel> _decodeStoredPaths(PlaylistModel playlist) async {
    final coverPath = playlist.coverPath;
    if (coverPath == null || coverPath.isEmpty) {
      return playlist;
    }
    final decoded = await _sandboxPathCodec.decode(coverPath);
    if (decoded == coverPath) {
      return playlist;
    }
    return playlist.copyWith(coverPath: decoded);
  }

  PlaylistModel? _parsePlaylistBytes(Uint8List bytes) {
    if (bytes.length < 4) {
      return null;
    }
    final data = ByteData.sublistView(bytes);
    int offset = 0;

    if (bytes[0] != _magic[0] ||
        bytes[1] != _magic[1] ||
        bytes[2] != _magic[2]) {
      return null;
    }
    offset += _magic.length;

    final version = data.getUint8(offset);
    offset += 1;
    if (version != _version) {
      return null;
    }

    final idResult = _readString(bytes, offset);
    final id = idResult.$1;
    offset = idResult.$2;
    if (id == null) {
      return null;
    }

    final nameResult = _readString(bytes, offset);
    final name = nameResult.$1 ?? 'Playlist';
    offset = nameResult.$2;

    final descriptionResult = _readString(bytes, offset);
    final description = descriptionResult.$1;
    offset = descriptionResult.$2;

    final coverResult = _readString(bytes, offset);
    final coverPath = coverResult.$1;
    offset = coverResult.$2;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      data.getInt64(offset, Endian.little),
    );
    offset += 8;
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      data.getInt64(offset, Endian.little),
    );
    offset += 8;

    final trackCount = data.getUint32(offset, Endian.little);
    offset += 4;

    final trackIds = <String>[];
    for (var i = 0; i < trackCount; i++) {
      final trackResult = _readString(bytes, offset);
      final hash = trackResult.$1;
      offset = trackResult.$2;
      if (hash != null) {
        trackIds.add(hash);
      }
    }

    return PlaylistModel(
      id: id,
      name: name,
      trackIds: trackIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
      description: description,
      coverPath: coverPath,
    );
  }

  Future<Uint8List> _encodePlaylistBytes(PlaylistModel playlist) async {
    final coverPath = playlist.coverPath;
    if (coverPath == null || coverPath.isEmpty) {
      return _encodePlaylist(playlist);
    }

    final encoded = await _sandboxPathCodec.encode(coverPath);
    if (encoded == coverPath) {
      return _encodePlaylist(playlist);
    }

    final normalized = playlist.copyWith(coverPath: encoded);
    return _encodePlaylist(normalized);
  }

  Uint8List _encodePlaylist(PlaylistModel playlist) {
    final builder = BytesBuilder();
    builder.add(_magic);
    builder.add([_version]);

    _writeString(builder, playlist.id);
    _writeString(builder, playlist.name);
    _writeString(builder, playlist.description);
    _writeString(builder, playlist.coverPath);

    builder.add(_encodeInt64(playlist.createdAt.millisecondsSinceEpoch));
    builder.add(_encodeInt64(playlist.updatedAt.millisecondsSinceEpoch));

    builder.add(_encodeUint32(playlist.trackIds.length));
    for (final hash in playlist.trackIds) {
      _writeString(builder, hash);
    }

    return builder.toBytes();
  }

  void _writeString(BytesBuilder builder, String? value) {
    if (value == null) {
      builder.add(_encodeUint32(0xFFFFFFFF));
      return;
    }
    final bytes = utf8.encode(value);
    builder.add(_encodeUint32(bytes.length));
    builder.add(bytes);
  }

  (String?, int) _readString(Uint8List bytes, int offset) {
    final data = ByteData.sublistView(bytes);
    final length = data.getUint32(offset, Endian.little);
    offset += 4;
    if (length == 0xFFFFFFFF) {
      return (null, offset);
    }
    final end = offset + length;
    final slice = bytes.sublist(offset, end);
    return (utf8.decode(slice), end);
  }

  Uint8List _encodeUint32(int value) {
    final bytes = Uint8List(4);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, value, Endian.little);
    return bytes;
  }

  Uint8List _encodeInt64(int value) {
    final bytes = Uint8List(8);
    final data = ByteData.sublistView(bytes);
    data.setInt64(0, value, Endian.little);
    return bytes;
  }
}
