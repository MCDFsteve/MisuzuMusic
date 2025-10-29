import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';

class SongDetailService {
  SongDetailService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final RegExp _sanitizeRegExp =
      RegExp(r'[\p{P}\p{S}\s]+', unicode: true);

  String sanitizeTitle(String rawTitle) {
    final sanitized = rawTitle.replaceAll(_sanitizeRegExp, '').trim();
    if (sanitized.isNotEmpty) {
      return sanitized;
    }
    // 避免出现空文件名，使用回退标识符
    return 'untitled_${rawTitle.hashCode.abs()}';
  }

  Future<SongDetailResult> fetchDetail({
    required String title,
    String? artist,
    String? album,
  }) async {
    final sanitized = sanitizeTitle(title);
    debugPrint('🗒️ 歌曲详情查找: $sanitized.txt');

    final uri = Uri.parse(AppConstants.songDetailEndpoint).replace(
      queryParameters: <String, String?>{
        'title': title,
        'artist': artist?.trim().isEmpty ?? true ? null : artist!.trim(),
        'album': album?.trim().isEmpty ?? true ? null : album!.trim(),
        'file': sanitized,
      }..removeWhere((key, value) => value == null),
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw NetworkException(
        '歌曲详情获取失败 (HTTP ${response.statusCode})',
        response.body,
      );
    }

    try {
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const NetworkException('歌曲详情响应格式无效');
      }

      final success = decoded['success'] == true;
      if (!success) {
        final message = decoded['message'];
        throw NetworkException(
          message is String && message.trim().isNotEmpty
              ? message.trim()
              : '歌曲详情获取失败',
        );
      }

      final fileName = (decoded['file'] as String?)?.trim();
      final content = decoded['content'] as String?;
      final exists = decoded['exists'] == true;

      if (fileName == null || fileName.isEmpty) {
        throw const NetworkException('歌曲详情响应缺少文件名');
      }

      return SongDetailResult(
        fileName: fileName,
        content: content ?? '',
        exists: exists,
        created: false,
      );
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw NetworkException('解析歌曲详情失败: $e');
    }
  }

  Future<SongDetailResult> saveDetail({
    required String title,
    required String content,
    String? artist,
    String? album,
  }) async {
    final sanitized = sanitizeTitle(title);
    debugPrint('📝 歌曲详情保存: $sanitized.txt');

    final uri = Uri.parse(AppConstants.songDetailEndpoint);
    final payload = <String, dynamic>{
      'title': title,
      'artist': artist,
      'album': album,
      'file': sanitized,
      'content': content,
    }..removeWhere((key, value) => value == null);

    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw NetworkException(
        '歌曲详情保存失败 (HTTP ${response.statusCode})',
        response.body,
      );
    }

    try {
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const NetworkException('歌曲详情保存响应格式无效');
      }

      final success = decoded['success'] == true;
      if (!success) {
        final message = decoded['message'];
        throw NetworkException(
          message is String && message.trim().isNotEmpty
              ? message.trim()
              : '歌曲详情保存失败',
        );
      }

      final fileName = (decoded['file'] as String?)?.trim();
      final savedContent = decoded['content'] as String?;
      final created = decoded['created'] == true;

      if (fileName == null || fileName.isEmpty) {
        throw const NetworkException('歌曲详情保存响应缺少文件名');
      }

      return SongDetailResult(
        fileName: fileName,
        content: savedContent ?? content,
        exists: true,
        created: created,
      );
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw NetworkException('解析歌曲详情保存响应失败: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

class SongDetailResult {
  const SongDetailResult({
    required this.fileName,
    required this.content,
    required this.exists,
    required this.created,
  });

  final String fileName;
  final String content;
  final bool exists;
  final bool created;
}
