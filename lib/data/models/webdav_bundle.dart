import 'dart:convert';
import 'dart:typed_data';

class WebDavBundleEntry {
  WebDavBundleEntry({
    required this.trackId,
    required this.relativePath,
    required this.metadata,
    required this.artwork,
    required this.playCount,
    required this.lastPlayTimestampMs,
  });

  final String trackId;
  final String relativePath;
  final Map<String, dynamic> metadata;
  final Uint8List? artwork;
  final int playCount;
  final int lastPlayTimestampMs;
}

class WebDavBundleParser {
  static const _magic = 0x42444d4d; // 'MMDB'
  static const _version = 1;

  const WebDavBundleParser();

  List<WebDavBundleEntry> parse(Uint8List bytes) {
    final reader = _BinaryReader(bytes);
    final magic = reader.readUint32();
    if (magic != _magic) {
      throw const FormatException('Invalid metadata bundle magic.');
    }

    final version = reader.readUint16();
    if (version != _version) {
      throw FormatException('Unsupported bundle version: $version');
    }

    reader.readUint16(); // flags, reserved
    reader.readUint64(); // timestamp
    final count = reader.readUint32();

    final entries = <WebDavBundleEntry>[];
    for (var i = 0; i < count; i++) {
      final keyLen = reader.readUint16();
      final keyBytes = reader.readBytes(keyLen);
      final relativePath = utf8.decode(keyBytes);

      final hashLen = reader.readUint8();
      final trackId = utf8.decode(reader.readBytes(hashLen));

      final metadataSize = reader.readUint32();
      final metadataBytes = reader.readBytes(metadataSize);
      final metadata = json.decode(utf8.decode(metadataBytes))
          as Map<String, dynamic>;

      final artworkSize = reader.readUint32();
      Uint8List? artwork;
      if (artworkSize > 0) {
        artwork = Uint8List.fromList(reader.readBytes(artworkSize));
      }

      final playCount = reader.readUint32();
      final lastPlayed = reader.readUint64();

      final normalizedPath = metadata['relative_path'] as String? ?? relativePath;

      entries.add(
        WebDavBundleEntry(
          trackId: trackId,
          relativePath: normalizedPath,
          metadata: metadata,
          artwork: artwork,
          playCount: playCount,
          lastPlayTimestampMs: lastPlayed,
        ),
      );
    }

    return entries;
  }
}

class _BinaryReader {
  _BinaryReader(Uint8List data)
      : _view = data.buffer.asByteData(),
        _buffer = data,
        _offset = 0;

  final ByteData _view;
  final Uint8List _buffer;
  int _offset;

  Uint8List readBytes(int length) {
    if (_offset + length > _buffer.length) {
      throw const FormatException('Unexpected end of metadata bundle');
    }
    final bytes = _buffer.sublist(_offset, _offset + length);
    _offset += length;
    return bytes;
  }

  int readUint8() => _readInteger(1, (b, o) => b.getUint8(o));
  int readUint16() => _readInteger(2, (b, o) => b.getUint16(o, Endian.little));
  int readUint32() => _readInteger(4, (b, o) => b.getUint32(o, Endian.little));
  int readUint64() {
    final low = readUint32();
    final high = readUint32();
    return (high << 32) | low;
  }

  int _readInteger(int size, int Function(ByteData, int) reader) {
    if (_offset + size > _buffer.length) {
      throw const FormatException('Unexpected end of metadata bundle');
    }
    final value = reader(_view, _offset);
    _offset += size;
    return value;
  }
}
