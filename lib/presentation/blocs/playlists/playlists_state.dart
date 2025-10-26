part of 'playlists_cubit.dart';

class PlaylistsState extends Equatable {
  const PlaylistsState({
    this.isLoading = false,
    this.isProcessing = false,
    this.playlists = const [],
    this.playlistTracks = const {},
    this.errorMessage,
    this.sortMode = TrackSortMode.titleAZ,
  });

  final bool isLoading;
  final bool isProcessing;
  final List<Playlist> playlists;
  final Map<String, List<Track>> playlistTracks;
  final String? errorMessage;
  final TrackSortMode sortMode;

  PlaylistsState copyWith({
    bool? isLoading,
    bool? isProcessing,
    List<Playlist>? playlists,
    Map<String, List<Track>>? playlistTracks,
    String? errorMessage,
    bool clearError = false,
    TrackSortMode? sortMode,
  }) {
    return PlaylistsState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      playlists: playlists ?? this.playlists,
      playlistTracks: playlistTracks ?? this.playlistTracks,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      sortMode: sortMode ?? this.sortMode,
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
  ];
}
