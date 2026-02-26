class JellyfinLibraryConstants {
  JellyfinLibraryConstants._();

  static const String headerImageUrl = 'x-jellyfin-image-url';
  static const String headerItemId = 'x-jellyfin-item-id';
  static const String headerLibraryId = 'x-jellyfin-library-id';
  static const String headerServerName = 'x-jellyfin-server-name';

  static String? buildArtworkUrl(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return null;
    }
    final url = headers[headerImageUrl];
    if (url == null || url.isEmpty) {
      return null;
    }
    return url;
  }
}
