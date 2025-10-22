import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';

class RemoteLyricsApi {
  RemoteLyricsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<String>> listAvailableLyrics() async {
    final uri = Uri.parse(AppConstants.remoteLyricsEndpoint).replace(
      queryParameters: const {
        'action': 'list',
        'format': 'json',
      },
    );
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw NetworkException(_resolveErrorMessage(response.body));
    }

    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final files = decoded['files'];
        if (files is List) {
          return files
              .whereType<String>()
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty)
              .toList();
        }
      }
      return const [];
    } catch (e) {
      throw NetworkException('解析云歌词列表失败: $e');
    }
  }

  Future<String?> fetchLyrics(String filename) async {
    final trimmed = filename.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.parse(AppConstants.remoteLyricsEndpoint).replace(
      queryParameters: {'file': trimmed},
    );

    final response = await _client.get(uri);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw NetworkException(_resolveErrorMessage(response.body));
    }

    return response.body;
  }

  void dispose() {
    _client.close();
  }

  String _resolveErrorMessage(String responseBody) {
    try {
      final decoded = json.decode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // ignore parse errors
    }
    final trimmed = responseBody.trim();
    return trimmed.isEmpty ? '云歌词请求失败' : trimmed;
  }
}
