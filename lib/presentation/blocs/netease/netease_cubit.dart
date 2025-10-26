import 'package:bloc/bloc.dart';

import '../../../core/error/exceptions.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/entities/netease_entities.dart';
import '../../../domain/repositories/netease_repository.dart';
import 'netease_state.dart';

class NeteaseCubit extends Cubit<NeteaseState> {
  NeteaseCubit(this._repository) : super(const NeteaseState());

  final NeteaseRepository _repository;
  bool _hydrated = false;

  Future<void> hydrate() async {
    if (_hydrated) {
      return;
    }
    emit(state.copyWith(isInitializing: true, clearError: true));
    try {
      final session = await _repository.loadSession();
      final playlists = _repository.getCachedPlaylists();
      final tracks = _repository.getCachedPlaylistTracks();
      emit(
        state.copyWith(
          isInitializing: false,
          session: session,
          playlists: playlists,
          playlistTracks: tracks,
        ),
      );
      _hydrated = true;
      if (session != null) {
        await refreshPlaylists(showLoading: false);
      }
    } catch (e) {
      emit(state.copyWith(isInitializing: false, errorMessage: e.toString()));
    }
  }

  Future<bool> loginWithCookie(String rawCookie) async {
    final cookie = _normalizeCookie(rawCookie);
    if (cookie.isEmpty) {
      emit(state.copyWith(errorMessage: 'Cookie 不能为空'));
      return false;
    }
    emit(state.copyWith(isSubmittingCookie: true, clearError: true));
    try {
      final session = await _repository.loginWithCookie(cookie);
      emit(state.copyWith(isSubmittingCookie: false, session: session));
      await refreshPlaylists();
      return true;
    } on AuthenticationException catch (e) {
      emit(state.copyWith(isSubmittingCookie: false, errorMessage: e.message));
      return false;
    } catch (e) {
      emit(state.copyWith(isSubmittingCookie: false, errorMessage: '登录失败: $e'));
      return false;
    }
  }

  Future<void> refreshPlaylists({bool showLoading = true}) async {
    if (state.session == null) {
      return;
    }
    emit(state.copyWith(isLoadingPlaylists: showLoading, clearError: true));
    try {
      final playlists = await _repository.fetchUserPlaylists();
      emit(state.copyWith(isLoadingPlaylists: false, playlists: playlists));
    } catch (e) {
      emit(
        state.copyWith(isLoadingPlaylists: false, errorMessage: e.toString()),
      );
    }
  }

  Future<List<Track>> ensurePlaylistTracks(
    int playlistId, {
    bool force = false,
  }) async {
    final cached = state.playlistTracks[playlistId];
    if (!force && cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      final tracks = await _repository.fetchPlaylistTracks(playlistId);
      final updated = Map<int, List<Track>>.from(state.playlistTracks)
        ..[playlistId] = tracks;
      emit(state.copyWith(playlistTracks: updated));
      return tracks;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
      return const [];
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(
      state.copyWith(
        session: null,
        playlists: const [],
        playlistTracks: const {},
      ),
    );
  }

  Future<String?> addTrackToPlaylist(int playlistId, Track track) async {
    final message = await _repository.addTrackToPlaylist(playlistId, track);
    if (message == null) {
      final tracks = await _repository.fetchPlaylistTracks(playlistId);
      final updatedTracks = Map<int, List<Track>>.from(state.playlistTracks)
        ..[playlistId] = tracks;
      final updatedPlaylists = state.playlists
          .map(
            (playlist) => playlist.id == playlistId
                ? playlist.copyWith(trackCount: tracks.length)
                : playlist,
          )
          .toList();
      emit(
        state.copyWith(
          playlists: updatedPlaylists,
          playlistTracks: updatedTracks,
        ),
      );
    }
    if (message != null) {
      emit(state.copyWith(errorMessage: message));
    }
    return message;
  }

  void clearMessage() {
    emit(state.copyWith(clearError: true));
  }

  String _normalizeCookie(String raw) {
    var normalized = raw.trim();
    while (normalized.endsWith(';')) {
      normalized = normalized.substring(0, normalized.length - 1).trimRight();
    }
    return normalized;
  }
}
