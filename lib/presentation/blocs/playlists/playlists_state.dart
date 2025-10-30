part of 'playlists_cubit.dart';

class PlaylistAutoSyncConfig extends Equatable {
  const PlaylistAutoSyncConfig({required this.remoteId, this.enabled = true});

  final String remoteId;
  final bool enabled;

  PlaylistAutoSyncConfig copyWith({String? remoteId, bool? enabled}) {
    return PlaylistAutoSyncConfig(
      remoteId: remoteId ?? this.remoteId,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {'remoteId': remoteId, 'enabled': enabled};
  }

  static PlaylistAutoSyncConfig? fromMap(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return PlaylistAutoSyncConfig(remoteId: trimmed);
    }
    if (value is Map<String, dynamic>) {
      final remoteId = (value['remoteId'] as String?)?.trim();
      if (remoteId == null || remoteId.isEmpty) {
        return null;
      }
      final enabled = value['enabled'] is bool
          ? value['enabled'] as bool
          : true;
      return PlaylistAutoSyncConfig(remoteId: remoteId, enabled: enabled);
    }
    if (value is Map) {
      final remoteId = (value['remoteId'] as String?)?.trim();
      if (remoteId == null || remoteId.isEmpty) {
        return null;
      }
      final enabled = value['enabled'] is bool
          ? value['enabled'] as bool
          : true;
      return PlaylistAutoSyncConfig(remoteId: remoteId, enabled: enabled);
    }
    return null;
  }

  @override
  List<Object?> get props => [remoteId, enabled];
}

class PlaylistsState extends Equatable {
  const PlaylistsState({
    this.isLoading = false,
    this.isProcessing = false,
    this.playlists = const [],
    this.playlistTracks = const {},
    this.errorMessage,
    this.sortMode = TrackSortMode.titleAZ,
    this.autoSyncSettings = const {},
  });

  final bool isLoading;
  final bool isProcessing;
  final List<Playlist> playlists;
  final Map<String, List<Track>> playlistTracks;
  final String? errorMessage;
  final TrackSortMode sortMode;
  final Map<String, PlaylistAutoSyncConfig> autoSyncSettings;

  PlaylistsState copyWith({
    bool? isLoading,
    bool? isProcessing,
    List<Playlist>? playlists,
    Map<String, List<Track>>? playlistTracks,
    String? errorMessage,
    bool clearError = false,
    TrackSortMode? sortMode,
    Map<String, PlaylistAutoSyncConfig>? autoSyncSettings,
  }) {
    return PlaylistsState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      playlists: playlists ?? this.playlists,
      playlistTracks: playlistTracks ?? this.playlistTracks,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      sortMode: sortMode ?? this.sortMode,
      autoSyncSettings: autoSyncSettings ?? this.autoSyncSettings,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isProcessing,
    playlists,
    playlistTracks,
    errorMessage,
    sortMode,
    autoSyncSettings,
  ];
}
