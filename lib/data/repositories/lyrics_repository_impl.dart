import 'dart:io';
import 'package:misuzu_music/core/constants/app_constants.dart';
import 'package:path/path.dart' as path;

import '../../core/error/exceptions.dart';
import '../../domain/entities/lyrics_entities.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../datasources/local/lyrics_local_datasource.dart';
import '../datasources/remote/netease_api_client.dart';
import '../models/lyrics_models.dart';
import '../services/remote_lyrics_api.dart';

class LyricsRepositoryImpl implements LyricsRepository {
  final LyricsLocalDataSource _localDataSource;
  final NeteaseApiClient _neteaseApiClient;
  final RemoteLyricsApi _remoteLyricsApi;

  LyricsRepositoryImpl({
    required LyricsLocalDataSource localDataSource,
    required NeteaseApiClient neteaseApiClient,
    required RemoteLyricsApi remoteLyricsApi,
  })  : _localDataSource = localDataSource,
        _neteaseApiClient = neteaseApiClient,
        _remoteLyricsApi = remoteLyricsApi;

  @override
  Future<Lyrics?> getLyricsByTrackId(String trackId) async {
    try {
      final lyricsModel = await _localDataSource.getLyricsByTrackId(trackId);
      return lyricsModel?.toEntity();
    } catch (e) {
      throw DatabaseException('Failed to get lyrics: ${e.toString()}');
    }
  }

  @override
  Future<void> saveLyrics(Lyrics lyrics) async {
    try {
      final lyricsModel = LyricsModel.fromEntity(lyrics);

      final existingLyrics = await _localDataSource.getLyricsByTrackId(
        lyrics.trackId,
      );
      if (existingLyrics != null) {
        await _localDataSource.updateLyrics(lyricsModel);
      } else {
        await _localDataSource.insertLyrics(lyricsModel);
      }
    } catch (e) {
      throw DatabaseException('Failed to save lyrics: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteLyrics(String trackId) async {
    try {
      await _localDataSource.deleteLyrics(trackId);
    } catch (e) {
      throw DatabaseException('Failed to delete lyrics: ${e.toString()}');
    }
  }

  @override
  Future<String?> findLyricsFile(String audioFilePath) async {
    try {
      final audioFile = File(audioFilePath);
      final directory = audioFile.parent;
      final baseName = path.basenameWithoutExtension(audioFilePath);

      // Common lyrics file extensions
      final lyricsExtensions = ['.lrc', '.txt'];

      // Primary attempt: exact match with full base name
      for (final extension in lyricsExtensions) {
        final lyricsPath = path.join(directory.path, '$baseName$extension');
        final lyricsFile = File(lyricsPath);
        if (lyricsFile.existsSync()) {
          return lyricsPath;
        }
      }

      // Secondary attempt: allow matching by title segment when filename is like
      // "Artist - Title" but lyrics file only contains "Title".
      final normalizedTargets = _buildNormalizedTitleCandidates(baseName);
      final candidateFiles = directory
          .listSync(followLinks: false)
          .whereType<File>()
          .where(
            (file) => lyricsExtensions.any(
              (ext) => file.path.toLowerCase().endsWith(ext),
            ),
          )
          .toList();

      for (final file in candidateFiles) {
        final filename = path.basenameWithoutExtension(file.path);
        final normalizedName = _normalizeFilename(filename);
        final variants = <String>{
          normalizedName,
          _withoutSpaces(normalizedName),
        };
        if (variants.any(normalizedTargets.contains)) {
          return file.path;
        }
      }

      return null;
    } catch (e) {
      throw FileSystemException('Failed to find lyrics file: ${e.toString()}');
    }
  }

  Set<String> _buildNormalizedTitleCandidates(String baseName) {
    final candidates = <String>{};
    final normalizedFull = _normalizeFilename(baseName);
    if (normalizedFull.isNotEmpty) {
      candidates.add(normalizedFull);
      candidates.add(_withoutSpaces(normalizedFull));
    }

    final separators = [' - ', '-', ' – ', ' — ', ' _ ', '_', ':', '：'];
    for (final separator in separators) {
      if (baseName.contains(separator)) {
        final parts = baseName.split(separator);
        for (final part in parts) {
          final normalizedPart = _normalizeFilename(part);
          if (normalizedPart.length >= 2) {
            candidates.add(normalizedPart);
            candidates.add(_withoutSpaces(normalizedPart));
          }
        }
      }
    }

    return candidates;
  }

  String _normalizeFilename(String input) {
    final primary = input.toLowerCase().trim();

    final buffer = StringBuffer();
    for (final rune in primary.runes) {
      final char = String.fromCharCode(rune);
      if (_isFilenameWordChar(char)) {
        buffer.write(char);
      } else {
        buffer.write(' ');
      }
    }

    final result = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isFilenameWordChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    final isAsciiLower = code >= 97 && code <= 122;
    final isDigit = code >= 48 && code <= 57;
    final isCjkUnified =
        (code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF);
    final isHiragana = code >= 0x3040 && code <= 0x309F;
    final isKatakana = code >= 0x30A0 && code <= 0x30FF;
    final isCommonKanji = char == '々' || char == '〆' || char == '〤';

    return isAsciiLower ||
        isDigit ||
        isCjkUnified ||
        isHiragana ||
        isKatakana ||
        isCommonKanji;
  }

  String _withoutSpaces(String input) => input.replaceAll(' ', '');

  @override
  Future<Lyrics?> loadLyricsFromFile(String filePath, String trackId) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileSystemException('Lyrics file not found: $filePath');
      }

      final content = await file.readAsString();
      final extension = path.extension(filePath).toLowerCase();

      LyricsFormat format;
      List<LyricsLine> lines;

      if (extension == '.lrc') {
        format = LyricsFormat.lrc;
        lines = _parseLrcContent(content);
      } else {
        format = LyricsFormat.text;
        lines = _parseTextContent(content);
      }

      return Lyrics(trackId: trackId, lines: lines, format: format);
    } catch (e) {
      throw LyricsException('Failed to load lyrics from file: ${e.toString()}');
    }
  }

  @override
  Future<bool> hasLyrics(String trackId) async {
    try {
      return await _localDataSource.hasLyrics(trackId);
    } catch (e) {
      throw DatabaseException(
        'Failed to check lyrics existence: ${e.toString()}',
      );
    }
  }

  @override
  Future<Lyrics?> fetchOnlineLyrics({
    required String trackId,
    required String title,
    String? artist,
    bool cloudOnly = false,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return null;
    }

    try {
      if (cloudOnly) {
        return await _fetchLyricsFromRemoteLibrary(
          trackId: trackId,
          title: trimmedTitle,
          artist: artist,
        );
      }

      final Lyrics? remoteLyrics = await _fetchLyricsFromRemoteLibrary(
        trackId: trackId,
        title: trimmedTitle,
        artist: artist,
      );
      if (remoteLyrics != null) {
        return remoteLyrics;
      }

      final songId = await _neteaseApiClient.searchSongId(
        title: trimmedTitle,
        artist: artist?.trim(),
      );
      if (songId == null) {
        return null;
      }

      final lyricResult = await _neteaseApiClient.fetchLyricsBySongId(songId);
      if (lyricResult == null || !lyricResult.hasOriginal) {
        return null;
      }

      final String originalContent = lyricResult.original ?? '';
      final List<LyricsLine> mergedLines = _mergeNeteaseLyrics(
        originalContent,
        lyricResult.translated,
      );

      if (mergedLines.isEmpty) {
        return null;
      }

      final lyrics = Lyrics(
        trackId: trackId,
        lines: mergedLines,
        format: LyricsFormat.lrc,
      );

      await saveLyrics(lyrics);
      return await getLyricsByTrackId(trackId);
    } catch (e) {
      print('⚠️ LyricsRepository: 在线歌词获取失败 -> $e');
      return null;
    }
  }

  Future<Lyrics?> _fetchLyricsFromRemoteLibrary({
    required String trackId,
    required String title,
    String? artist,
  }) async {
    try {
      final available = await _remoteLyricsApi.listAvailableLyrics();
      if (available.isEmpty) {
        return null;
      }

      print('🎼 LyricsRepository: 云端可用歌词 ${available.length} 个');
      for (final entry in available) {
        print('  • $entry');
      }

      final normalizedAvailable = <MapEntry<String, String>>[
        for (final file in available)
          MapEntry<String, String>(file, _normalizeForLooseCompare(file)),
      ];

      final Map<String, List<String>> normalizedMap = {};
      for (final file in available) {
        final baseName = file.toLowerCase().endsWith('.lrc')
            ? file.substring(0, file.length - 4)
            : file;
        final key = _sanitizeForComparison(baseName);
        if (key.isEmpty) {
          continue;
        }
        normalizedMap.putIfAbsent(key, () => []).add(file);
      }

      final candidateKeys = _buildCandidateKeys(title, artist);
      for (var candidate in candidateKeys) {
        if (!candidate.toLowerCase().endsWith('.lrc')) {
          candidate = '$candidate.lrc';
        }

        final looseCandidate = _normalizeForLooseCompare(candidate);
        final directEntry = normalizedAvailable.firstWhere(
          (entry) => entry.value == looseCandidate,
          orElse: () => const MapEntry<String, String>('', ''),
        );

        String? matchedFile = directEntry.key.isNotEmpty ? directEntry.key : null;
        if (matchedFile == null) {
          final normalizedKey = _sanitizeForComparison(
            candidate.substring(0, candidate.length - 4),
          );
          if (normalizedKey.isNotEmpty) {
            final candidates = normalizedMap[normalizedKey];
            if (candidates != null && candidates.isNotEmpty) {
              matchedFile = candidates.first;
            }
          }
        }

        if (matchedFile == null) {
          continue;
        }

        final content = await _remoteLyricsApi.fetchLyrics(matchedFile);
        if (content == null || content.trim().isEmpty) {
          continue;
        }
        final parsedLines = _parseLrcContent(content);
        if (parsedLines.isEmpty) {
          continue;
        }
        final lyrics = Lyrics(
          trackId: trackId,
          lines: parsedLines,
          format: LyricsFormat.lrc,
        );
        await saveLyrics(lyrics);
        return await getLyricsByTrackId(trackId);
      }

      final fallbackKey = _sanitizeForComparison(title);
      if (fallbackKey.isEmpty) {
        return null;
      }
      final looseEntry = normalizedMap.entries.firstWhere(
        (entry) => entry.key.contains(fallbackKey),
        orElse: () => const MapEntry<String, List<String>>('', <String>[]),
      );
      if (looseEntry.value.isEmpty) {
        return null;
      }

      final content = await _remoteLyricsApi.fetchLyrics(looseEntry.value.first);
      if (content == null || content.trim().isEmpty) {
        return null;
      }
      final parsedLines = _parseLrcContent(content);
      if (parsedLines.isEmpty) {
        return null;
      }
      final lyrics = Lyrics(
        trackId: trackId,
        lines: parsedLines,
        format: LyricsFormat.lrc,
      );
      await saveLyrics(lyrics);
      return await getLyricsByTrackId(trackId);
    } catch (e) {
      print('⚠️ LyricsRepository: 云歌词获取失败 -> $e');
      return null;
    }
  }

  Iterable<String> _buildCandidateKeys(String title, String? artist) {
    final trimmedTitle = title.trim();
    final trimmedArtist = artist?.trim();

    final Set<String> candidates = {
      trimmedTitle,
      if (trimmedArtist != null && trimmedArtist.isNotEmpty)
        '${trimmedArtist} - $trimmedTitle',
      if (trimmedArtist != null && trimmedArtist.isNotEmpty)
        '$trimmedTitle - $trimmedArtist',
      if (trimmedArtist != null && trimmedArtist.isNotEmpty)
        '${trimmedArtist}_$trimmedTitle',
      if (trimmedArtist != null && trimmedArtist.isNotEmpty)
        '${trimmedTitle}_$trimmedArtist',
    };

    final normalizedTitle = _sanitizeForComparison(trimmedTitle);
    final normalizedArtist =
        trimmedArtist == null ? '' : _sanitizeForComparison(trimmedArtist);

    if (normalizedTitle.isNotEmpty) {
      candidates.add(normalizedTitle);
    }
    if (normalizedArtist.isNotEmpty) {
      candidates
        ..add('${normalizedArtist}_$normalizedTitle')
        ..add('${normalizedTitle}_$normalizedArtist')
        ..add('${normalizedArtist}-$normalizedTitle')
        ..add('${normalizedTitle}-$normalizedArtist');
    }

    return candidates.where((candidate) => candidate.trim().isNotEmpty);
  }

  String _sanitizeForComparison(String value) {
    var result = value.trim().toLowerCase();
    if (result.isEmpty) {
      return '';
    }
    result = result
        .replaceAll(RegExp(r'[\s]+'), '_')
        .replaceAll(RegExp(r'[\-‐‑‒–—―〜~]+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'[()\[\]{}]+'), '')
        .replaceAll(RegExp(r'_+'), '_');
    return result
        .replaceFirst(RegExp(r'^_+'), '')
        .replaceFirst(RegExp(r'_+$'), '');
  }

  String _normalizeForLooseCompare(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s]+'), ' ')
        .replaceAll(RegExp(r'[‐‑‒–—―〜~]+'), '-')
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  List<LyricsLine> _mergeNeteaseLyrics(
    String originalContent,
    String? translatedContent,
  ) {
    final List<LyricsLine> originalLines = _parseLrcContent(originalContent);
    if (originalLines.isEmpty) {
      return <LyricsLine>[];
    }

    if (translatedContent == null || translatedContent.trim().isEmpty) {
      return originalLines;
    }

    final Map<Duration, String> translationMap = _parseTranslationMap(
      translatedContent,
    );
    if (translationMap.isEmpty) {
      return originalLines;
    }

    final List<LyricsLine> merged = <LyricsLine>[];
    for (final line in originalLines) {
      final String? cachedTranslation = line.translatedText;
      final String? mappedTranslation = translationMap[line.timestamp];
      final String? normalizedTranslation = _normalizeTranslation(
        mappedTranslation ?? cachedTranslation,
      );

      if (identical(normalizedTranslation, cachedTranslation) ||
          (normalizedTranslation == cachedTranslation)) {
        merged.add(line);
      } else {
        merged.add(
          LyricsLine(
            timestamp: line.timestamp,
            originalText: line.originalText,
            translatedText: normalizedTranslation,
            annotatedTexts: line.annotatedTexts,
          ),
        );
      }
    }

    return merged;
  }

  Map<Duration, String> _parseTranslationMap(String content) {
    final Map<Duration, String> result = {};
    final List<String> lines = content.split('\n');
    final RegExp pattern = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final rawLine in lines) {
      final String trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final Match? match = pattern.firstMatch(trimmed);
      if (match == null) {
        continue;
      }

      final int minutes = int.parse(match.group(1)!);
      final int seconds = int.parse(match.group(2)!);
      final String fraction = match.group(3)!;
      final int milliseconds = fraction.length == 3
          ? int.parse(fraction)
          : int.parse(fraction) * 10;
      final String text = match.group(4)!.trim();
      if (text.isEmpty) {
        continue;
      }

      final Duration timestamp = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
      result[timestamp] = text;
    }

    return result;
  }

  String? _normalizeTranslation(String? input) {
    if (input == null) {
      return null;
    }
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll('\r', '');
  }

  List<LyricsLine> _parseLrcContent(String content) {
    final lines = <LyricsLine>[];
    final lrcLines = content.split('\n');

    for (final lrcLine in lrcLines) {
      final match = RegExp(
        r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)',
      ).firstMatch(lrcLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3)!;
        final rawText = match.group(4)!.trim();
        final translationSplit = _extractTranslation(rawText);
        final baseText = translationSplit.text;

        if (baseText.isNotEmpty || translationSplit.translation != null) {
          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: fraction.length == 3
                ? int.parse(fraction)
                : int.parse(fraction) * 10,
          );
          final parsed = _parseAnnotatedLine(baseText);

          lines.add(
            LyricsLine(
              timestamp: timestamp,
              originalText: parsed.text,
              translatedText: translationSplit.translation,
              annotatedTexts: parsed.segments,
            ),
          );
        }
      }
    }

    return lines;
  }

  List<LyricsLine> _parseTextContent(String content) {
    final lines = <LyricsLine>[];
    final textLines = content.split('\n');

    for (int i = 0; i < textLines.length; i++) {
      final rawText = textLines[i].trim();
      if (rawText.isNotEmpty) {
        final translationSplit = _extractTranslation(rawText);
        final parsed = _parseAnnotatedLine(translationSplit.text);
        lines.add(
          LyricsLine(
            timestamp: Duration(seconds: i * 5), // Default 5 seconds per line
            originalText: parsed.text,
            translatedText: translationSplit.translation,
            annotatedTexts: parsed.segments,
          ),
        );
      }
    }

    return lines;
  }

  _ParsedAnnotatedLine _parseAnnotatedLine(String rawText) {
    final segments = <AnnotatedText>[];
    final pattern = RegExp(r'([^\[\]]+)\[([^\[\]]+)\]');
    int currentIndex = 0;

    for (final match in pattern.allMatches(rawText)) {
      final start = match.start;
      final end = match.end;

      if (start > currentIndex) {
        final plainSegment = rawText.substring(currentIndex, start);
        if (plainSegment.isNotEmpty) {
          segments.add(
            AnnotatedText(
              original: plainSegment,
              annotation: plainSegment,
              type: TextType.other,
            ),
          );
        }
      }

      final baseRaw = match.group(1)!.trim();
      final ruby = match.group(2)!.trim();

      if (baseRaw.isNotEmpty) {
        final split = _separatePrefix(baseRaw, ruby);

        if (split.prefix.isNotEmpty) {
          segments.add(
            AnnotatedText(
              original: split.prefix,
              annotation: split.prefix,
              type: TextType.other,
            ),
          );
        }

        if (split.core.isNotEmpty) {
          segments.add(
            AnnotatedText(
              original: split.core,
              annotation: ruby,
              type: TextType.kanji,
            ),
          );
        }
      }

      currentIndex = end;
    }

    if (currentIndex < rawText.length) {
      final tail = rawText.substring(currentIndex);
      if (tail.isNotEmpty) {
        segments.add(
          AnnotatedText(original: tail, annotation: tail, type: TextType.other),
        );
      }
    }

    if (segments.isEmpty) {
      segments.add(
        AnnotatedText(
          original: rawText,
          annotation: rawText,
          type: TextType.other,
        ),
      );
    }

    final buffer = StringBuffer();
    for (final segment in segments) {
      buffer.write(segment.original);
    }

    return _ParsedAnnotatedLine(text: buffer.toString(), segments: segments);
  }

  _TranslationSplit _extractTranslation(String rawText) {
    final match = RegExp(
      r'<([^<>]+)>\s*$',
      multiLine: false,
    ).firstMatch(rawText);
    if (match == null) {
      return _TranslationSplit(text: rawText.trimRight(), translation: null);
    }

    final base = rawText.substring(0, match.start).trimRight();
    final translation = match.group(1)?.trim();

    return _TranslationSplit(
      text: base,
      translation: (translation == null || translation.isEmpty)
          ? null
          : translation,
    );
  }
}

class _ParsedAnnotatedLine {
  const _ParsedAnnotatedLine({required this.text, required this.segments});

  final String text;
  final List<AnnotatedText> segments;
}

class _TranslationSplit {
  const _TranslationSplit({required this.text, required this.translation});

  final String text;
  final String? translation;
}

class _BaseSplitResult {
  const _BaseSplitResult({required this.prefix, required this.core});

  final String prefix;
  final String core;
}

_BaseSplitResult _separatePrefix(String base, String ruby) {
  if (base.isEmpty) {
    return const _BaseSplitResult(prefix: '', core: '');
  }

  final kanjiRegex = RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF々〆ヶ]');
  int firstKanjiIndex = -1;

  for (int i = 0; i < base.length; i++) {
    final char = base[i];
    if (kanjiRegex.hasMatch(char)) {
      firstKanjiIndex = i;
      break;
    }
  }

  if (firstKanjiIndex <= 0) {
    return _BaseSplitResult(prefix: '', core: base);
  }

  final prefix = base.substring(0, firstKanjiIndex);
  final core = base.substring(firstKanjiIndex);

  if (ruby.startsWith(prefix)) {
    return _BaseSplitResult(prefix: '', core: base);
  }

  return _BaseSplitResult(prefix: prefix, core: core);
}
