part of 'playlists_cubit.dart';

class PlaylistsState extends Equatable {
  const PlaylistsState({
    this.isLoading = false,
    this.isProcessing = false,
    this.playlists = const [],
    this.playlistTracks = const {},
    this.errorMessage,
  });

  final bool isLoading;
  final bool isProcessing;
  final List<Playlist> playlists;
  final Map<String, List<Track>> playlistTracks;
  final String? errorMessage;

  PlaylistsState copyWith({
    bool? isLoading,
    bool? isProcessing,
    List<Playlist>? playlists,
    Map<String, List<Track>>? playlistTracks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlaylistsState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      playlists: playlists ?? this.playlists,
      playlistTracks: playlistTracks ?? this.playlistTracks,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isProcessing,
    playlists,
    playlistTracks,
    errorMessage,
  ];
}
