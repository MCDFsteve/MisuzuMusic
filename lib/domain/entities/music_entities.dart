import 'package:equatable/equatable.dart';

// Base entity class
abstract class Entity extends Equatable {
  const Entity();
}

// Track entity - represents a music track
class Track extends Entity {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Duration duration;
  final DateTime dateAdded;
  final String? artworkPath;
  final int? trackNumber;
  final int? year;
  final String? genre;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.duration,
    required this.dateAdded,
    this.artworkPath,
    this.trackNumber,
    this.year,
    this.genre,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        album,
        filePath,
        duration,
        dateAdded,
        artworkPath,
        trackNumber,
        year,
        genre,
      ];

  Track copyWith({
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
    return Track(
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

// Artist entity
class Artist extends Entity {
  final String name;
  final int trackCount;
  final String? artworkPath;

  const Artist({
    required this.name,
    required this.trackCount,
    this.artworkPath,
  });

  @override
  List<Object?> get props => [name, trackCount, artworkPath];
}

// Album entity
class Album extends Entity {
  final String title;
  final String artist;
  final int trackCount;
  final int? year;
  final String? artworkPath;
  final Duration totalDuration;

  const Album({
    required this.title,
    required this.artist,
    required this.trackCount,
    this.year,
    this.artworkPath,
    required this.totalDuration,
  });

  @override
  List<Object?> get props => [
        title,
        artist,
        trackCount,
        year,
        artworkPath,
        totalDuration,
      ];
}

// Playlist entity
class Playlist extends Entity {
  final String id;
  final String name;
  final List<String> trackIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object> get props => [id, name, trackIds, createdAt, updatedAt];

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PlaybackHistoryEntry extends Entity {
  const PlaybackHistoryEntry({
    required this.track,
    required this.playedAt,
    this.playCount = 1,
    this.fingerprint,
  });

  final Track track;
  final DateTime playedAt;
  final int playCount;
  final String? fingerprint;

  @override
  List<Object?> get props => [track, playedAt, playCount, fingerprint];

  PlaybackHistoryEntry copyWith({
    Track? track,
    DateTime? playedAt,
    int? playCount,
    String? fingerprint,
  }) {
    return PlaybackHistoryEntry(
      track: track ?? this.track,
      playedAt: playedAt ?? this.playedAt,
      playCount: playCount ?? this.playCount,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }
}
