import 'dart:convert';

import '../../domain/entities/music_entities.dart';

class NeteaseAccountModel {
  const NeteaseAccountModel({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
  });

  final int userId;
  final String nickname;
  final String? avatarUrl;

  factory NeteaseAccountModel.fromJson(Map<String, dynamic> json) {
    return NeteaseAccountModel(
      userId: json['userId'] as int,
      nickname: json['nickname'] as String? ?? '网络歌曲用户',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
  };
}

class NeteaseSessionModel {
  const NeteaseSessionModel({
    required this.cookie,
    required this.account,
    required this.updatedAt,
  });

  final String cookie;
  final NeteaseAccountModel account;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'cookie': cookie,
    'account': account.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory NeteaseSessionModel.fromJson(Map<String, dynamic> json) {
    return NeteaseSessionModel(
      cookie: json['cookie'] as String,
      account: NeteaseAccountModel.fromJson(
        Map<String, dynamic>.from(json['account'] as Map),
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  NeteaseSessionModel copyWith({String? cookie}) {
    return NeteaseSessionModel(
      cookie: cookie ?? this.cookie,
      account: account,
      updatedAt: DateTime.now(),
    );
  }
}

class NeteasePlaylistModel {
  const NeteasePlaylistModel({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.playCount,
    required this.creatorName,
    this.coverUrl,
    this.description,
    this.updatedAt,
  });

  final int id;
  final String name;
  final int trackCount;
  final int playCount;
  final String creatorName;
  final String? coverUrl;
  final String? description;
  final DateTime? updatedAt;

  factory NeteasePlaylistModel.fromApi(Map<String, dynamic> payload) {
    final creator = payload['creator'];
    return NeteasePlaylistModel(
      id: (payload['id'] as num).toInt(),
      name: payload['name'] as String? ?? '网络歌曲歌单',
      trackCount:
          (payload['trackCount'] as num?)?.toInt() ??
          (payload['tracks'] is List ? (payload['tracks'] as List).length : 0),
      playCount: (payload['playCount'] as num?)?.toInt() ?? 0,
      creatorName: creator is Map && creator['nickname'] is String
          ? creator['nickname'] as String
          : '网络歌曲用户',
      coverUrl: payload['coverImgUrl'] as String?,
      description: payload['description'] as String?,
      updatedAt: payload['updateTime'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (payload['updateTime'] as num).toInt(),
            )
          : null,
    );
  }

  factory NeteasePlaylistModel.fromJson(Map<String, dynamic> json) {
    return NeteasePlaylistModel(
      id: json['id'] as int,
      name: json['name'] as String,
      trackCount: json['trackCount'] as int,
      playCount: json['playCount'] as int,
      creatorName: json['creatorName'] as String,
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }

  NeteasePlaylistModel copyWith({
    int? trackCount,
    int? playCount,
    String? name,
    String? creatorName,
    String? coverUrl,
    String? description,
    DateTime? updatedAt,
  }) {
    return NeteasePlaylistModel(
      id: id,
      name: name ?? this.name,
      trackCount: trackCount ?? this.trackCount,
      playCount: playCount ?? this.playCount,
      creatorName: creatorName ?? this.creatorName,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trackCount': trackCount,
    'playCount': playCount,
    'creatorName': creatorName,
    'coverUrl': coverUrl,
    'description': description,
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

class NeteaseTrackModel {
  const NeteaseTrackModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.coverUrl,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String? coverUrl;

  factory NeteaseTrackModel.fromApi(Map<String, dynamic> payload) {
    final artists = payload['ar'] as List? ?? payload['artists'] as List? ?? [];
    final artistName = artists.isEmpty
        ? '未知艺人'
        : artists
              .map(
                (artist) => artist is Map && artist['name'] is String
                    ? artist['name'] as String
                    : '',
              )
              .where((name) => name.isNotEmpty)
              .join('、');
    final album = payload['al'] ?? payload['album'];
    final albumName = album is Map && album['name'] is String
        ? album['name'] as String
        : '未知专辑';
    final cover = album is Map && album['picUrl'] is String
        ? album['picUrl'] as String
        : null;
    return NeteaseTrackModel(
      id: (payload['id'] as num).toInt(),
      title: payload['name'] as String? ?? '未知曲目',
      artist: artistName.isEmpty ? '未知艺人' : artistName,
      album: albumName,
      durationMs:
          (payload['dt'] as num?)?.toInt() ??
          (payload['duration'] as num?)?.toInt() ??
          0,
      coverUrl: cover,
    );
  }

  factory NeteaseTrackModel.fromJson(Map<String, dynamic> json) {
    return NeteaseTrackModel(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      durationMs: json['durationMs'] as int,
      coverUrl: json['coverUrl'] as String?,
    );
  }

  factory NeteaseTrackModel.fromTrack(Track track) {
    final neteaseId =
        int.tryParse(track.sourceId ?? track.id.replaceFirst('netease_', '')) ??
        0;
    return NeteaseTrackModel(
      id: neteaseId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationMs: track.duration.inMilliseconds,
      coverUrl: track.httpHeaders?['x-netease-cover'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'coverUrl': coverUrl,
  };

import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../domain/entities/music_entities.dart';

class NeteaseAccountModel {
  const NeteaseAccountModel({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
  });
// ... (rest of NeteaseAccountModel) ...
}

// ... (NeteaseSessionModel and NeteasePlaylistModel remain unchanged) ...

class NeteaseTrackModel {
  // ... (fields and other methods) ...

  Track toPlayerTrack({required String cookie}) {
    final now = DateTime.now();
    final uniqueId = 'netease_$id';
    final hash = sha1.convert(utf8.encode(uniqueId)).toString();
    return Track(
      id: uniqueId,
      title: title,
      artist: artist,
      album: album,
      filePath: 'netease://$id',
      duration: Duration(milliseconds: durationMs),
      dateAdded: now,
      artworkPath: null,
      sourceType: TrackSourceType.netease,
      sourceId: id.toString(),
      remotePath: '/song/$id',
      httpHeaders: {
        'Cookie': cookie,
        if (coverUrl != null) 'x-netease-cover': coverUrl!,
      },
      contentHash: hash,
    );
  }
}
// ... (rest of file) ...
}

class NeteaseSongCandidate {
  const NeteaseSongCandidate({
    required this.id,
    required this.title,
    required this.artists,
    required this.album,
    required this.durationMs,
    this.aliases = const [],
  });

  final int id;
  final String title;
  final List<String> artists;
  final String album;
  final int durationMs;
  final List<String> aliases;

  String get displayArtists => artists.join(', ');

  String get durationLabel {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String? get aliasLabel => aliases.isEmpty ? null : aliases.first;
}

class NeteaseTrackStreamInfo {
  const NeteaseTrackStreamInfo({required this.url, required this.cookie});

  final String url;
  final String cookie;
}

class NeteaseCachePayload {
  const NeteaseCachePayload({
    this.session,
    this.playlists = const [],
    this.playlistTracks = const {},
  });

  final NeteaseSessionModel? session;
  final List<NeteasePlaylistModel> playlists;
  final Map<int, List<NeteaseTrackModel>> playlistTracks;

  factory NeteaseCachePayload.empty() => const NeteaseCachePayload();

  NeteaseCachePayload copyWith({
    NeteaseSessionModel? session,
    bool clearSession = false,
    List<NeteasePlaylistModel>? playlists,
    Map<int, List<NeteaseTrackModel>>? playlistTracks,
  }) {
    return NeteaseCachePayload(
      session: clearSession ? null : (session ?? this.session),
      playlists: playlists ?? this.playlists,
      playlistTracks: playlistTracks ?? this.playlistTracks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session': session?.toJson(),
      'playlists': playlists.map((e) => e.toJson()).toList(),
      'playlistTracks': playlistTracks.map(
        (key, value) =>
            MapEntry(key.toString(), value.map((e) => e.toJson()).toList()),
      ),
    };
  }

  factory NeteaseCachePayload.fromJson(Map<String, dynamic> json) {
    final sessionJson = json['session'];
    final playlistsJson = json['playlists'] as List? ?? const [];
    final tracksJson = json['playlistTracks'] as Map? ?? const {};

    return NeteaseCachePayload(
      session: sessionJson is Map
          ? NeteaseSessionModel.fromJson(Map<String, dynamic>.from(sessionJson))
          : null,
      playlists: playlistsJson
          .whereType<Map>()
          .map(
            (item) => NeteasePlaylistModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      playlistTracks: tracksJson.map((key, value) {
        final entries = value is List ? value : const [];
        final parsed = entries
            .whereType<Map>()
            .map(
              (item) => NeteaseTrackModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
        return MapEntry(int.parse(key.toString()), parsed);
      }),
    );
  }

  static NeteaseCachePayload fromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return NeteaseCachePayload.empty();
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) {
        return NeteaseCachePayload.fromJson(decoded);
      }
      return NeteaseCachePayload.empty();
    } catch (_) {
      return NeteaseCachePayload.empty();
    }
  }
}
