class NormalizedTrackFields {
  const NormalizedTrackFields({
    required this.title,
    required this.artist,
    required this.album,
  });

  final String title;
  final String artist;
  final String album;
}

NormalizedTrackFields normalizeTrackFields({
  required String title,
  required String artist,
  required String album,
  required String fallbackFileName,
}) {
  String cleanTitle = title.trim();
  String cleanArtist = artist.trim();
  String cleanAlbum = album.trim();
  final String fallback = fallbackFileName.trim();

  if (cleanTitle.isEmpty) {
    cleanTitle = fallback;
  }

  final bool artistUnknown = isUnknownMetadataValue(cleanArtist);
  final bool albumUnknown = isUnknownMetadataValue(cleanAlbum);

  if (artistUnknown) {
    final _ArtistTitleParts? fromTitle = _splitArtistAndTitle(cleanTitle);
    final _ArtistTitleParts? fromFile =
        fromTitle ?? _splitArtistAndTitle(fallback);
    final _ArtistTitleParts? parts = fromTitle ?? fromFile;

    if (parts != null) {
      cleanArtist = parts.artist;
      cleanTitle = parts.title;
      if (albumUnknown) {
        cleanAlbum = cleanTitle;
      }
    } else {
      cleanTitle = fallback.isNotEmpty ? fallback : cleanTitle;
      if (albumUnknown) {
        cleanAlbum = cleanTitle;
      }
    }
  } else {
    if (cleanTitle.isEmpty) {
      cleanTitle = fallback.isNotEmpty ? fallback : cleanTitle;
    }
    if (albumUnknown) {
      cleanAlbum = cleanTitle;
    }
  }

  if (isUnknownMetadataValue(cleanAlbum)) {
    cleanAlbum = cleanTitle;
  }
  if (isUnknownMetadataValue(cleanArtist)) {
    cleanArtist = 'Unknown Artist';
  }
  if (cleanTitle.isEmpty) {
    cleanTitle = fallback.isNotEmpty ? fallback : 'Unknown Title';
  }

  return NormalizedTrackFields(
    title: cleanTitle,
    artist: cleanArtist,
    album: cleanAlbum,
  );
}

bool isUnknownMetadataValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return true;
  }
  final lower = trimmed.toLowerCase();
  switch (lower) {
    case 'unknown':
    case 'unknown artist':
    case 'unknown album':
    case 'unknown title':
    case 'unknown track':
    case '未知':
    case '未知艺术家':
    case '未知專輯':
    case '未知专辑':
      return true;
    default:
      return false;
  }
}

_ArtistTitleParts? _splitArtistAndTitle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final int hyphenIndex = trimmed.indexOf('-');
  if (hyphenIndex <= 0 || hyphenIndex >= trimmed.length - 1) {
    return null;
  }
  final String artist = trimmed.substring(0, hyphenIndex).trim();
  final String title = trimmed.substring(hyphenIndex + 1).trim();
  if (artist.isEmpty || title.isEmpty) {
    return null;
  }
  return _ArtistTitleParts(artist: artist, title: title);
}

class _ArtistTitleParts {
  const _ArtistTitleParts({required this.artist, required this.title});

  final String artist;
  final String title;
}
