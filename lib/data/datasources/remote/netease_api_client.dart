import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../models/netease_models.dart';

class NeteaseApiClient {
  NeteaseApiClient({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppConstants.neteaseApiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/126.0.0.0 Safari/537.36';

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
      //print('⚠️ NeteaseApiClient: 获取歌曲封面失败 -> $e');
      return null;
    }
  }

  Options _authOptions(String cookie) {
    return Options(
      headers: {
        'Cookie': cookie,
        'User-Agent': _userAgent,
        'Referer': 'https://music.163.com',
      },
    );
  }

  Future<NeteaseAccountModel?> fetchAccountProfile(String cookie) async {
    try {
      final response = await _dio.get(
        '/user/account',
        options: _authOptions(cookie),
      );
      final data = response.data;
      if (data is! Map) {
        return null;
      }
      final account = data['profile'];
      if (account is! Map) {
        return null;
      }
      return NeteaseAccountModel.fromJson(
        Map<String, dynamic>.from(account as Map),
      );
    } catch (e) {
      //print('⚠️ NeteaseApiClient: 获取账号信息失败 -> $e');
      return null;
    }
  }

  Future<List<NeteasePlaylistModel>> fetchUserPlaylists({
    required String cookie,
    required int userId,
  }) async {
    try {
      final response = await _dio.get(
        '/user/playlist',
        options: _authOptions(cookie),
        queryParameters: {'uid': userId, 'limit': 200, 'offset': 0},
      );
      final data = response.data;
      if (data is! Map) {
        return const [];
      }
      final playlists = data['playlist'];
      if (playlists is! List) {
        return const [];
      }
      return playlists
          .whereType<Map>()
          .map(
            (item) => NeteasePlaylistModel.fromApi(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      //print('⚠️ NeteaseApiClient: 获取用户歌单失败 -> $e');
      return const [];
    }
  }

  Future<List<NeteaseTrackModel>?> fetchPlaylistTracks({
    required String cookie,
    required int playlistId,
  }) async {
    try {
      final response = await _dio.get(
        '/playlist/track/all',
        options: _authOptions(cookie),
        queryParameters: {'id': playlistId, 'limit': 500, 'offset': 0},
      );
      final data = response.data;
      if (data is! Map) {
        return null;
      }
      final songs = data['songs'];
      if (songs is! List) {
        return null;
      }
      return songs
          .whereType<Map>()
          .map(
            (item) => NeteaseTrackModel.fromApi(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      //print('⚠️ NeteaseApiClient: 获取歌单歌曲失败 -> $e');
      return null;
    }
  }

  Future<NeteaseTrackStreamInfo?> fetchTrackStream({
    required String cookie,
    required int trackId,
  }) async {
    try {
      final response = await _dio.get(
        '/song/url/v1',
        options: _authOptions(cookie),
        queryParameters: {'id': trackId, 'level': 'standard'},
      );
      final data = response.data;
      if (data is! Map) {
        return null;
      }
      final payload = data['data'];
      if (payload is! List || payload.isEmpty) {
        return null;
      }
      final first = payload.first;
      if (first is! Map) {
        return null;
      }
      final url = first['url'] as String?;
      if (url == null || url.isEmpty) {
        return null;
      }
      return NeteaseTrackStreamInfo(url: url, cookie: cookie);
    } catch (e) {
      //print('⚠️ NeteaseApiClient: 获取音频地址失败 -> $e');
      return null;
    }
  }

  Future<bool> addTrackToPlaylist({
    required String cookie,
    required int playlistId,
    required int trackId,
  }) async {
    try {
      final response = await _dio.get(
        '/playlist/tracks',
        options: _authOptions(cookie),
        queryParameters: {'op': 'add', 'pid': playlistId, 'tracks': trackId},
      );
      final data = response.data;
      if (data is Map && (data['code'] == 200 || data['status'] == 200)) {
        return true;
      }
      return false;
    } catch (e) {
      //print('⚠️ NeteaseApiClient: 添加歌曲到歌单失败 -> $e');
      return false;
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
      //print('⚠️ NeteaseApiClient: 下载图片失败 -> $e');
      return null;
    }
  }

  Future<int?> searchSongId({required String title, String? artist}) async {
    final keywords = _buildKeywords(title: title, artist: artist);
    if (keywords.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {'keywords': keywords, 'limit': 5},
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
      //print('⚠️ NeteaseApiClient: 搜索歌曲失败 -> $e');
      return null;
    }
  }

  Future<List<NeteaseSongCandidate>> searchSongCandidates({
    required String keyword,
    String? artist,
    int limit = 10,
  }) async {
    final combined = _buildKeywords(title: keyword, artist: artist);
    if (combined.isEmpty) {
      return const [];
    }
    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {'keywords': combined, 'limit': limit.clamp(1, 50)},
      );
      final data = response.data;
      if (data is! Map) {
        return const [];
      }
      final result = data['result'];
      if (result is! Map) {
        return const [];
      }
      final songs = result['songs'];
      if (songs is! List) {
        return const [];
      }
      final candidates = <NeteaseSongCandidate>[];
      for (final entry in songs) {
        if (entry is! Map) {
          continue;
        }
        final idRaw = entry['id'];
        final id = switch (idRaw) {
          int value => value,
          num value => value.toInt(),
          String value => int.tryParse(value),
          _ => null,
        };
        if (id == null) {
          continue;
        }

        final title = (entry['name'] as String?)?.trim();
        if (title == null || title.isEmpty) {
          continue;
        }

        final artistsPayload =
            entry['ar'] as List? ?? entry['artists'] as List? ?? const [];
        final artists = <String>[];
        for (final artistEntry in artistsPayload) {
          if (artistEntry is Map && artistEntry['name'] is String) {
            final name = (artistEntry['name'] as String).trim();
            if (name.isNotEmpty) {
              artists.add(name);
            }
          }
        }
        if (artists.isEmpty) {
          artists.add('未知艺人');
        }

        final albumPayload = entry['al'] ?? entry['album'];
        String albumName = '未知专辑';
        if (albumPayload is Map && albumPayload['name'] is String) {
          final name = (albumPayload['name'] as String).trim();
          if (name.isNotEmpty) {
            albumName = name;
          }
        }

        final aliasesRaw =
            entry['alia'] as List? ?? entry['alias'] as List? ?? const [];
        final aliases = aliasesRaw
            .whereType<String>()
            .map((alias) => alias.trim())
            .where((alias) => alias.isNotEmpty)
            .toList();

        final durationMs =
            (entry['dt'] as num?)?.toInt() ??
            (entry['duration'] as num?)?.toInt() ??
            0;

        candidates.add(
          NeteaseSongCandidate(
            id: id,
            title: title,
            artists: artists,
            album: albumName,
            durationMs: durationMs,
            aliases: aliases,
          ),
        );
      }
      return candidates;
    } catch (error) {
      // ignore: avoid_print
      //print('⚠️ NeteaseApiClient: 搜索歌曲列表失败 -> $error');
      return const [];
    }
  }

  Future<NeteaseLyricResult?> fetchLyricsBySongId(int songId) async {
    try {
      final response = await _dio.get(
        '/lyric',
        queryParameters: {'id': songId, 'lv': -1, 'tv': -1},
      );
      final data = response.data;
      if (data is! Map) {
        return null;
      }
      final original = _extractLyricText(data['lrc']);
      final translated = _extractLyricText(data['tlyric']);
      if (original == null && translated == null) {
        return null;
      }
      return NeteaseLyricResult(original: original, translated: translated);
    } catch (e) {
      //print('⚠️ NeteaseApiClient: 获取歌词失败 -> $e');
      return null;
    }
  }

  String? _extractLyricText(dynamic payload) {
    if (payload is! Map) {
      return null;
    }
    final lyric = payload['lyric'];
    if (lyric is! String) {
      return null;
    }
    final trimmed = lyric.trim();
    return trimmed.isEmpty ? null : trimmed;
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

class NeteaseLyricResult {
  const NeteaseLyricResult({this.original, this.translated});

  final String? original;
  final String? translated;

  bool get hasOriginal => original != null && original!.isNotEmpty;
  bool get hasTranslated => translated != null && translated!.isNotEmpty;
}
