import 'package:equatable/equatable.dart';

import '../../../domain/entities/music_entities.dart';
import '../../../domain/entities/netease_entities.dart';

class NeteaseState extends Equatable {
  const NeteaseState({
    this.isInitializing = true,
    this.isSubmittingCookie = false,
    this.isLoadingPlaylists = false,
    this.session,
    this.playlists = const [],
    this.playlistTracks = const {},
    this.errorMessage,
  });

  final bool isInitializing;
  final bool isSubmittingCookie;
  final bool isLoadingPlaylists;
  final NeteaseSession? session;
  final List<NeteasePlaylist> playlists;
  final Map<int, List<Track>> playlistTracks;
  final String? errorMessage;

  bool get hasSession => session != null;

  NeteaseState copyWith({
    bool? isInitializing,
    bool? isSubmittingCookie,
    bool? isLoadingPlaylists,
    NeteaseSession? session,
    List<NeteasePlaylist>? playlists,
    Map<int, List<Track>>? playlistTracks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NeteaseState(
      isInitializing: isInitializing ?? this.isInitializing,
      isSubmittingCookie: isSubmittingCookie ?? this.isSubmittingCookie,
      isLoadingPlaylists: isLoadingPlaylists ?? this.isLoadingPlaylists,
      session: session ?? this.session,
      playlists: playlists ?? this.playlists,
      playlistTracks: playlistTracks ?? this.playlistTracks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    isInitializing,
    isSubmittingCookie,
    isLoadingPlaylists,
    session,
    playlists,
    playlistTracks,
    errorMessage,
  ];
}
