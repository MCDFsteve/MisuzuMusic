import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';

class CloudPlaylistApi {
  CloudPlaylistApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> uploadPlaylist({
    required String remoteId,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse(AppConstants.cloudPlaylistEndpoint);
    final request = http.MultipartRequest('POST', uri)
      ..fields['action'] = 'upload'
      ..fields['id'] = remoteId
      ..files.add(
        http.MultipartFile.fromBytes(
          'playlist_file',
          bytes,
          filename: '$remoteId.msz',
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw NetworkException(_resolveErrorMessage(response.body));
    }

    final body = _decodeJson(response.body);
    final success = body['success'] as bool? ?? false;
    if (!success) {
      throw NetworkException(body['message'] as String? ?? '云端上传失败');
    }
  }

  Future<Uint8List> downloadPlaylist({required String remoteId}) async {
    final uri = Uri.parse(AppConstants.cloudPlaylistEndpoint).replace(
      queryParameters: {
        'action': 'download',
        'id': remoteId,
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw NetworkException(_resolveErrorMessage(response.body));
    }

    if (response.bodyBytes.isEmpty) {
      throw NetworkException('云端歌单内容为空');
    }

    return Uint8List.fromList(response.bodyBytes);
  }

  void dispose() {
    _client.close();
  }

  Map<String, dynamic> _decodeJson(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // swallow and fallback to empty map
    }
    return const {};
  }

  String _resolveErrorMessage(String raw) {
    final jsonBody = _decodeJson(raw);
    final message = jsonBody['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    if (raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return '云端请求失败';
  }
}
