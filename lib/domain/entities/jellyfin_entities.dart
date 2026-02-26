import 'package:equatable/equatable.dart';

class JellyfinLibrary extends Equatable {
  const JellyfinLibrary({
    required this.id,
    required this.name,
    this.collectionType,
  });

  final String id;
  final String name;
  final String? collectionType;

  @override
  List<Object?> get props => [id, name, collectionType];
}

class JellyfinAuthSession extends Equatable {
  const JellyfinAuthSession({
    required this.accessToken,
    required this.userId,
    this.serverName,
  });

  final String accessToken;
  final String userId;
  final String? serverName;

  @override
  List<Object?> get props => [accessToken, userId, serverName];
}

class JellyfinSource extends Equatable {
  const JellyfinSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.userId,
    required this.libraryId,
    this.username,
    this.libraryName,
    this.serverName,
    this.ignoreTls = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String userId;
  final String libraryId;
  final String? username;
  final String? libraryName;
  final String? serverName;
  final bool ignoreTls;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        id,
        name,
        baseUrl,
        userId,
        libraryId,
        username,
        libraryName,
        serverName,
        ignoreTls,
        createdAt,
        updatedAt,
      ];

  JellyfinSource copyWith({
    String? name,
    String? baseUrl,
    String? userId,
    String? libraryId,
    String? username,
    String? libraryName,
    String? serverName,
    bool? ignoreTls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JellyfinSource(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      userId: userId ?? this.userId,
      libraryId: libraryId ?? this.libraryId,
      username: username ?? this.username,
      libraryName: libraryName ?? this.libraryName,
      serverName: serverName ?? this.serverName,
      ignoreTls: ignoreTls ?? this.ignoreTls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
