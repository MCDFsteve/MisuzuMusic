import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/storage/binary_config_store.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/repositories/music_library_repository.dart';

part 'playlists_state.dart';

class PlaylistsCubit extends Cubit<PlaylistsState> {
  PlaylistsCubit(this._repository, this._configStore)
    : super(const PlaylistsState()) {
    unawaited(_initialize());
  }

  final MusicLibraryRepository _repository;
  final BinaryConfigStore _configStore;
  final Uuid _uuid = const Uuid();
  static final RegExp _cloudIdPattern = RegExp(r'^[A-Za-z0-9_]{5,}$');
  static const String _cloudIdRuleMessage = '云端ID需至少5位，只能包含字母、数字或下划线';

  Future<void> _initialize() async {
    try {
      await _configStore.init();
    } catch (e) {
      print('❌ PlaylistsCubit: 初始化配置存储失败: $e');
    }
    await _initializeSortMode();
    await _loadAutoSyncSettings();
    await loadPlaylists();
    unawaited(_pullAutoSyncedPlaylistsFromCloud());
  }

  Future<void> _initializeSortMode() async {
    try {
      final sortModeString = _configStore.getValue<String>(
        StorageKeys.playlistSortMode,
      );
      final sortMode = TrackSortModeExtension.fromStorageString(sortModeString);
      emit(state.copyWith(sortMode: sortMode));
    } catch (e) {
      print('❌ PlaylistsCubit: 加载排序模式失败: $e');
    }
  }

  Future<void> _loadAutoSyncSettings() async {
    try {
      final raw = _configStore.getValue<Map<String, dynamic>>(
        StorageKeys.playlistAutoSyncSettings,
      );
      if (raw == null || raw.isEmpty) {
        emit(state.copyWith(autoSyncSettings: const {}));
        return;
      }

      final parsed = <String, PlaylistAutoSyncConfig>{};
      var changed = false;

      raw.forEach((key, value) {
        final config = PlaylistAutoSyncConfig.fromMap(value);
        if (config != null) {
          parsed[key] = config;
        } else {
          changed = true;
        }
      });

      emit(state.copyWith(autoSyncSettings: parsed));

      if (changed || parsed.length != raw.length) {
        unawaited(_persistAutoSyncSettings(parsed));
      }
    } catch (e) {
      print('❌ PlaylistsCubit: 加载自动同步配置失败: $e');
    }
  }

  bool isValidCloudPlaylistId(String id) {
    return _cloudIdPattern.hasMatch(id.trim());
  }

  String get cloudIdRuleDescription => _cloudIdRuleMessage;

  PlaylistAutoSyncConfig? autoSyncSettingOf(String playlistId) {
    return state.autoSyncSettings[playlistId];
  }

  Future<void> saveAutoSyncSetting({
    required String playlistId,
    required PlaylistAutoSyncConfig config,
  }) async {
    final trimmedRemoteId = config.remoteId.trim();
    final updated = Map<String, PlaylistAutoSyncConfig>.from(
      state.autoSyncSettings,
    );

    if (trimmedRemoteId.isEmpty) {
      if (!updated.containsKey(playlistId)) {
        return;
      }
      updated.remove(playlistId);
    } else {
      updated[playlistId] = config.copyWith(remoteId: trimmedRemoteId);
    }

    emit(state.copyWith(autoSyncSettings: updated));
    await _persistAutoSyncSettings(updated);
  }

  Future<void> clearAutoSyncSetting(String playlistId) async {
    if (!state.autoSyncSettings.containsKey(playlistId)) {
      return;
    }
    final updated = Map<String, PlaylistAutoSyncConfig>.from(
      state.autoSyncSettings,
    )..remove(playlistId);
    emit(state.copyWith(autoSyncSettings: updated));
    await _persistAutoSyncSettings(updated);
  }

  Future<String?> syncPlaylistFromCloud(
    String playlistId, {
    bool force = false,
  }) async {
    final config = state.autoSyncSettings[playlistId];
    if (config == null) {
      return '尚未配置自动同步';
    }
    if (!config.enabled && !force) {
      return '未启用自动同步';
    }
    final remoteId = config.remoteId.trim();
    if (remoteId.isEmpty) {
      return '云端ID无效';
    }
    return _pullSingleAutoSyncedPlaylist(
      playlistId: playlistId,
      remoteId: remoteId,
    );
  }

  Future<void> changeSortMode(TrackSortMode sortMode) async {
    try {
      // 保存到BinaryConfigStore
      await _configStore.setValue(
        StorageKeys.playlistSortMode,
        sortMode.toStorageString(),
      );

      // 对所有歌单tracks重新排序
      final Map<String, List<Track>> sortedPlaylistTracks = {};
      for (final entry in state.playlistTracks.entries) {
        sortedPlaylistTracks[entry.key] = _sortTracks(entry.value, sortMode);
      }

      emit(
        state.copyWith(
          sortMode: sortMode,
          playlistTracks: sortedPlaylistTracks,
        ),
      );
    } catch (e) {
      print('❌ PlaylistsCubit: 更改排序模式失败: $e');
    }
  }

  List<Track> _sortTracks(List<Track> tracks, TrackSortMode sortMode) {
    final List<Track> sorted = List.from(tracks);

    switch (sortMode) {
      case TrackSortMode.titleAZ:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case TrackSortMode.titleZA:
        sorted.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
      case TrackSortMode.addedNewest:
        sorted.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case TrackSortMode.addedOldest:
        sorted.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case TrackSortMode.artistAZ:
        sorted.sort((a, b) {
          final artistCompare = a.artist.toLowerCase().compareTo(
            b.artist.toLowerCase(),
          );
          if (artistCompare != 0) {
            return artistCompare;
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case TrackSortMode.artistZA:
        sorted.sort((a, b) {
          final artistCompare = b.artist.toLowerCase().compareTo(
            a.artist.toLowerCase(),
          );
          if (artistCompare != 0) {
            return artistCompare;
          }
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        });
        break;
      case TrackSortMode.albumAZ:
        sorted.sort((a, b) {
          final albumCompare = a.album.toLowerCase().compareTo(
            b.album.toLowerCase(),
          );
          if (albumCompare != 0) {
            return albumCompare;
          }
          final trackCompare = (a.trackNumber ?? 0).compareTo(
            b.trackNumber ?? 0,
          );
          if (trackCompare != 0) {
            return trackCompare;
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case TrackSortMode.albumZA:
        sorted.sort((a, b) {
          final albumCompare = b.album.toLowerCase().compareTo(
            a.album.toLowerCase(),
          );
          if (albumCompare != 0) {
            return albumCompare;
          }
          final trackCompare = (b.trackNumber ?? 0).compareTo(
            a.trackNumber ?? 0,
          );
          if (trackCompare != 0) {
            return trackCompare;
          }
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        });
        break;
    }

    return sorted;
  }

  Future<void> loadPlaylists() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final playlists = await _repository.getAllPlaylists();
      final updatedTracks = Map<String, List<Track>>.from(state.playlistTracks)
        ..removeWhere(
          (key, value) => playlists.every((playlist) => playlist.id != key),
        );
      final autoSyncSettings = _pruneAutoSyncSettings(playlists);
      emit(
        state.copyWith(
          isLoading: false,
          playlists: playlists,
          playlistTracks: updatedTracks,
          autoSyncSettings: autoSyncSettings,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Map<String, PlaylistAutoSyncConfig> _pruneAutoSyncSettings(
    List<Playlist> playlists,
  ) {
    if (state.autoSyncSettings.isEmpty) {
      return state.autoSyncSettings;
    }
    final validIds = playlists.map((playlist) => playlist.id).toSet();
    final current = Map<String, PlaylistAutoSyncConfig>.from(
      state.autoSyncSettings,
    );
    final removable = <String>[];
    for (final entry in current.entries) {
      if (!validIds.contains(entry.key)) {
        removable.add(entry.key);
      }
    }
    if (removable.isEmpty) {
      return state.autoSyncSettings;
    }
    for (final id in removable) {
      current.remove(id);
    }
    unawaited(_persistAutoSyncSettings(current));
    return current;
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
      final sortedTracks = _sortTracks(tracks, state.sortMode);
      final updated = Map<String, List<Track>>.from(state.playlistTracks)
        ..[playlistId] = sortedTracks;
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
      unawaited(_autoUploadIfEnabled(playlistId));
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
      unawaited(_autoUploadIfEnabled(playlistId));
    } catch (e) {
      emit(state.copyWith(isProcessing: false, errorMessage: e.toString()));
    }
  }

  Future<bool> updatePlaylist({
    required String playlistId,
    required String name,
    String? description,
    String? coverPath,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: '歌单名称不能为空'));
      return false;
    }

    emit(state.copyWith(isProcessing: true, clearError: true));
    try {
      Playlist? sourcePlaylist;
      for (final item in state.playlists) {
        if (item.id == playlistId) {
          sourcePlaylist = item;
          break;
        }
      }
      sourcePlaylist ??= await _repository.getPlaylistById(playlistId);
      if (sourcePlaylist == null) {
        emit(state.copyWith(isProcessing: false, errorMessage: '未找到该歌单'));
        return false;
      }

      final updated = sourcePlaylist.copyWith(
        name: trimmedName,
        description: description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        coverPath: coverPath?.trim().isEmpty == true ? null : coverPath?.trim(),
        updatedAt: DateTime.now(),
      );

      await _repository.updatePlaylist(updated);

      final updatedPlaylists = state.playlists
          .map((playlist) => playlist.id == playlistId ? updated : playlist)
          .toList();

      emit(
        state.copyWith(
          isProcessing: false,
          playlists: updatedPlaylists,
          clearError: true,
        ),
      );
      unawaited(_autoUploadIfEnabled(playlistId));
      return true;
    } catch (e) {
      emit(state.copyWith(isProcessing: false, errorMessage: e.toString()));
      return false;
    }
  }

  Future<bool> deletePlaylist(String playlistId) async {
    emit(state.copyWith(isProcessing: true, clearError: true));
    try {
      await _repository.deletePlaylist(playlistId);
      final updatedPlaylists = state.playlists
          .where((playlist) => playlist.id != playlistId)
          .toList();
      final updatedTracks = Map<String, List<Track>>.from(state.playlistTracks)
        ..remove(playlistId);
      emit(
        state.copyWith(
          isProcessing: false,
          playlists: updatedPlaylists,
          playlistTracks: updatedTracks,
          clearError: true,
        ),
      );
      await clearAutoSyncSetting(playlistId);
      return true;
    } catch (e) {
      emit(state.copyWith(isProcessing: false, errorMessage: e.toString()));
      return false;
    }
  }

  Future<String?> uploadPlaylistToCloud({
    required Playlist playlist,
    required String remoteId,
  }) async {
    final trimmed = remoteId.trim();
    if (!isValidCloudPlaylistId(trimmed)) {
      emit(state.copyWith(errorMessage: _cloudIdRuleMessage));
      return _cloudIdRuleMessage;
    }

    emit(state.copyWith(isProcessing: true, clearError: true));
    try {
      await _repository.uploadPlaylistToCloud(
        playlistId: playlist.id,
        remoteId: trimmed,
      );
      emit(state.copyWith(isProcessing: false, clearError: true));
      return null;
    } catch (e) {
      final message = _resolveErrorMessage(e);
      emit(state.copyWith(isProcessing: false, errorMessage: message));
      return message;
    }
  }

  Future<(String? playlistId, String? error)> importPlaylistFromCloud(
    String remoteId,
  ) async {
    final trimmed = remoteId.trim();
    if (!isValidCloudPlaylistId(trimmed)) {
      emit(state.copyWith(errorMessage: _cloudIdRuleMessage));
      return (null, _cloudIdRuleMessage);
    }

    emit(state.copyWith(isProcessing: true, clearError: true));
    try {
      final playlist = await _repository.downloadPlaylistFromCloud(trimmed);
      if (playlist == null) {
        const message = '云端返回的歌单内容无效';
        emit(state.copyWith(isProcessing: false, errorMessage: message));
        return (null, message);
      }

      await loadPlaylists();
      await ensurePlaylistTracks(playlist.id, force: true);
      emit(state.copyWith(isProcessing: false, clearError: true));
      return (playlist.id, null);
    } catch (e) {
      final message = _resolveErrorMessage(e);
      emit(state.copyWith(isProcessing: false, errorMessage: message));
      return (null, message);
    }
  }

  Future<void> _persistAutoSyncSettings(
    Map<String, PlaylistAutoSyncConfig> settings,
  ) async {
    if (settings.isEmpty) {
      await _configStore.remove(StorageKeys.playlistAutoSyncSettings);
      return;
    }
    final encoded = <String, dynamic>{};
    settings.forEach((key, value) {
      encoded[key] = value.toMap();
    });
    await _configStore.setValue(StorageKeys.playlistAutoSyncSettings, encoded);
  }

  Future<void> _pullAutoSyncedPlaylistsFromCloud() async {
    if (state.autoSyncSettings.isEmpty) {
      return;
    }
    for (final entry in state.autoSyncSettings.entries) {
      final config = entry.value;
      if (!config.enabled) {
        continue;
      }
      await _pullSingleAutoSyncedPlaylist(
        playlistId: entry.key,
        remoteId: config.remoteId,
      );
    }
  }

  Future<String?> _pullSingleAutoSyncedPlaylist({
    required String playlistId,
    required String remoteId,
  }) async {
    final trimmed = remoteId.trim();
    if (trimmed.isEmpty) {
      return '云端ID无效';
    }
    try {
      final playlist = await _repository.downloadPlaylistFromCloud(trimmed);
      if (playlist == null) {
        const message = '云端返回的歌单内容无效';
        emit(state.copyWith(errorMessage: message));
        return message;
      }
      if (playlist.id != playlistId) {
        final updated = Map<String, PlaylistAutoSyncConfig>.from(
          state.autoSyncSettings,
        );
        final config = updated.remove(playlistId);
        if (config != null) {
          updated[playlist.id] = config;
          emit(state.copyWith(autoSyncSettings: updated));
          await _persistAutoSyncSettings(updated);
        }
      }
      await refreshPlaylist(playlist.id);
      await ensurePlaylistTracks(playlist.id, force: true);
      return null;
    } catch (e) {
      final message = _resolveErrorMessage(e);
      emit(state.copyWith(errorMessage: message));
      return message;
    }
  }

  Future<void> _autoUploadIfEnabled(String playlistId) async {
    final config = state.autoSyncSettings[playlistId];
    if (config == null || !config.enabled) {
      return;
    }
    final remoteId = config.remoteId.trim();
    if (remoteId.isEmpty) {
      return;
    }
    try {
      await _repository.uploadPlaylistToCloud(
        playlistId: playlistId,
        remoteId: remoteId,
      );
    } catch (e) {
      final message = _resolveErrorMessage(e);
      emit(state.copyWith(errorMessage: message));
    }
  }

  String _resolveErrorMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return error.toString();
  }
}
