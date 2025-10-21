import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/music_entities.dart';
import '../../../domain/repositories/music_library_repository.dart';

part 'playlists_state.dart';

class PlaylistsCubit extends Cubit<PlaylistsState> {
  PlaylistsCubit(this._repository) : super(const PlaylistsState()) {
    loadPlaylists();
  }

  final MusicLibraryRepository _repository;
  final Uuid _uuid = const Uuid();

  Future<void> loadPlaylists() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final playlists = await _repository.getAllPlaylists();
      final updatedTracks = Map<String, List<Track>>.from(state.playlistTracks)
        ..removeWhere(
          (key, value) => playlists.every((playlist) => playlist.id != key),
        );
      emit(
        state.copyWith(
          isLoading: false,
          playlists: playlists,
          playlistTracks: updatedTracks,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> refreshPlaylist(String playlistId) async {
    try {
      final refreshed = await _repository.getPlaylistById(playlistId);
      if (refreshed == null) {
        final updatedPlaylists = state.playlists
            .where((element) => element.id != playlistId)
            .toList();
        emit(state.copyWith(playlists: updatedPlaylists));
        final updatedTracks = Map<String, List<Track>>.from(
          state.playlistTracks,
        )..remove(playlistId);
        emit(state.copyWith(playlistTracks: updatedTracks));
        return;
      }
      final playlists = state.playlists
          .map((p) => p.id == playlistId ? refreshed : p)
          .toList();
      emit(state.copyWith(playlists: playlists));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> ensurePlaylistTracks(
    String playlistId, {
    bool force = false,
  }) async {
    if (!force && state.playlistTracks.containsKey(playlistId)) {
      return;
    }
    try {
      final tracks = await _repository.getPlaylistTracks(playlistId);
      final updated = Map<String, List<Track>>.from(state.playlistTracks)
        ..[playlistId] = tracks;
      emit(state.copyWith(playlistTracks: updated));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<String?> createPlaylist({
    required String name,
    String? description,
    String? coverPath,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: '歌单名称不能为空'));
      return null;
    }
    emit(state.copyWith(isProcessing: true, clearError: true));
    try {
      final playlist = Playlist(
        id: _uuid.v4(),
        name: trimmedName,
        trackIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        coverPath: coverPath?.trim().isEmpty == true ? null : coverPath?.trim(),
      );
      await _repository.createPlaylist(playlist);
      await loadPlaylists();
      emit(state.copyWith(isProcessing: false, clearError: true));
      return playlist.id;
    } catch (e) {
      emit(state.copyWith(isProcessing: false, errorMessage: e.toString()));
      return null;
    }
  }

  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    emit(state.copyWith(isProcessing: true, clearError: true));
    try {
      Playlist? playlist;
      for (final item in state.playlists) {
        if (item.id == playlistId) {
          playlist = item;
          break;
        }
      }
      playlist ??= await _repository.getPlaylistById(playlistId);
      if (playlist == null) {
        emit(state.copyWith(isProcessing: false));
        return false;
      }
      final trackHash = track.contentHash ?? track.id;
      if (playlist.trackIds.contains(trackHash)) {
        emit(state.copyWith(isProcessing: false));
        return false;
      }
      await _repository.addTrackToPlaylist(playlistId, trackHash);
      await loadPlaylists();
      await ensurePlaylistTracks(playlistId, force: true);
      emit(state.copyWith(isProcessing: false, clearError: true));
      return true;
    } catch (e) {
      emit(state.copyWith(isProcessing: false, errorMessage: e.toString()));
      return false;
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, Track track) async {
    emit(state.copyWith(isProcessing: true, clearError: true));
    try {
      final trackHash = track.contentHash ?? track.id;
      await _repository.removeTrackFromPlaylist(playlistId, trackHash);
      await loadPlaylists();
      await ensurePlaylistTracks(playlistId, force: true);
      emit(state.copyWith(isProcessing: false, clearError: true));
    } catch (e) {
      emit(state.copyWith(isProcessing: false, errorMessage: e.toString()));
    }
  }
}
