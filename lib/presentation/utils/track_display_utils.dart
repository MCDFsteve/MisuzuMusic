import 'package:path/path.dart' as p;

import '../../core/utils/track_field_normalizer.dart';
import '../../domain/entities/music_entities.dart';

class TrackDisplayInfo {
  const TrackDisplayInfo({
    required this.title,
    required this.artist,
    required this.album,
  });

  final String title;
  final String artist;
  final String album;
}

TrackDisplayInfo deriveTrackDisplayInfo(Track track) {
  final fallback = p.basenameWithoutExtension(track.filePath);
  final normalized = normalizeTrackFields(
    title: track.title,
    artist: track.artist,
    album: track.album,
    fallbackFileName: fallback,
  );

  return TrackDisplayInfo(
    title: normalized.title,
    artist: normalized.artist,
    album: normalized.album,
  );
}

Track applyDisplayInfo(Track track, TrackDisplayInfo info) {
  return track.copyWith(
    title: info.title,
    artist: info.artist,
    album: info.album,
  );
}

