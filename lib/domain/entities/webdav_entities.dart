import 'package:equatable/equatable.dart';

class WebDavSource extends Equatable {
  const WebDavSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.rootPath,
    this.username,
    this.ignoreTls = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String rootPath;
  final String? username;
  final bool ignoreTls;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        id,
        name,
        baseUrl,
        rootPath,
        username,
        ignoreTls,
        createdAt,
        updatedAt,
      ];

  WebDavSource copyWith({
    String? name,
    String? baseUrl,
    String? rootPath,
    String? username,
    bool? ignoreTls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WebDavSource(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      rootPath: rootPath ?? this.rootPath,
      username: username ?? this.username,
      ignoreTls: ignoreTls ?? this.ignoreTls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WebDavEntry extends Equatable {
  const WebDavEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
  });

  final String name;
  final String path;
  final bool isDirectory;

  @override
  List<Object?> get props => [name, path, isDirectory];
}
