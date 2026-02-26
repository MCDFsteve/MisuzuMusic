import '../../domain/entities/jellyfin_entities.dart';

class JellyfinSourceModel extends JellyfinSource {
  const JellyfinSourceModel({
    required super.id,
    required super.name,
    required super.baseUrl,
    required super.userId,
    required super.libraryId,
    super.username,
    super.libraryName,
    super.serverName,
    super.ignoreTls,
    super.createdAt,
    super.updatedAt,
  });

  factory JellyfinSourceModel.fromEntity(JellyfinSource source) {
    return JellyfinSourceModel(
      id: source.id,
      name: source.name,
      baseUrl: source.baseUrl,
      userId: source.userId,
      libraryId: source.libraryId,
      username: source.username,
      libraryName: source.libraryName,
      serverName: source.serverName,
      ignoreTls: source.ignoreTls,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
    );
  }

  factory JellyfinSourceModel.fromMap(Map<String, dynamic> map) {
    return JellyfinSourceModel(
      id: map['id'] as String,
      name: map['name'] as String,
      baseUrl: map['base_url'] as String,
      userId: map['user_id'] as String,
      libraryId: map['library_id'] as String,
      username: map['username'] as String?,
      libraryName: map['library_name'] as String?,
      serverName: map['server_name'] as String?,
      ignoreTls: map['ignore_tls'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'base_url': baseUrl,
      'user_id': userId,
      'library_id': libraryId,
      'username': username,
      'library_name': libraryName,
      'server_name': serverName,
      'ignore_tls': ignoreTls,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  JellyfinSource toEntity() => JellyfinSource(
        id: id,
        name: name,
        baseUrl: baseUrl,
        userId: userId,
        libraryId: libraryId,
        username: username,
        libraryName: libraryName,
        serverName: serverName,
        ignoreTls: ignoreTls,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
