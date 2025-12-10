import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../constants/audio_extensions.dart';

class FileAssociationService {
  FileAssociationService({
    MethodChannel? channel,
  }) : _channel =
            channel ?? const MethodChannel('com.aimessoft.misuzumusic/file_association');

  final MethodChannel _channel;
  final List<String> _pendingPaths = [];
  final StreamController<List<String>> _openFilesController =
      StreamController<List<String>>.broadcast();

  Stream<List<String>> get onFilesOpened => _openFilesController.stream;

  Future<void> initialize({List<String> initialPaths = const []}) async {
    _pendingPaths
      ..clear()
      ..addAll(_filterAudioPaths(initialPaths));

    if (Platform.isMacOS ||
        Platform.isIOS ||
        Platform.isAndroid ||
        Platform.isWindows ||
        Platform.isLinux) {
      _channel.setMethodCallHandler(_handleMethodCall);
      await _collectPendingFilesFromNative();
    } else {
      _channel.setMethodCallHandler(null);
    }
  }

  List<String> takePendingPaths() {
    final result = List<String>.from(_pendingPaths);
    _pendingPaths.clear();
    return result;
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'openFiles':
        final arguments = call.arguments;
        final rawPaths = arguments is List
            ? arguments.map((item) => item.toString()).toList()
            : <String>[];
        final filtered = _filterAudioPaths(rawPaths);
        if (filtered.isEmpty) {
          return;
        }

        if (_openFilesController.hasListener) {
          _openFilesController.add(filtered);
        } else {
          for (final path in filtered) {
            if (!_pendingPaths.contains(path)) {
              _pendingPaths.add(path);
            }
          }
        }
        break;
      default:
        break;
    }
  }

  Future<void> _collectPendingFilesFromNative() async {
    try {
      final pending =
          await _channel.invokeMethod<List<dynamic>>('collectPendingFiles');
      if (pending == null) {
        return;
      }
      final parsed =
          _filterAudioPaths(pending.map((item) => item.toString()).toList());
      for (final path in parsed) {
        if (!_pendingPaths.contains(path)) {
          _pendingPaths.add(path);
        }
      }
    } catch (_) {
      // Ignore errors when the native side has no pending files.
    }
  }

  List<String> _filterAudioPaths(List<String> candidates) {
    final result = <String>[];
    final seen = <String>{};

    for (final raw in candidates) {
      if (raw.isEmpty) {
        continue;
      }

      var cleaned = raw.trim();
      if (cleaned.length >= 2 &&
          ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
              (cleaned.startsWith("'") && cleaned.endsWith("'")))) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
      }
      if (cleaned.startsWith('file://')) {
        try {
          cleaned = Uri.parse(cleaned).toFilePath();
        } catch (_) {
          // Ignore invalid URI
        }
      }

      final file = File(cleaned);
      if (!file.existsSync()) {
        continue;
      }

      final extension = p.extension(cleaned).toLowerCase();
      if (!kSupportedAudioFileExtensions.contains(extension)) {
        continue;
      }

      final normalized = file.absolute.path;
      if (seen.add(normalized)) {
        result.add(normalized);
      }
    }

    return result;
  }
}
