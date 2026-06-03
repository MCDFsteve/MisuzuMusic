import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as path;

import 'track_field_normalizer.dart';

AudioMetadata readCorrectedAudioMetadata(File file, {required bool getImage}) {
  final extension = path.extension(file.path).toLowerCase();

  try {
    if (extension == '.mp3') {
      try {
        final rawMetadata = readAllMetadata(file, getImage: getImage);
        if (rawMetadata is Mp3Metadata) {
          return _audioMetadataFromMp3(file, rawMetadata);
        }
      } catch (_) {
        // Fall back to the generic reader for MP3 files without usable ID3.
      }
    }

    final metadata = readMetadata(file, getImage: getImage);
    if (extension == '.flac' && _needsFlacFallback(metadata, getImage)) {
      final fallback = _readFlacMetadataFallback(file, getImage: getImage);
      if (fallback != null) {
        return _mergeAudioMetadata(metadata, fallback);
      }
    }
    return metadata;
  } catch (_) {
    if (extension == '.flac') {
      final fallback = _readFlacMetadataFallback(file, getImage: getImage);
      if (fallback != null) {
        return fallback;
      }
    }
    rethrow;
  }
}

AudioMetadata _audioMetadataFromMp3(File file, Mp3Metadata metadata) {
  final audioMetadata = AudioMetadata(
    file: file,
    album: _nonEmpty(metadata.album),
    artist: _firstNonEmpty([
      metadata.leadPerformer,
      metadata.bandOrOrchestra,
      metadata.originalArtist,
    ]),
    bitrate: metadata.bitrate,
    discNumber: metadata.discNumber,
    duration: metadata.duration,
    language: _nonEmpty(metadata.languages),
    lyrics: _nonEmpty(metadata.lyric),
    sampleRate: metadata.samplerate,
    title: _nonEmpty(metadata.songName),
    totalDisc: metadata.totalDics,
    trackNumber: metadata.trackNumber,
    trackTotal: metadata.trackTotal,
    year: _yearFromMp3Metadata(metadata),
  );

  audioMetadata.genres = metadata.genres
      .map((genre) => genre.trim())
      .where((genre) => genre.isNotEmpty)
      .toList();
  audioMetadata.pictures = List<Picture>.of(metadata.pictures);

  final guestArtistFrame = metadata.customMetadata['GUEST ARTIST'];
  if (guestArtistFrame != null) {
    audioMetadata.performers.addAll(
      guestArtistFrame
          .split('/')
          .map((artist) => artist.trim())
          .where((artist) => artist.isNotEmpty),
    );
  }

  return audioMetadata;
}

DateTime? _yearFromMp3Metadata(Mp3Metadata metadata) {
  final year = metadata.originalReleaseYear ?? metadata.year;
  if (year == null || year <= 0) {
    return null;
  }
  return DateTime(year);
}

bool _needsFlacFallback(AudioMetadata metadata, bool getImage) {
  final missingDuration =
      metadata.duration == null || metadata.duration == Duration.zero;
  final missingPictures = getImage && metadata.pictures.isEmpty;
  return missingDuration || missingPictures;
}

AudioMetadata _mergeAudioMetadata(
  AudioMetadata primary,
  AudioMetadata fallback,
) {
  final metadata = AudioMetadata(
    file: primary.file,
    album: _firstNonEmpty([primary.album, fallback.album]),
    artist: _firstNonEmpty([primary.artist, fallback.artist]),
    bitrate: primary.bitrate ?? fallback.bitrate,
    discNumber: primary.discNumber ?? fallback.discNumber,
    duration: primary.duration != null && primary.duration! > Duration.zero
        ? primary.duration
        : fallback.duration,
    language: _firstNonEmpty([primary.language, fallback.language]),
    lyrics: _firstNonEmpty([primary.lyrics, fallback.lyrics]),
    sampleRate: primary.sampleRate ?? fallback.sampleRate,
    title: _firstNonEmpty([primary.title, fallback.title]),
    totalDisc: primary.totalDisc ?? fallback.totalDisc,
    trackNumber: primary.trackNumber ?? fallback.trackNumber,
    trackTotal: primary.trackTotal ?? fallback.trackTotal,
    year: primary.year ?? fallback.year,
  );

  metadata.genres = primary.genres.isNotEmpty
      ? List<String>.of(primary.genres)
      : List<String>.of(fallback.genres);
  metadata.pictures = primary.pictures.isNotEmpty
      ? List<Picture>.of(primary.pictures)
      : List<Picture>.of(fallback.pictures);
  metadata.performers.addAll(
    primary.performers.isNotEmpty ? primary.performers : fallback.performers,
  );
  return metadata;
}

AudioMetadata? _readFlacMetadataFallback(File file, {required bool getImage}) {
  final bytes = file.readAsBytesSync();
  final flacOffset = _findFlacMarker(bytes);
  if (flacOffset < 0) {
    return null;
  }

  final builder = _FlacMetadataBuilder();
  var offset = flacOffset + 4;
  var isLastBlock = false;

  while (!isLastBlock && offset + 4 <= bytes.length) {
    final header = bytes[offset];
    isLastBlock = (header & 0x80) != 0;
    final type = header & 0x7F;
    final length =
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    offset += 4;

    if (length < 0 || offset + length > bytes.length) {
      break;
    }

    switch (type) {
      case 0:
        _parseFlacStreamInfo(bytes, offset, length, builder, file);
        break;
      case 4:
        _parseFlacVorbisComments(
          bytes.sublist(offset, offset + length),
          builder,
          getImage: getImage,
        );
        break;
      case 6:
        if (getImage) {
          final picture = _parseFlacPictureBlock(
            bytes.sublist(offset, offset + length),
          );
          if (picture != null) {
            builder.pictures.add(picture);
          }
        }
        break;
    }

    offset += length;
  }

  return builder.toAudioMetadata(file);
}

int _findFlacMarker(Uint8List bytes) {
  if (_hasFlacMarkerAt(bytes, 0)) {
    return 0;
  }

  if (bytes.length >= 10 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    final id3Size =
        10 +
        ((bytes[6] & 0x7F) << 21) +
        ((bytes[7] & 0x7F) << 14) +
        ((bytes[8] & 0x7F) << 7) +
        (bytes[9] & 0x7F);
    if (_hasFlacMarkerAt(bytes, id3Size)) {
      return id3Size;
    }
  }

  final limit = bytes.length - 4 < 1024 * 1024 ? bytes.length - 4 : 1024 * 1024;
  for (var i = 0; i <= limit; i++) {
    if (_hasFlacMarkerAt(bytes, i)) {
      return i;
    }
  }
  return -1;
}

bool _hasFlacMarkerAt(Uint8List bytes, int offset) {
  return offset >= 0 &&
      offset + 4 <= bytes.length &&
      bytes[offset] == 0x66 &&
      bytes[offset + 1] == 0x4C &&
      bytes[offset + 2] == 0x61 &&
      bytes[offset + 3] == 0x43;
}

void _parseFlacStreamInfo(
  Uint8List bytes,
  int offset,
  int length,
  _FlacMetadataBuilder builder,
  File file,
) {
  if (length < 34 || offset + 18 > bytes.length) {
    return;
  }

  final sampleRate =
      (bytes[offset + 10] << 12) |
      (bytes[offset + 11] << 4) |
      (bytes[offset + 12] >> 4);
  final bitsPerSample =
      (((bytes[offset + 12] & 0x01) << 4) | (bytes[offset + 13] >> 4)) + 1;
  final totalSamples =
      ((bytes[offset + 13] & 0x0F) << 32) |
      (bytes[offset + 14] << 24) |
      (bytes[offset + 15] << 16) |
      (bytes[offset + 16] << 8) |
      bytes[offset + 17];

  if (sampleRate > 0) {
    builder.sampleRate = sampleRate;
  }
  if (sampleRate > 0 && totalSamples > 0) {
    final durationMs = totalSamples / sampleRate * 1000;
    builder.duration = Duration(milliseconds: durationMs.round());
    final seconds = builder.duration!.inMilliseconds / 1000;
    if (seconds > 0) {
      builder.bitrate = (file.lengthSync() * 8 / seconds).round();
    } else {
      builder.bitrate = bitsPerSample * sampleRate;
    }
  } else {
    builder.bitrate = bitsPerSample * sampleRate;
  }
}

void _parseFlacVorbisComments(
  Uint8List bytes,
  _FlacMetadataBuilder builder, {
  required bool getImage,
}) {
  if (bytes.length < 8) {
    return;
  }

  var offset = 0;
  final vendorLength = _readUint32LE(bytes, offset);
  offset += 4 + vendorLength;
  if (offset + 4 > bytes.length) {
    return;
  }

  final commentCount = _readUint32LE(bytes, offset);
  offset += 4;

  for (var i = 0; i < commentCount && offset + 4 <= bytes.length; i++) {
    final length = _readUint32LE(bytes, offset);
    offset += 4;
    if (length < 0 || offset + length > bytes.length) {
      break;
    }

    final comment = utf8.decode(bytes.sublist(offset, offset + length));
    offset += length;

    final separatorIndex = comment.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    final name = comment.substring(0, separatorIndex).trim().toUpperCase();
    final value = comment.substring(separatorIndex + 1).trim();
    if (value.isEmpty) {
      continue;
    }

    switch (name) {
      case 'TITLE':
        builder.title ??= value;
        break;
      case 'ARTIST':
        builder.artist = _appendDelimitedValue(builder.artist, value);
        break;
      case 'ALBUMARTIST':
      case 'ALBUM ARTIST':
        builder.artist ??= value;
        break;
      case 'ALBUM':
        builder.album ??= value;
        break;
      case 'TRACKNUMBER':
      case 'ITUNES_CDDB_TRACKNUMBER':
        builder.trackNumber ??= _parseLeadingInt(value);
        break;
      case 'TRACKTOTAL':
      case 'TOTALTRACKS':
        builder.trackTotal ??= _parseLeadingInt(value);
        break;
      case 'DISCNUMBER':
        builder.discNumber ??= _parseLeadingInt(value);
        break;
      case 'DISCTOTAL':
      case 'TOTALDISCS':
        builder.discTotal ??= _parseLeadingInt(value);
        break;
      case 'DATE':
        builder.year ??= _parseMetadataDate(value);
        break;
      case 'GENRE':
        builder.genres.add(value);
        break;
      case 'PERFORMER':
        builder.performers.add(value);
        break;
      case 'LYRICS':
      case 'LYRIC':
      case 'UNSYNCEDLYRICS':
      case 'UNSYNCED LYRICS':
        builder.lyrics ??= value;
        break;
      case 'METADATA_BLOCK_PICTURE':
        if (getImage) {
          final picture = _parseBase64FlacPicture(value);
          if (picture != null) {
            builder.pictures.add(picture);
          }
        }
        break;
    }
  }
}

Picture? _parseBase64FlacPicture(String value) {
  try {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    final bytes = base64.decode(normalized);
    return _parseFlacPictureBlock(Uint8List.fromList(bytes));
  } catch (_) {
    return null;
  }
}

Picture? _parseFlacPictureBlock(Uint8List bytes) {
  if (bytes.length < 32) {
    return null;
  }

  var offset = 0;
  final pictureType = _readUint32BE(bytes, offset);
  offset += 4;
  final mimeLength = _readUint32BE(bytes, offset);
  offset += 4;
  if (mimeLength < 0 || offset + mimeLength > bytes.length) {
    return null;
  }

  final mimeType = ascii.decode(bytes.sublist(offset, offset + mimeLength));
  offset += mimeLength;
  if (offset + 4 > bytes.length) {
    return null;
  }

  final descriptionLength = _readUint32BE(bytes, offset);
  offset += 4 + descriptionLength;
  if (descriptionLength < 0 || offset + 16 > bytes.length) {
    return null;
  }

  offset += 16;
  if (offset + 4 > bytes.length) {
    return null;
  }

  final dataLength = _readUint32BE(bytes, offset);
  offset += 4;
  if (dataLength <= 0 || offset + dataLength > bytes.length) {
    return null;
  }

  return Picture(
    bytes.sublist(offset, offset + dataLength),
    mimeType,
    _pictureTypeFromFlacValue(pictureType),
  );
}

PictureType _pictureTypeFromFlacValue(int value) {
  if (value >= 0 && value < PictureType.values.length) {
    return PictureType.values[value];
  }
  return PictureType.other;
}

int _readUint32BE(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

int _readUint32LE(Uint8List bytes, int offset) {
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

int? _parseLeadingInt(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(0)!);
}

DateTime? _parseMetadataDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed != null) {
    return parsed;
  }

  final year = RegExp(r'\d{4}').firstMatch(value)?.group(0);
  if (year == null) {
    return null;
  }
  return DateTime.tryParse(year);
}

String? _appendDelimitedValue(String? current, String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return current;
  }

  final existing = splitArtistNames(current ?? '');
  if (existing.any(
    (artist) => artist.toLowerCase() == normalized.toLowerCase(),
  )) {
    return current;
  }
  if (current == null || current.trim().isEmpty) {
    return normalized;
  }
  return '$current/$normalized';
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final normalized = _nonEmpty(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return null;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

class _FlacMetadataBuilder {
  String? title;
  String? artist;
  String? album;
  String? lyrics;
  DateTime? year;
  int? trackNumber;
  int? trackTotal;
  int? discNumber;
  int? discTotal;
  int? bitrate;
  int? sampleRate;
  Duration? duration;
  final List<String> genres = <String>[];
  final List<String> performers = <String>[];
  final List<Picture> pictures = <Picture>[];

  AudioMetadata toAudioMetadata(File file) {
    final metadata = AudioMetadata(
      file: file,
      album: album,
      artist: artist,
      bitrate: bitrate,
      discNumber: discNumber,
      duration: duration,
      lyrics: lyrics,
      sampleRate: sampleRate,
      title: title,
      totalDisc: discTotal,
      trackNumber: trackNumber,
      trackTotal: trackTotal,
      year: year,
    );
    metadata.genres = genres;
    metadata.performers.addAll(performers);
    metadata.pictures = pictures;
    return metadata;
  }
}
