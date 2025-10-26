import 'package:equatable/equatable.dart';

class NeteaseSession extends Equatable {
  const NeteaseSession({
    required this.cookie,
    required this.account,
    required this.updatedAt,
  });

  final String cookie;
  final NeteaseAccount account;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [cookie, account, updatedAt];
}

class NeteaseAccount extends Equatable {
  const NeteaseAccount({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
  });

  final int userId;
  final String nickname;
  final String? avatarUrl;

  @override
  List<Object?> get props => [userId, nickname, avatarUrl];
}

class NeteasePlaylist extends Equatable {
  const NeteasePlaylist({
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

  @override
  List<Object?> get props => [
        id,
        name,
        trackCount,
        playCount,
        creatorName,
        coverUrl,
        description,
        updatedAt,
      ];

  NeteasePlaylist copyWith({
    String? name,
    int? trackCount,
    int? playCount,
    String? creatorName,
    String? coverUrl,
    String? description,
    DateTime? updatedAt,
  }) {
    return NeteasePlaylist(
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
}
