import 'dart:collection';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:misuzu_music/core/constants/app_constants.dart';
import 'package:path/path.dart' as path;

import '../../core/error/exceptions.dart';
import '../../core/utils/lyrics_line_merger.dart';
import '../../domain/entities/lyrics_entities.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../datasources/local/lyrics_local_datasource.dart';
import '../datasources/remote/netease_api_client.dart';
import '../models/lyrics_models.dart';
import '../services/netease_id_resolver.dart';
import '../services/remote_lyrics_api.dart';

class LyricsRepositoryImpl implements LyricsRepository {
  final LyricsLocalDataSource _localDataSource;
  final NeteaseApiClient _neteaseApiClient;
  final RemoteLyricsApi _remoteLyricsApi;
  final NeteaseIdResolver _neteaseIdResolver;

  LyricsRepositoryImpl({
    required LyricsLocalDataSource localDataSource,
    required NeteaseApiClient neteaseApiClient,
    required RemoteLyricsApi remoteLyricsApi,
    required NeteaseIdResolver neteaseIdResolver,
  }) : _localDataSource = localDataSource,
       _neteaseApiClient = neteaseApiClient,
       _remoteLyricsApi = remoteLyricsApi,
       _neteaseIdResolver = neteaseIdResolver;

  @override
  Future<Lyrics?> getLyricsByTrackId(String trackId) async {
    try {
      final lyricsModel = await _localDataSource.getLyricsByTrackId(trackId);
      final lyrics = lyricsModel?.toEntity();
      return lyrics == null ? null : _mergeLyricsLines(lyrics);
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
      final lyricsExtensions = ['.lrc', '.ttml', '.txt'];

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
      } else if (extension == '.ttml' || extension == '.xml') {
        format = LyricsFormat.lrc;
        lines = _parseTtmlContent(content);
        if (lines.isEmpty) {
          format = LyricsFormat.text;
          lines = _parseTextContent(_stripTtmlTags(content));
        }
      } else if (_looksLikeTtml(content)) {
        format = LyricsFormat.lrc;
        lines = _parseTtmlContent(content);
        if (lines.isEmpty) {
          format = LyricsFormat.text;
          lines = _parseTextContent(_stripTtmlTags(content));
        }
      } else {
        format = LyricsFormat.text;
        lines = _parseTextContent(content);
      }

      if (lines.isNotEmpty) {
        _logLyricsPreview(lines);
      } else {
        print('🎼 LyricsRepository: 本地歌词解析为空');
      }
      return _mergeLyricsLines(
        Lyrics(trackId: trackId, lines: lines, format: format),
      );
    } catch (e) {
      throw LyricsException('Failed to load lyrics from file: ${e.toString()}');
    }
  }

  @override
  Future<Lyrics?> loadLyricsFromMetadata(Track track) async {
    final filePath = track.filePath;
    if (filePath.isEmpty) {
      return null;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return null;
      }

      final metadata = readMetadata(file);
      final rawLyrics = metadata.lyrics;
      if (rawLyrics == null || rawLyrics.trim().isEmpty) {
        return null;
      }

      final cleaned = rawLyrics
          .replaceAll('\u0000', '')
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .trim();
      if (cleaned.isEmpty) {
        return null;
      }

      var format = LyricsFormat.lrc;
      var lines = _parseLrcContent(cleaned);
      if (lines.isEmpty && _looksLikeTtml(cleaned)) {
        lines = _parseTtmlContent(cleaned);
      }
      if (lines.isEmpty) {
        format = LyricsFormat.text;
        lines = _parseTextContent(cleaned);
      }

      if (lines.isEmpty) {
        print('🎼 LyricsRepository: 内嵌歌词存在但解析为空');
        return null;
      }

      _logLyricsPreview(lines);
      return _mergeLyricsLines(
        Lyrics(trackId: track.id, lines: lines, format: format),
      );
    } catch (e) {
      print('⚠️ LyricsRepository: 读取内嵌歌词失败 -> $e');
      return null;
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
    required Track track,
    bool cloudOnly = false,
  }) async {
    final trimmedTitle = track.title.trim();
    if (trimmedTitle.isEmpty) {
      return null;
    }

    try {
      if (cloudOnly) {
        return await _fetchLyricsFromRemoteLibrary(track: track);
      }

      final Lyrics? remoteLyrics = await _fetchLyricsFromRemoteLibrary(
        track: track,
      );
      if (remoteLyrics != null) {
        return remoteLyrics;
      }

      final resolution = await _neteaseIdResolver.resolve(track: track);
      final songId = resolution?.id;
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

      print('🎼 LyricsRepository: 使用歌词 -> songId=$songId');
      _logLyricsPreview(mergedLines);
      await saveLyrics(
        _mergeLyricsLines(
          Lyrics(
            trackId: track.id,
            lines: mergedLines,
            format: LyricsFormat.lrc,
          ),
        ),
      );
      return await getLyricsByTrackId(track.id);
    } catch (e) {
      print('⚠️ LyricsRepository: 在线歌词获取失败 -> $e');
      return null;
    }
  }

  Future<Lyrics?> _fetchLyricsFromRemoteLibrary({required Track track}) async {
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

      final candidateKeys = _buildCandidateKeys(
        track.title,
        track.artist.trim().isEmpty ? null : track.artist,
      );
      for (var candidate in candidateKeys) {
        if (!candidate.toLowerCase().endsWith('.lrc')) {
          candidate = '$candidate.lrc';
        }

        final looseCandidate = _normalizeForLooseCompare(candidate);
        final directEntry = normalizedAvailable.firstWhere(
          (entry) => entry.value == looseCandidate,
          orElse: () => const MapEntry<String, String>('', ''),
        );

        String? matchedFile = directEntry.key.isNotEmpty
            ? directEntry.key
            : null;
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
        print('🎼 LyricsRepository: 云端歌词原文预览 ->\n' + _extractPreview(content));
        final parsedLines = _parseLrcContent(content);
        if (parsedLines.isEmpty) {
          continue;
        }
        print('🎼 LyricsRepository: 使用云端歌词 -> $matchedFile');
        print(
          '--- Cloud LRC Raw ---\n${content.split('\n').take(20).join('\n')}\n---------------------',
        );
        _debugPrintAnnotations(parsedLines);
        _logLyricsPreview(parsedLines);
        await saveLyrics(
          _mergeLyricsLines(
            Lyrics(
              trackId: track.id,
              lines: parsedLines,
              format: LyricsFormat.lrc,
            ),
          ),
        );
        return await getLyricsByTrackId(track.id);
      }

      final fallbackKey = _sanitizeForComparison(track.title);
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

      final content = await _remoteLyricsApi.fetchLyrics(
        looseEntry.value.first,
      );
      if (content == null || content.trim().isEmpty) {
        return null;
      }
      print('🎼 LyricsRepository: 云端歌词原文预览 ->\n' + _extractPreview(content));
      final parsedLines = _parseLrcContent(content);
      if (parsedLines.isEmpty) {
        return null;
      }
      print('🎼 LyricsRepository: 使用云端歌词(模糊匹配) -> ${looseEntry.value.first}');
      print(
        '--- Cloud LRC Raw ---\n${content.split('\n').take(20).join('\n')}\n---------------------',
      );
      _debugPrintAnnotations(parsedLines);
      _logLyricsPreview(parsedLines);
      await saveLyrics(
        _mergeLyricsLines(
          Lyrics(
            trackId: track.id,
            lines: parsedLines,
            format: LyricsFormat.lrc,
          ),
        ),
      );
      return await getLyricsByTrackId(track.id);
    } catch (e) {
      print('⚠️ LyricsRepository: 云歌词获取失败 -> $e');
      return null;
    }
  }

  Iterable<String> _buildCandidateKeys(String title, String? artist) {
    final trimmedTitle = title.trim();
    final trimmedArtist = artist?.trim();

    final sanitizedTitle = _stripPunctuation(trimmedTitle);
    final sanitizedArtist =
        trimmedArtist == null ? '' : _stripPunctuation(trimmedArtist);

    final candidates = LinkedHashSet<String>();

    if (sanitizedArtist.isNotEmpty && sanitizedTitle.isNotEmpty) {
      final combined = '$sanitizedArtist $sanitizedTitle'.trim();
      if (combined.isNotEmpty) {
        candidates
          ..add(combined)
          ..add(combined.replaceAll(' ', ''));
      }
    }

    if (sanitizedTitle.isNotEmpty) {
      candidates.add(sanitizedTitle);
      candidates.add(sanitizedTitle.replaceAll(' ', ''));
    }

    final Set<String> fallback = {
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
    for (final candidate in fallback) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) {
        candidates.add(trimmed);
      }
    }

    final normalizedTitle = _sanitizeForComparison(trimmedTitle);
    final normalizedArtist = trimmedArtist == null
        ? ''
        : _sanitizeForComparison(trimmedArtist);

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

  String _stripPunctuation(String input) {
    final replaced = input.replaceAll(
      RegExp(r'[\p{P}\p{S}]', unicode: true),
      ' ',
    );
    return replaced.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  Lyrics _mergeLyricsLines(Lyrics lyrics) {
    final mergedLines = LyricsLineMerger.mergeByTimestamp(lyrics.lines);
    if (identical(mergedLines, lyrics.lines)) {
      return lyrics;
    }
    return Lyrics(
      trackId: lyrics.trackId,
      lines: mergedLines,
      format: lyrics.format,
      source: lyrics.source,
    );
  }

  void _logLyricsPreview(List<LyricsLine> lines) {
    if (lines.isEmpty) {
      print('🎼 LyricsRepository: 预览空内容');
      return;
    }
    final preview = lines
        .take(3)
        .map(
          (line) =>
              '[${line.timestamp}] ${line.originalText} | 注音: ${line.annotatedTexts.map((segment) => '${segment.type}:${segment.original}->{segment.annotation}').join(', ')}',
        )
        .join('\n');
    print('🎼 LyricsRepository: 预览前几行:\n$preview');
  }

  void _debugPrintAnnotations(List<LyricsLine> lines) {
    final sample = lines.take(3);
    for (final line in sample) {
      for (final seg in line.annotatedTexts) {
        print(
          '🔍 seg original="${seg.original}" annotation="${seg.annotation}" codeUnits=${seg.annotation.codeUnits}',
        );
      }
    }
  }

  String _extractPreview(String content) {
    final lines = content.split('\n');
    return lines.take(5).join('\n');
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

    return LyricsLineMerger.mergeByTimestamp(merged);
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

    return LyricsLineMerger.mergeByTimestamp(lines);
  }

  bool _looksLikeTtml(String content) {
    final String normalized = content.toLowerCase();
    return normalized.contains('<tt') &&
        (normalized.contains('xmlns="http://www.w3.org/ns/ttml"') ||
            normalized.contains('xmlns="http://www.w3.org/ns/ttml#"') ||
            normalized.contains('<tt>') ||
            normalized.contains('<tt '));
  }

  List<LyricsLine> _parseTtmlContent(String content) {
    final lines = <LyricsLine>[];
    final normalized = content
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final RegExp pPattern = RegExp(
      r'<p\b([^>]*)>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in pPattern.allMatches(normalized)) {
      final String attrs = match.group(1) ?? '';
      final String body = match.group(2) ?? '';
      final String? begin =
          _extractXmlAttribute(attrs, 'begin') ??
          _extractXmlAttribute(body, 'begin');
      if (begin == null) {
        continue;
      }

      final Duration? timestamp = _parseTtmlTimestamp(begin);
      if (timestamp == null) {
        continue;
      }

      final String text = _normalizeTtmlText(body);
      if (text.isEmpty) {
        continue;
      }

      final parsed = _parseAnnotatedLine(text);
      lines.add(
        LyricsLine(
          timestamp: timestamp,
          originalText: parsed.text,
          translatedText: null,
          annotatedTexts: parsed.segments,
        ),
      );
    }

    return LyricsLineMerger.mergeByTimestamp(lines);
  }

  String? _extractXmlAttribute(String source, String name) {
    final RegExp doubleQuote = RegExp(
      '$name\\s*=\\s*\\\"([^\\\"]+)\\\"',
      caseSensitive: false,
    );
    final RegExp singleQuote = RegExp(
      "$name\\s*=\\s*'([^']+)'",
      caseSensitive: false,
    );
    final Match? doubleMatch = doubleQuote.firstMatch(source);
    if (doubleMatch != null) {
      return doubleMatch.group(1);
    }
    final Match? singleMatch = singleQuote.firstMatch(source);
    if (singleMatch != null) {
      return singleMatch.group(1);
    }
    return null;
  }

  Duration? _parseTtmlTimestamp(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length < 2) {
        return null;
      }

      double seconds = 0;
      int minutes = 0;
      int hours = 0;

      final String secondsPart = parts.removeLast();
      final double? secondsValue = double.tryParse(secondsPart);
      if (secondsValue == null) {
        return null;
      }
      seconds = secondsValue;

      if (parts.isNotEmpty) {
        final int? minutesValue = int.tryParse(parts.removeLast());
        if (minutesValue == null) {
          return null;
        }
        minutes = minutesValue;
      }

      if (parts.isNotEmpty) {
        final int? hoursValue = int.tryParse(parts.removeLast());
        if (hoursValue == null) {
          return null;
        }
        hours = hoursValue;
      }

      final double totalSeconds =
          hours * 3600 + minutes * 60 + seconds;
      return Duration(milliseconds: (totalSeconds * 1000).round());
    }

    final String lower = trimmed.toLowerCase();
    if (lower.endsWith('ms')) {
      final double? value = double.tryParse(
        lower.substring(0, lower.length - 2),
      );
      if (value == null) {
        return null;
      }
      return Duration(milliseconds: value.round());
    }
    if (lower.endsWith('s')) {
      final double? value = double.tryParse(
        lower.substring(0, lower.length - 1),
      );
      if (value == null) {
        return null;
      }
      return Duration(milliseconds: (value * 1000).round());
    }
    if (lower.endsWith('m')) {
      final double? value = double.tryParse(
        lower.substring(0, lower.length - 1),
      );
      if (value == null) {
        return null;
      }
      return Duration(milliseconds: (value * 60000).round());
    }
    if (lower.endsWith('h')) {
      final double? value = double.tryParse(
        lower.substring(0, lower.length - 1),
      );
      if (value == null) {
        return null;
      }
      return Duration(milliseconds: (value * 3600000).round());
    }

    final double? fallback = double.tryParse(lower);
    if (fallback == null) {
      return null;
    }
    return Duration(milliseconds: (fallback * 1000).round());
  }

  String _normalizeTtmlText(String input) {
    const placeholder = '\u0001';
    final String prepared = input.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      placeholder,
    );
    final String stripped = _stripTtmlTags(prepared);
    final String decoded = _decodeXmlEntities(stripped);
    final String collapsed = decoded.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.replaceAll(placeholder, '\n').trim();
  }

  String _stripTtmlTags(String input) {
    return input
        .replaceAll(RegExp(r'</?span\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?p\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
  }

  String _decodeXmlEntities(String input) {
    final buffer = StringBuffer();
    int lastIndex = 0;
    final RegExp pattern = RegExp(
      r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);',
    );

    for (final match in pattern.allMatches(input)) {
      buffer.write(input.substring(lastIndex, match.start));
      final String entity = match.group(1) ?? '';
      String? replacement;

      switch (entity) {
        case 'amp':
          replacement = '&';
          break;
        case 'lt':
          replacement = '<';
          break;
        case 'gt':
          replacement = '>';
          break;
        case 'quot':
          replacement = '\"';
          break;
        case 'apos':
          replacement = "'";
          break;
        default:
          if (entity.startsWith('#x')) {
            final int? codePoint = int.tryParse(
              entity.substring(2),
              radix: 16,
            );
            if (codePoint != null) {
              replacement = String.fromCharCode(codePoint);
            }
          } else if (entity.startsWith('#')) {
            final int? codePoint = int.tryParse(entity.substring(1));
            if (codePoint != null) {
              replacement = String.fromCharCode(codePoint);
            }
          }
      }

      buffer.write(replacement ?? match.group(0));
      lastIndex = match.end;
    }

    buffer.write(input.substring(lastIndex));
    return buffer.toString();
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

    return LyricsLineMerger.mergeByTimestamp(lines);
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
