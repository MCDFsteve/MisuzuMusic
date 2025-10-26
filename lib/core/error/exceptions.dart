// Custom exceptions for the Misuzu Music application
abstract class AppException implements Exception {
  final String message;
  final String? details;

  const AppException(this.message, [this.details]);

  @override
  String toString() {
    return details != null ? '$message: $details' : message;
  }
}

// Audio related exceptions
class AudioException extends AppException {
  const AudioException(super.message, [super.details]);
}

class AudioFormatNotSupportedException extends AudioException {
  const AudioFormatNotSupportedException(String format)
      : super('Audio format not supported', format);
}

class AudioFileNotFoundException extends AudioException {
  const AudioFileNotFoundException(String filePath)
      : super('Audio file not found', filePath);
}

class AudioPlaybackException extends AudioException {
  const AudioPlaybackException(String reason)
      : super('Audio playback failed', reason);
}

// File system exceptions
class FileSystemException extends AppException {
  const FileSystemException(super.message, [super.details]);
}

class DirectoryNotFoundException extends FileSystemException {
  const DirectoryNotFoundException(String path)
      : super('Directory not found', path);
}

class PermissionDeniedException extends FileSystemException {
  const PermissionDeniedException(String path)
      : super('Permission denied', path);
}

// Database exceptions
class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.details]);
}

// Authentication exceptions
class AuthenticationException extends AppException {
  const AuthenticationException(super.message, [super.details]);
}

// Lyrics processing exceptions
class LyricsException extends AppException {
  const LyricsException(super.message, [super.details]);
}

class LyricsParseException extends LyricsException {
  const LyricsParseException(String format)
      : super('Failed to parse lyrics', format);
}

// Japanese text processing exceptions
class JapaneseProcessingException extends AppException {
  const JapaneseProcessingException(super.message, [super.details]);
}

class MeCabInitializationException extends JapaneseProcessingException {
  const MeCabInitializationException()
      : super('Failed to initialize MeCab');
}

// Network exceptions (for future use)
class NetworkException extends AppException {
  const NetworkException(super.message, [super.details]);
}

class ConnectionTimeoutException extends NetworkException {
  const ConnectionTimeoutException()
      : super('Connection timeout');
}
