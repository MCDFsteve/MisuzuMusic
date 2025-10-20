import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';

class NeteaseApiClient {
  NeteaseApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConstants.neteaseApiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  final Dio _dio;

  Future<String?> fetchSongCoverUrl(int songId) async {
    try {
      final response = await _dio.get(
        '/song/detail',
        queryParameters: {'ids': songId},
      );
      final data = response.data;
      if (data is! Map) {
        return null;
      }
      final songs = data['songs'];
      if (songs is! List || songs.isEmpty) {
        return null;
      }
      final song = songs.first;
      if (song is Map) {
        final album = song['al'];
        if (album is Map && album['picUrl'] is String) {
          return (album['picUrl'] as String).trim();
        }
      }
      return null;
    } catch (e) {
      print('⚠️ NeteaseApiClient: 获取歌曲封面失败 -> $e');
      return null;
    }
  }

  Future<Uint8List?> downloadImage(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        return null;
      }
      return Uint8List.fromList(data);
    } catch (e) {
      print('⚠️ NeteaseApiClient: 下载图片失败 -> $e');
      return null;
    }
  }

  Future<int?> searchSongId({
    required String title,
    String? artist,
  }) async {
    final keywords = _buildKeywords(title: title, artist: artist);
    if (keywords.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {
          'keywords': keywords,
          'limit': 5,
        },
      );
      final data = response.data;
      if (data is! Map) {
        return null;
      }
      final result = data['result'];
      if (result is! Map) {
        return null;
      }
      final songs = result['songs'];
      if (songs is! List || songs.isEmpty) {
        return null;
      }
      final first = songs.first;
      if (first is Map && first['id'] != null) {
        return int.tryParse(first['id'].toString());
      }
      return null;
    } catch (e) {
      print('⚠️ NeteaseApiClient: 搜索歌曲失败 -> $e');
      return null;
    }
  }

  Future<String?> fetchLyricsBySongId(int songId) async {
    try {
      final response = await _dio.get(
        '/lyric',
        queryParameters: {'id': songId},
      );
      final data = response.data;
      if (data is! Map) {
        return null;
      }
      final lrc = data['lrc'];
      if (lrc is Map && lrc['lyric'] is String) {
        return (lrc['lyric'] as String).trim();
      }
      return null;
    } catch (e) {
      print('⚠️ NeteaseApiClient: 获取歌词失败 -> $e');
      return null;
    }
  }

  String _buildKeywords({required String title, String? artist}) {
    final keywords = <String>[];
    final trimmedArtist = artist?.trim();
    if (trimmedArtist != null && trimmedArtist.isNotEmpty) {
      keywords.add(trimmedArtist);
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      keywords.add(trimmedTitle);
    }
    return keywords.join(' ');
  }
}
