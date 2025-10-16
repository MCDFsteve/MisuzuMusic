import '../../domain/entities/music_entities.dart';

class TrackModel extends Track {
  const TrackModel({
    required super.id,
    required super.title,
    required super.artist,
    required super.album,
    required super.filePath,
    required super.duration,
    required super.dateAdded,
    super.artworkPath,
    super.trackNumber,
    super.year,
    super.genre,
  });

  // Convert from domain entity
  factory TrackModel.fromEntity(Track track) {
    return TrackModel(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      filePath: track.filePath,
      duration: track.duration,
      dateAdded: track.dateAdded,
      artworkPath: track.artworkPath,
      trackNumber: track.trackNumber,
      year: track.year,
      genre: track.genre,
    );
  }

  // Convert from database map
  factory TrackModel.fromMap(Map<String, dynamic> map) {
    return TrackModel(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      filePath: map['file_path'] as String,
      duration: Duration(milliseconds: map['duration_ms'] as int),
      dateAdded: DateTime.fromMillisecondsSinceEpoch(map['date_added'] as int),
      artworkPath: map['artwork_path'] as String?,
      trackNumber: map['track_number'] as int?,
      year: map['year'] as int?,
      genre: map['genre'] as String?,
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'file_path': filePath,
      'duration_ms': duration.inMilliseconds,
      'date_added': dateAdded.millisecondsSinceEpoch,
      'artwork_path': artworkPath,
      'track_number': trackNumber,
      'year': year,
      'genre': genre,
    };
  }

  // Convert to domain entity
  Track toEntity() {
    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      filePath: filePath,
      duration: duration,
      dateAdded: dateAdded,
      artworkPath: artworkPath,
      trackNumber: trackNumber,
      year: year,
      genre: genre,
    );
  }

  @override
  TrackModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? filePath,
    Duration? duration,
    DateTime? dateAdded,
    String? artworkPath,
    int? trackNumber,
    int? year,
    String? genre,
  }) {
    return TrackModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      dateAdded: dateAdded ?? this.dateAdded,
      artworkPath: artworkPath ?? this.artworkPath,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
    );
  }
}

class ArtistModel extends Artist {
  const ArtistModel({
    required super.name,
    required super.trackCount,
    super.artworkPath,
  });

  factory ArtistModel.fromEntity(Artist artist) {
    return ArtistModel(
      name: artist.name,
      trackCount: artist.trackCount,
      artworkPath: artist.artworkPath,
    );
  }

  factory ArtistModel.fromMap(Map<String, dynamic> map) {
    return ArtistModel(
      name: map['name'] as String,
      trackCount: map['track_count'] as int,
      artworkPath: map['artwork_path'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'track_count': trackCount,
      'artwork_path': artworkPath,
    };
  }

  Artist toEntity() {
    return Artist(
      name: name,
      trackCount: trackCount,
      artworkPath: artworkPath,
    );
  }
}

class AlbumModel extends Album {
  const AlbumModel({
    required super.title,
    required super.artist,
    required super.trackCount,
    super.year,
    super.artworkPath,
    required super.totalDuration,
  });

  factory AlbumModel.fromEntity(Album album) {
    return AlbumModel(
      title: album.title,
      artist: album.artist,
      trackCount: album.trackCount,
      year: album.year,
      artworkPath: album.artworkPath,
      totalDuration: album.totalDuration,
    );
  }

  factory AlbumModel.fromMap(Map<String, dynamic> map) {
    return AlbumModel(
      title: map['title'] as String,
      artist: map['artist'] as String,
      trackCount: map['track_count'] as int,
      year: map['year'] as int?,
      artworkPath: map['artwork_path'] as String?,
      totalDuration: Duration(milliseconds: map['total_duration_ms'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'track_count': trackCount,
      'year': year,
      'artwork_path': artworkPath,
      'total_duration_ms': totalDuration.inMilliseconds,
    };
  }

  Album toEntity() {
    return Album(
      title: title,
      artist: artist,
      trackCount: trackCount,
      year: year,
      artworkPath: artworkPath,
      totalDuration: totalDuration,
    );
  }
}

class PlaylistModel extends Playlist {
  const PlaylistModel({
    required super.id,
    required super.name,
    required super.trackIds,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PlaylistModel.fromEntity(Playlist playlist) {
    return PlaylistModel(
      id: playlist.id,
      name: playlist.name,
      trackIds: playlist.trackIds,
      createdAt: playlist.createdAt,
      updatedAt: playlist.updatedAt,
    );
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] as String,
      name: map['name'] as String,
      trackIds: [], // Will be populated separately from playlist_tracks table
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Playlist toEntity() {
    return Playlist(
      id: id,
      name: name,
      trackIds: trackIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  PlaylistModel copyWith({
    String? id,
    String? name,
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}