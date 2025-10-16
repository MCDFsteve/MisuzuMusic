import 'dart:io';
import 'package:path/path.dart' as path;

import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';
import '../../domain/entities/lyrics_entities.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../../domain/services/japanese_processing_service.dart';
import '../datasources/local/lyrics_local_datasource.dart';
import '../models/lyrics_models.dart';

class LyricsRepositoryImpl implements LyricsRepository {
  final LyricsLocalDataSource _localDataSource;
  final JapaneseProcessingService _japaneseProcessingService;

  LyricsRepositoryImpl({
    required LyricsLocalDataSource localDataSource,
    required JapaneseProcessingService japaneseProcessingService,
  })  : _localDataSource = localDataSource,
        _japaneseProcessingService = japaneseProcessingService;

  @override
  Future<Lyrics?> getLyricsByTrackId(String trackId) async {
    try {
      final lyricsModel = await _localDataSource.getLyricsByTrackId(trackId);
      if (lyricsModel != null) {
        final lyrics = lyricsModel.toEntity();
        // Process Japanese text if not already processed
        if (lyrics.lines.any((line) => line.annotatedTexts.isEmpty)) {
          return await _processJapaneseLyrics(lyrics);
        }
        return lyrics;
      }
      return null;
    } catch (e) {
      throw DatabaseException('Failed to get lyrics: ${e.toString()}');
    }
  }

  @override
  Future<void> saveLyrics(Lyrics lyrics) async {
    try {
      final processedLyrics = await _processJapaneseLyrics(lyrics);
      final lyricsModel = LyricsModel.fromEntity(processedLyrics);

      final existingLyrics = await _localDataSource.getLyricsByTrackId(lyrics.trackId);
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

      for (final extension in lyricsExtensions) {
        final lyricsPath = path.join(directory.path, '$baseName$extension');
        final lyricsFile = File(lyricsPath);
        if (lyricsFile.existsSync()) {
          return lyricsPath;
        }
      }

      // Try looking for similar filenames
      await for (final entity in directory.list()) {
        if (entity is File) {
          final fileName = path.basenameWithoutExtension(entity.path);
          final extension = path.extension(entity.path).toLowerCase();

          if (lyricsExtensions.contains(extension) &&
              _isSimilarFileName(fileName, baseName)) {
            return entity.path;
          }
        }
      }

      return null;
    } catch (e) {
      throw FileSystemException('Failed to find lyrics file: ${e.toString()}');
    }
  }

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

      final lyrics = Lyrics(
        trackId: trackId,
        lines: lines,
        format: format,
      );

      return await _processJapaneseLyrics(lyrics);
    } catch (e) {
      throw LyricsException('Failed to load lyrics from file: ${e.toString()}');
    }
  }

  @override
  Future<bool> hasLyrics(String trackId) async {
    try {
      return await _localDataSource.hasLyrics(trackId);
    } catch (e) {
      throw DatabaseException('Failed to check lyrics existence: ${e.toString()}');
    }
  }

  Future<Lyrics> _processJapaneseLyrics(Lyrics lyrics) async {
    try {
      final processedLines = <LyricsLine>[];

      for (final line in lyrics.lines) {
        if (_japaneseProcessingService.containsJapanese(line.originalText)) {
          final annotatedTexts = await _japaneseProcessingService.annotateText(line.originalText);
          processedLines.add(LyricsLine(
            timestamp: line.timestamp,
            originalText: line.originalText,
            annotatedTexts: annotatedTexts,
          ));
        } else {
          // Non-Japanese text, create a single annotation
          processedLines.add(LyricsLine(
            timestamp: line.timestamp,
            originalText: line.originalText,
            annotatedTexts: [
              AnnotatedText(
                original: line.originalText,
                annotation: line.originalText,
                type: TextType.other,
              )
            ],
          ));
        }
      }

      return Lyrics(
        trackId: lyrics.trackId,
        lines: processedLines,
        format: lyrics.format,
      );
    } catch (e) {
      throw JapaneseProcessingException('Failed to process Japanese lyrics: ${e.toString()}');
    }
  }

  List<LyricsLine> _parseLrcContent(String content) {
    final lines = <LyricsLine>[];
    final lrcLines = content.split('\n');

    for (final lrcLine in lrcLines) {
      final match = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)').firstMatch(lrcLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: centiseconds * 10,
          );

          lines.add(LyricsLine(
            timestamp: timestamp,
            originalText: text,
            annotatedTexts: [], // Will be populated by processing
          ));
        }
      }
    }

    return lines;
  }

  List<LyricsLine> _parseTextContent(String content) {
    final lines = <LyricsLine>[];
    final textLines = content.split('\n');

    for (int i = 0; i < textLines.length; i++) {
      final text = textLines[i].trim();
      if (text.isNotEmpty) {
        lines.add(LyricsLine(
          timestamp: Duration(seconds: i * 5), // Default 5 seconds per line
          originalText: text,
          annotatedTexts: [], // Will be populated by processing
        ));
      }
    }

    return lines;
  }

  bool _isSimilarFileName(String fileName1, String fileName2) {
    // Simple similarity check - can be made more sophisticated
    final normalized1 = fileName1.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final normalized2 = fileName2.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    return normalized1.contains(normalized2) ||
           normalized2.contains(normalized1) ||
           _levenshteinDistance(normalized1, normalized2) <= 3;
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }
}