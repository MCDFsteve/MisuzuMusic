class MysteryLibraryConstants {
  MysteryLibraryConstants._();

  static const String idPrefix = 'mystery';
  static const String defaultBaseUrl =
      'https://nipaplay.aimes-soft.com/music_library.php';

  static const String headerBaseUrl = 'x-mystery-base-url';
  static const String headerCode = 'x-mystery-code';
  static const String headerDisplayName = 'x-mystery-display-name';
  static const String headerCoverRemote = 'x-mystery-cover-remote';
  static const String headerThumbnailRemote = 'x-mystery-thumbnail-remote';
  static const String headerCoverLocal = 'x-mystery-cover-local';
  static const String headerThumbnailLocal = 'x-mystery-thumbnail-local';

  static String? buildArtworkUrl(
    Map<String, String>? headers, {
    bool thumbnail = true,
  }) {
    if (headers == null || headers.isEmpty) {
      return null;
    }

    final baseUrl = headers[headerBaseUrl];
    final code = headers[headerCode];
    if (baseUrl == null || baseUrl.isEmpty || code == null || code.isEmpty) {
      return null;
    }

    final remotePath = (thumbnail
            ? headers[headerThumbnailRemote]
            : headers[headerCoverRemote]) ??
        headers[headerCoverRemote];

    if (remotePath == null || remotePath.isEmpty) {
      return null;
    }

    final uri = Uri.parse(baseUrl);
    final query = <String, String>{
      ...uri.queryParameters,
      'action': thumbnail ? 'thumbnail' : 'cover',
      'code': code,
      'path': remotePath,
    };

    return uri.replace(queryParameters: query).toString();
  }
}
