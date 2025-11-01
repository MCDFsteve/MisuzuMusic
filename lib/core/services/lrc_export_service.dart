import 'dart:io';
import 'dart:convert' show utf8;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/lyrics_entities.dart';
import '../constants/app_constants.dart';

/// Service for exporting lyrics to LRC format
class LrcExportService {
  LrcExportService._();

  static final RegExp _punctuationPattern =
      RegExp(r'[\p{P}\p{S}]', unicode: true);
  static final RegExp _invalidFileCharacters =
      RegExp(r'[<>:"/\\|?*]');

  /// Generate LRC formatted content from lyrics
  static String formatLyricsToLrc({
    required Lyrics lyrics,
    String? title,
    String? artist,
    String? album,
  }) {
    final buffer = StringBuffer();

    // Add metadata headers
    if (title != null) {
      buffer.writeln('[ti:$title]');
    }
    if (artist != null) {
      buffer.writeln('[ar:$artist]');
    }
    if (album != null) {
      buffer.writeln('[al:$album]');
    }
    buffer.writeln('[by:Misuzu Music]');
    buffer.writeln('');

    // Process each lyrics line
    for (final line in lyrics.lines) {
      final timestamp = formatTimestamp(line.timestamp);

      // Generate the main lyric line with annotations
      final annotatedLine = formatAnnotatedLine(line.annotatedTexts);

      // Add translation if available
      final translation = line.translatedText != null && line.translatedText!.isNotEmpty
          ? '<${line.translatedText}>'
          : '';

      // Combine everything
      final fullLine = '$annotatedLine$translation';
      buffer.writeln('[$timestamp]$fullLine');
    }

    return buffer.toString();
  }

  /// Format timestamp to LRC format [mm:ss.xx]
  static String formatTimestamp(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final centiseconds = ((duration.inMilliseconds % 1000) / 10).floor().toString().padLeft(2, '0');
    return '$minutes:$seconds.$centiseconds';
  }

  /// Format annotated texts with furigana in brackets
  static String formatAnnotatedLine(List<AnnotatedText> annotatedTexts) {
    final buffer = StringBuffer();

    for (final text in annotatedTexts) {
      if (text.type == TextType.kanji && text.original != text.annotation) {
        // For kanji with different annotation, add furigana in brackets
        buffer.write('${text.original}[${text.annotation}]');
      } else {
        // For other text types, just use original
        buffer.write(text.original);
      }
    }

    return buffer.toString();
  }

  /// Save LRC content to file with user-selected location
  static Future<bool> saveToFile({
    required String lrcContent,
    required String filename,
  }) async {
    try {
      // Let user choose save location
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '保存LRC歌词文件',
        fileName: '$filename.lrc',
        type: FileType.custom,
        allowedExtensions: ['lrc'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(lrcContent, encoding: utf8);
        return true;
      }
      return false;
    } catch (e) {
      print('Error saving LRC file: $e');
      return false;
    }
  }

  /// Quick save to Downloads folder (fallback method)
  static Future<String?> saveToDownloads({
    required String lrcContent,
    required String filename,
  }) async {
    try {
      // Get downloads directory (or documents on iOS)
      Directory? directory;
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        directory = await getDownloadsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final file = File('${directory.path}/$filename.lrc');
        await file.writeAsString(lrcContent, encoding: utf8);
        return file.path;
      }
      return null;
    } catch (e) {
      print('Error saving LRC file to downloads: $e');
      return null;
    }
  }

  /// Generate suggested filename from track info
  static String generateFilename({
    String? artist,
    String? title,
    String? trackId,
  }) {
    final compactArtist = artist == null ? '' : _compactSegment(artist);
    final compactTitle = title == null ? '' : _compactSegment(title);

    final buffer = StringBuffer();
    if (compactArtist.isNotEmpty) {
      buffer.write(compactArtist);
    }
    if (compactTitle.isNotEmpty) {
      buffer.write(compactTitle);
    }

    String candidate = buffer.toString();

    if (candidate.isEmpty && compactTitle.isNotEmpty) {
      candidate = compactTitle;
    }

    if (candidate.isEmpty && trackId != null) {
      candidate = _compactSegment('Track_$trackId');
    }

    if (candidate.isEmpty) {
      candidate = 'lyrics_${DateTime.now().millisecondsSinceEpoch}';
    }

    candidate = _ensureSafeFilename(candidate);

    if (candidate.isEmpty) {
      return 'lyrics_${DateTime.now().millisecondsSinceEpoch}';
    }

    return candidate;
  }

  static String _compactSegment(String input) {
    final stripped = input.replaceAll(_punctuationPattern, ' ');
    final collapsed = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) {
      return '';
    }
    return collapsed.replaceAll(' ', '');
  }

  static String _ensureSafeFilename(String input) {
    final withoutInvalid = input.replaceAll(_invalidFileCharacters, '');
    return withoutInvalid.trim();
  }
}
