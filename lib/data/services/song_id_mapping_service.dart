import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';

class SongIdMappingService {
  SongIdMappingService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Uri _buildUri(Map<String, Object?> query) {
    final entries = <String>[];
    query.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is Iterable) {
        for (final item in value) {
          if (item == null) continue;
          entries.add(
            '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(item.toString())}',
          );
        }
        return;
      }
      entries.add(
        '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value.toString())}',
      );
    });
    final base = AppConstants.songIdMappingEndpoint;
    if (entries.isEmpty) {
      return Uri.parse(base);
    }
    return Uri.parse('$base?${entries.join('&')}');
  }

  Future<int?> fetchNeteaseId(String hash) async {
    if (hash.isEmpty) {
      return null;
    }
    final uri = _buildUri({'hash': hash});
    final response = await _client.get(uri);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw SongIdServiceException(
        'GET ${uri.path} failed with status ${response.statusCode}',
      );
    }
    final payload = _decodeBody(response.body);
    final entries = payload['entries'];
    if (entries is Map) {
      final entry = entries[hash];
      if (entry is Map) {
        final id = entry['netease_id'];
        if (id is int) return id;
        if (id is String) return int.tryParse(id);
      }
    }
    return null;
  }

  Future<Map<String, int>> fetchNeteaseIds(Iterable<String> hashes) async {
    final sanitized = hashes.where((hash) => hash.isNotEmpty).toList();
    if (sanitized.isEmpty) {
      return const {};
    }
    final uri = _buildUri({'hash[]': sanitized});
    final response = await _client.get(uri);
    if (response.statusCode == 404) {
      return const {};
    }
    if (response.statusCode != 200) {
      throw SongIdServiceException(
        'GET ${uri.path} failed with status ${response.statusCode}',
      );
    }
    final payload = _decodeBody(response.body);
    final result = <String, int>{};
    final entries = payload['entries'];
    if (entries is Map) {
      entries.forEach((key, value) {
        if (value is Map) {
          final id = value['netease_id'];
          int? parsed;
          if (id is int) {
            parsed = id;
          } else if (id is String) {
            parsed = int.tryParse(id);
          }
          if (parsed != null) {
            result[key.toString()] = parsed;
          }
        }
      });
    }
    return result;
  }

  Future<void> saveMapping({
    required String hash,
    required int neteaseId,
    String? title,
    String? artist,
    String? album,
    String source = 'auto',
  }) async {
    if (hash.isEmpty) {
      throw SongIdServiceException('hash must not be empty');
    }
    if (neteaseId <= 0) {
      throw SongIdServiceException('neteaseId must be positive');
    }

    final uri = Uri.parse(AppConstants.songIdMappingEndpoint);
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: json.encode({
        'hash': hash,
        'netease_id': neteaseId,
        if (title != null && title.isNotEmpty) 'title': title,
        if (artist != null && artist.isNotEmpty) 'artist': artist,
        if (album != null && album.isNotEmpty) 'album': album,
        'source': source,
      }),
    );

    if (response.statusCode != 200) {
      throw SongIdServiceException(
        'POST ${uri.path} failed with status ${response.statusCode}',
      );
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return const {};
    }
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  void dispose() {
    _client.close();
  }
}

class SongIdServiceException implements Exception {
  SongIdServiceException(this.message);

  final String message;

  @override
  String toString() => 'SongIdServiceException: $message';
}
