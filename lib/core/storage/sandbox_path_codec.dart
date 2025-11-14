import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 在 iOS 上用占位符的形式记录沙盒内部路径，避免每次重装后路径挂掉。
/// 其它平台仍然可以读取这些占位符，但默认不会写入。
class SandboxPathCodec {
  static const String _documentsPrefix = 'sandbox-documents://';
  static const String _supportPrefix = 'sandbox-support://';

  String? _documentsBasePath;
  String? _supportBasePath;

  /// 把真实路径转成可写入数据库的占位符（仅 iOS 启用）。
  Future<String> encode(String absolutePath) async {
    if (!_shouldEncode) {
      return absolutePath;
    }

    final documents = await _documentsPath();
    if (documents != null && _isWithin(documents, absolutePath)) {
      final relative = _relativeWithin(documents, absolutePath);
      return '$_documentsPrefix$relative';
    }

    final support = await _supportPath();
    if (support != null && _isWithin(support, absolutePath)) {
      final relative = _relativeWithin(support, absolutePath);
      return '$_supportPrefix$relative';
    }

    return absolutePath;
  }

  /// 把数据库中的占位符还原成当前沙盒的真实路径。
  Future<String> decode(String storedPath) async {
    if (storedPath.startsWith(_documentsPrefix)) {
      final relative = storedPath.substring(_documentsPrefix.length);
      final documents = await _documentsPath();
      if (documents != null) {
        return _joinRelative(documents, relative);
      }
    } else if (storedPath.startsWith(_supportPrefix)) {
      final relative = storedPath.substring(_supportPrefix.length);
      final support = await _supportPath();
      if (support != null) {
        return _joinRelative(support, relative);
      }
    }

    return storedPath;
  }

  bool get _shouldEncode => Platform.isIOS;

  Future<String?> _documentsPath() async {
    if (_documentsBasePath != null) {
      return _documentsBasePath;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      _documentsBasePath = p.normalize(dir.path);
      return _documentsBasePath;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _supportPath() async {
    if (_supportBasePath != null) {
      return _supportBasePath;
    }
    try {
      final dir = await getApplicationSupportDirectory();
      _supportBasePath = p.normalize(dir.path);
      return _supportBasePath;
    } catch (_) {
      return null;
    }
  }

  bool _isWithin(String base, String target) {
    final normalizedBase = p.normalize(base);
    final normalizedTarget = p.normalize(target);
    if (normalizedBase == normalizedTarget) {
      return true;
    }
    return p.isWithin(normalizedBase, normalizedTarget);
  }

  String _relativeWithin(String base, String target) {
    var relative = p.relative(target, from: base);
    if (relative == '.') {
      relative = '';
    }
    return relative;
  }

  String _joinRelative(String base, String relative) {
    final sanitized = relative.isEmpty
        ? ''
        : relative.startsWith('/')
        ? relative.substring(1)
        : relative;
    final joined = sanitized.isEmpty ? base : p.join(base, sanitized);
    return p.normalize(joined);
  }
}
