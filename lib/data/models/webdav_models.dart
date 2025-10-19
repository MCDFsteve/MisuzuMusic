import '../../domain/entities/webdav_entities.dart';

class WebDavSourceModel extends WebDavSource {
  const WebDavSourceModel({
    required super.id,
    required super.name,
    required super.baseUrl,
    required super.rootPath,
    super.username,
    super.ignoreTls,
    super.createdAt,
    super.updatedAt,
  });

  factory WebDavSourceModel.fromEntity(WebDavSource source) {
    return WebDavSourceModel(
      id: source.id,
      name: source.name,
      baseUrl: source.baseUrl,
      rootPath: source.rootPath,
      username: source.username,
      ignoreTls: source.ignoreTls,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
    );
  }

  factory WebDavSourceModel.fromMap(Map<String, dynamic> map) {
    return WebDavSourceModel(
      id: map['id'] as String,
      name: map['name'] as String,
      baseUrl: map['base_url'] as String,
      rootPath: map['root_path'] as String,
      username: map['username'] as String?,
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
      'root_path': rootPath,
      'username': username,
      'ignore_tls': ignoreTls,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  WebDavSource toEntity() => WebDavSource(
    id: id,
    name: name,
    baseUrl: baseUrl,
    rootPath: rootPath,
    username: username,
    ignoreTls: ignoreTls,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
