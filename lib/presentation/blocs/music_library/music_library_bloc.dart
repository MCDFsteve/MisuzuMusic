import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/binary_config_store.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/entities/webdav_entities.dart';
import '../../../domain/entities/jellyfin_entities.dart';
import '../../../domain/usecases/music_usecases.dart';

// Events
abstract class MusicLibraryEvent extends Equatable {
  const MusicLibraryEvent();

  @override
  List<Object?> get props => [];
}

class LoadAllTracks extends MusicLibraryEvent {
  const LoadAllTracks();
}

class SearchTracksEvent extends MusicLibraryEvent {
  final String query;

  const SearchTracksEvent(this.query);

  @override
  List<Object> get props => [query];
}

class ScanDirectoryEvent extends MusicLibraryEvent {
  final String directoryPath;

  const ScanDirectoryEvent(this.directoryPath);

  @override
  List<Object> get props => [directoryPath];
}

class ScanWebDavDirectoryEvent extends MusicLibraryEvent {
  final WebDavSource source;
  final String password;

  const ScanWebDavDirectoryEvent({
    required this.source,
    required this.password,
  });

  @override
  List<Object> get props => [source, password];
}

class ScanJellyfinLibraryEvent extends MusicLibraryEvent {
  final JellyfinSource source;
  final String accessToken;

  const ScanJellyfinLibraryEvent({
    required this.source,
    required this.accessToken,
  });

  @override
  List<Object> get props => [source, accessToken];
}

class MountMysteryLibraryEvent extends MusicLibraryEvent {
  final Uri baseUri;
  final String code;

  const MountMysteryLibraryEvent({required this.baseUri, required this.code});

  @override
  List<Object> get props => [baseUri, code];
}

class UnmountMysteryLibraryEvent extends MusicLibraryEvent {
  final String sourceId;

  const UnmountMysteryLibraryEvent(this.sourceId);

  @override
  List<Object> get props => [sourceId];
}

class RemoveLibraryDirectoryEvent extends MusicLibraryEvent {
  final String directoryPath;

  const RemoveLibraryDirectoryEvent(this.directoryPath);

  @override
  List<Object> get props => [directoryPath];
}

class RemoveWebDavSourceEvent extends MusicLibraryEvent {
  final WebDavSource source;

  const RemoveWebDavSourceEvent(this.source);

  @override
  List<Object?> get props => [source];
}

class RemoveJellyfinSourceEvent extends MusicLibraryEvent {
  final JellyfinSource source;

  const RemoveJellyfinSourceEvent(this.source);

  @override
  List<Object?> get props => [source];
}

class ClearLibraryEvent extends MusicLibraryEvent {
  const ClearLibraryEvent();
}

class LoadAllArtistsEvent extends MusicLibraryEvent {
  const LoadAllArtistsEvent();
}

class LoadAllAlbumsEvent extends MusicLibraryEvent {
  const LoadAllAlbumsEvent();
}

class ChangeSortModeEvent extends MusicLibraryEvent {
  final TrackSortMode sortMode;

  const ChangeSortModeEvent(this.sortMode);

  @override
  List<Object> get props => [sortMode];
}

// States
abstract class MusicLibraryState extends Equatable {
  const MusicLibraryState();

  @override
  List<Object?> get props => [];
}

class MusicLibraryInitial extends MusicLibraryState {
  const MusicLibraryInitial();
}

class MusicLibraryLoading extends MusicLibraryState {
  const MusicLibraryLoading();
}

class MusicLibraryScanning extends MusicLibraryState {
  final String directoryPath;

  const MusicLibraryScanning(this.directoryPath);

  @override
  List<Object> get props => [directoryPath];
}

class MusicLibraryLoaded extends MusicLibraryState {
  final List<Track> tracks;
  final List<Track> allTracks;
  final List<Artist> artists;
  final List<Album> albums;
  final String? searchQuery;
  final List<String> libraryDirectories;
  final List<WebDavSource> webDavSources;
  final List<JellyfinSource> jellyfinSources;
  final TrackSortMode sortMode;

  const MusicLibraryLoaded({
    required this.tracks,
    required this.allTracks,
    required this.artists,
    required this.albums,
    required this.libraryDirectories,
    required this.webDavSources,
    required this.jellyfinSources,
    this.searchQuery,
    this.sortMode = TrackSortMode.titleAZ,
  });

  @override
  List<Object?> get props => [
    tracks,
    allTracks,
    artists,
    albums,
    libraryDirectories,
    webDavSources,
    jellyfinSources,
    searchQuery,
    sortMode,
  ];

  MusicLibraryLoaded copyWith({
    List<Track>? tracks,
    List<Track>? allTracks,
    List<Artist>? artists,
    List<Album>? albums,
    List<String>? libraryDirectories,
    List<WebDavSource>? webDavSources,
    List<JellyfinSource>? jellyfinSources,
    String? searchQuery,
    TrackSortMode? sortMode,
  }) {
    return MusicLibraryLoaded(
      tracks: tracks ?? this.tracks,
      allTracks: allTracks ?? this.allTracks,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      libraryDirectories: libraryDirectories ?? this.libraryDirectories,
      webDavSources: webDavSources ?? this.webDavSources,
      jellyfinSources: jellyfinSources ?? this.jellyfinSources,
      searchQuery: searchQuery ?? this.searchQuery,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

class MusicLibraryScanComplete extends MusicLibraryState {
  final int tracksAdded;
  final String directoryPath;
  final WebDavSource? webDavSource;
  final JellyfinSource? jellyfinSource;

  const MusicLibraryScanComplete({
    required this.tracksAdded,
    required this.directoryPath,
    this.webDavSource,
    this.jellyfinSource,
  });

  @override
  List<Object?> get props => [
    tracksAdded,
    directoryPath,
    webDavSource,
    jellyfinSource,
  ];
}

class MusicLibraryError extends MusicLibraryState {
  final String message;

  const MusicLibraryError(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class MusicLibraryBloc extends Bloc<MusicLibraryEvent, MusicLibraryState> {
  final GetAllTracks _getAllTracks;
  final SearchTracks _searchTracks;
  final ScanMusicDirectory _scanMusicDirectory;
  final GetAllArtists _getAllArtists;
  final GetAllAlbums _getAllAlbums;
  final GetLibraryDirectories _getLibraryDirectories;
  final ScanWebDavDirectory _scanWebDavDirectory;
  final ScanJellyfinLibrary _scanJellyfinLibrary;
  final MountMysteryLibrary _mountMysteryLibrary;
  final UnmountMysteryLibrary _unmountMysteryLibrary;
  final GetWebDavSources _getWebDavSources;
  final GetJellyfinSources _getJellyfinSources;
  final EnsureWebDavTrackMetadata _ensureWebDavTrackMetadata;
  final GetWebDavPassword _getWebDavPassword;
  final GetJellyfinAccessToken _getJellyfinAccessToken;
  final RemoveLibraryDirectory _removeLibraryDirectory;
  final DeleteWebDavSource _deleteWebDavSource;
  final DeleteJellyfinSource _deleteJellyfinSource;
  final ClearLibrary _clearLibrary;
  final WatchTrackUpdates _watchTrackUpdates;
  final BinaryConfigStore _configStore;

  List<Track> _allTracksCache = const [];

  StreamSubscription<Track>? _trackUpdateSubscription;

  bool _webDavMetadataEnrichmentInProgress = false;
  bool _webDavAutoSyncTriggered = false;
  bool _jellyfinAutoSyncTriggered = false;

  MusicLibraryBloc({
    required GetAllTracks getAllTracks,
    required SearchTracks searchTracks,
    required ScanMusicDirectory scanMusicDirectory,
    required GetAllArtists getAllArtists,
    required GetAllAlbums getAllAlbums,
    required GetLibraryDirectories getLibraryDirectories,
    required ScanWebDavDirectory scanWebDavDirectory,
    required ScanJellyfinLibrary scanJellyfinLibrary,
    required MountMysteryLibrary mountMysteryLibrary,
    required UnmountMysteryLibrary unmountMysteryLibrary,
    required GetWebDavSources getWebDavSources,
    required GetJellyfinSources getJellyfinSources,
    required EnsureWebDavTrackMetadata ensureWebDavTrackMetadata,
    required GetWebDavPassword getWebDavPassword,
    required GetJellyfinAccessToken getJellyfinAccessToken,
    required RemoveLibraryDirectory removeLibraryDirectory,
    required ClearLibrary clearLibrary,
    required DeleteWebDavSource deleteWebDavSource,
    required DeleteJellyfinSource deleteJellyfinSource,
    required WatchTrackUpdates watchTrackUpdates,
    required BinaryConfigStore configStore,
  }) : _getAllTracks = getAllTracks,
       _searchTracks = searchTracks,
       _scanMusicDirectory = scanMusicDirectory,
       _getAllArtists = getAllArtists,
       _getAllAlbums = getAllAlbums,
       _getLibraryDirectories = getLibraryDirectories,
       _scanWebDavDirectory = scanWebDavDirectory,
       _scanJellyfinLibrary = scanJellyfinLibrary,
       _mountMysteryLibrary = mountMysteryLibrary,
       _unmountMysteryLibrary = unmountMysteryLibrary,
       _getWebDavSources = getWebDavSources,
       _getJellyfinSources = getJellyfinSources,
       _ensureWebDavTrackMetadata = ensureWebDavTrackMetadata,
       _getWebDavPassword = getWebDavPassword,
       _getJellyfinAccessToken = getJellyfinAccessToken,
       _removeLibraryDirectory = removeLibraryDirectory,
       _clearLibrary = clearLibrary,
       _deleteWebDavSource = deleteWebDavSource,
       _deleteJellyfinSource = deleteJellyfinSource,
       _watchTrackUpdates = watchTrackUpdates,
       _configStore = configStore,
       super(const MusicLibraryInitial()) {
    on<LoadAllTracks>(_onLoadAllTracks);
    on<SearchTracksEvent>(_onSearchTracks);
    on<ScanDirectoryEvent>(_onScanDirectory);
    on<ScanWebDavDirectoryEvent>(_onScanWebDavDirectory);
    on<ScanJellyfinLibraryEvent>(_onScanJellyfinLibrary);
    on<MountMysteryLibraryEvent>(_onMountMysteryLibrary);
    on<UnmountMysteryLibraryEvent>(_onUnmountMysteryLibrary);
    on<RemoveLibraryDirectoryEvent>(_onRemoveLibraryDirectory);
    on<RemoveWebDavSourceEvent>(_onRemoveWebDavSource);
    on<RemoveJellyfinSourceEvent>(_onRemoveJellyfinSource);
    on<ClearLibraryEvent>(_onClearLibrary);
    on<LoadAllArtistsEvent>(_onLoadAllArtists);
    on<LoadAllAlbumsEvent>(_onLoadAllAlbums);
    on<ChangeSortModeEvent>(_onChangeSortMode);

    _trackUpdateSubscription = _watchTrackUpdates().listen(_onTrackUpdated);
  }

  void _onTrackUpdated(Track track) {
    final currentState = state;
    if (currentState is! MusicLibraryLoaded) {
      return;
    }

    final visibleIndex = currentState.tracks.indexWhere(
      (item) => item.id == track.id,
    );
    final allIndex = currentState.allTracks.indexWhere(
      (item) => item.id == track.id,
    );

    if (visibleIndex == -1 && allIndex == -1) {
      return;
    }

    final hasVisibleChange =
        visibleIndex != -1 && currentState.tracks[visibleIndex] != track;
    final hasAllChange =
        allIndex != -1 && currentState.allTracks[allIndex] != track;

    if (!hasVisibleChange && !hasAllChange) {
      return;
    }

    final updatedTracks = hasVisibleChange
        ? List<Track>.from(currentState.tracks)
        : currentState.tracks;
    final updatedAllTracks = hasAllChange
        ? List<Track>.from(currentState.allTracks)
        : currentState.allTracks;

    if (hasVisibleChange && visibleIndex != -1) {
      updatedTracks[visibleIndex] = track;
    }
    if (hasAllChange && allIndex != -1) {
      updatedAllTracks[allIndex] = track;
    }

    _allTracksCache = updatedAllTracks;

    emit(
      currentState.copyWith(tracks: updatedTracks, allTracks: updatedAllTracks),
    );
  }

  Future<void> _onLoadAllTracks(
    LoadAllTracks event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      print('🎵 BLoC: 开始加载所有音轨...');
      emit(const MusicLibraryLoading());

      final webDavSources = await _getWebDavSources();
      final jellyfinSources = await _getJellyfinSources();
      final tracks = await _getAllTracks();
      final artists = await _getAllArtists();
      final albums = await _getAllAlbums();
      final directories = await _getLibraryDirectories();

      // 加载保存的排序模式
      await _configStore.init();
      final sortModeString = _configStore.getValue<String>(
        StorageKeys.musicLibrarySortMode,
      );
      final sortMode = TrackSortModeExtension.fromStorageString(sortModeString);

      final visibleTracks = _filterVisibleTracks(tracks);
      final sortedTracks = _sortTracks(visibleTracks, sortMode);
      final hiddenCount = tracks.length - visibleTracks.length;
      if (hiddenCount > 0) {
        // print('🌐 BLoC: 暂时隐藏 $hiddenCount 首 WebDAV 音轨，等待元数据加载');
      }

      print(
        '🎵 BLoC: 加载完成 - ${sortedTracks.length} 首可用歌曲, 隐藏 $hiddenCount 首, ${artists.length} 位艺术家, ${albums.length} 张专辑',
      );

      _allTracksCache = sortedTracks;

      emit(
        MusicLibraryLoaded(
          tracks: sortedTracks,
          allTracks: _allTracksCache,
          artists: artists,
          albums: albums,
          libraryDirectories: directories,
          webDavSources: webDavSources,
          jellyfinSources: jellyfinSources,
          sortMode: sortMode,
        ),
      );

      if (!_webDavAutoSyncTriggered) {
        _webDavAutoSyncTriggered = true;
        unawaited(_autoSyncWebDavSources(webDavSources));
      }
      if (!_jellyfinAutoSyncTriggered) {
        _jellyfinAutoSyncTriggered = true;
        unawaited(_autoSyncJellyfinSources(jellyfinSources));
      }

      await _autoEnrichWebDavMetadata(tracks, emit);
    } catch (e) {
      print('❌ BLoC: 加载音轨失败: $e');
      emit(MusicLibraryError('加载音乐库失败: ${e.toString()}'));
    }
  }

  Future<void> _autoSyncWebDavSources(List<WebDavSource> sources) async {
    if (sources.isEmpty) {
      return;
    }

    for (final source in sources) {
      final password = await _getWebDavPassword(source.id);
      if (password == null || password.isEmpty) {
        continue;
      }
      try {
        await _scanWebDavDirectory(source: source, password: password);
      } catch (e) {
        print('⚠️ BLoC: 自动同步 WebDAV 源失败 -> $e');
      }
    }

    add(const LoadAllTracks());
  }

  Future<void> _autoSyncJellyfinSources(List<JellyfinSource> sources) async {
    if (sources.isEmpty) {
      return;
    }

    for (final source in sources) {
      final token = await _getJellyfinAccessToken(source.id);
      if (token == null || token.isEmpty) {
        continue;
      }
      try {
        await _scanJellyfinLibrary(source: source, accessToken: token);
      } catch (e) {
        print('⚠️ BLoC: 自动同步 Jellyfin 源失败 -> $e');
      }
    }

    add(const LoadAllTracks());
  }

  Future<void> _autoEnrichWebDavMetadata(
    List<Track> tracks,
    Emitter<MusicLibraryState> emit,
  ) async {
    if (_webDavMetadataEnrichmentInProgress) {
      return;
    }

    final candidates = tracks.where(_needsWebDavMetadata).toList();
    if (candidates.isEmpty) {
      return;
    }

    _webDavMetadataEnrichmentInProgress = true;
    try {
      // print('🌐 BLoC: 自动补全 WebDAV 元数据任务启动 - ${candidates.length} 首音轨');

      var updated = false;
      for (final track in candidates) {
        final enriched = await _ensureWebDavTrackMetadata(track, force: false);
        final effective = enriched ?? track;
        if (_hasMetadataChanged(track, effective)) {
          updated = true;
        }
      }

      if (updated) {
        // print('🌐 BLoC: WebDAV 元数据发生更新，刷新音乐库');
        final refreshedTracks = await _getAllTracks();
        final refreshedArtists = await _getAllArtists();
        final refreshedAlbums = await _getAllAlbums();
        final directories = await _getLibraryDirectories();
        final webDavSources = await _getWebDavSources();
        final jellyfinSources = await _getJellyfinSources();

        final currentState = state;
        final currentSortMode = currentState is MusicLibraryLoaded
            ? currentState.sortMode
            : TrackSortMode.titleAZ;

        final visibleTracks = _filterVisibleTracks(refreshedTracks);
        final sortedVisibleTracks = _sortTracks(visibleTracks, currentSortMode);
        final hiddenCount = refreshedTracks.length - visibleTracks.length;
        if (hiddenCount > 0) {
          // print('🌐 BLoC: 补齐后仍有 $hiddenCount 首 WebDAV 音轨缺少元数据，继续等待');
        }

        _allTracksCache = sortedVisibleTracks;

        emit(
          MusicLibraryLoaded(
            tracks: sortedVisibleTracks,
            allTracks: _allTracksCache,
            artists: refreshedArtists,
            albums: refreshedAlbums,
            libraryDirectories: directories,
            webDavSources: webDavSources,
            jellyfinSources: jellyfinSources,
            sortMode: currentSortMode,
          ),
        );
      } else {
        // print('🌐 BLoC: WebDAV 元数据无需更新');
      }
    } catch (e) {
      print('⚠️ BLoC: 自动补全 WebDAV 元数据失败 - $e');
    } finally {
      _webDavMetadataEnrichmentInProgress = false;
    }
  }

  Future<void> _onRemoveLibraryDirectory(
    RemoveLibraryDirectoryEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      await _removeLibraryDirectory(event.directoryPath);
      add(const LoadAllTracks());
    } catch (e) {
      print('⚠️ BLoC: 移除音乐库目录失败 -> $e');
    }
  }

  Future<void> _onRemoveWebDavSource(
    RemoveWebDavSourceEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      await _deleteWebDavSource(event.source.id);
      add(const LoadAllTracks());
    } catch (e) {
      print('⚠️ BLoC: 移除 WebDAV 源失败 -> $e');
    }
  }

  Future<void> _onRemoveJellyfinSource(
    RemoveJellyfinSourceEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      await _deleteJellyfinSource(event.source.id);
      add(const LoadAllTracks());
    } catch (e) {
      print('⚠️ BLoC: 移除 Jellyfin 源失败 -> $e');
    }
  }

  Future<void> _onClearLibrary(
    ClearLibraryEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      emit(const MusicLibraryLoading());
      await _clearLibrary();
      _allTracksCache = const [];
      add(const LoadAllTracks());
    } catch (e) {
      print('⚠️ BLoC: 清空音乐库失败 -> $e');
      emit(MusicLibraryError('删除扫描结果失败: ${e.toString()}'));
    }
  }

  bool _needsWebDavMetadata(Track track) {
    final isWebDav =
        track.sourceType == TrackSourceType.webdav ||
        track.filePath.startsWith('webdav://');
    if (!isWebDav) {
      return false;
    }

    final hasDuration = track.duration > Duration.zero;
    final hasArtist =
        track.artist.isNotEmpty &&
        track.artist.toLowerCase() != 'unknown artist';
    final hasAlbum =
        track.album.isNotEmpty && track.album.toLowerCase() != 'unknown album';
    final hasArtwork =
        track.artworkPath != null && track.artworkPath!.isNotEmpty;

    return !(hasDuration && hasArtist && hasAlbum && hasArtwork);
  }

  List<Track> _filterVisibleTracks(List<Track> tracks) {
    // return tracks.where((track) => !_needsWebDavMetadata(track)).toList();
    return tracks;
  }

  bool _hasMetadataChanged(Track original, Track updated) {
    if (original.title != updated.title) return true;
    if (original.artist != updated.artist) return true;
    if (original.album != updated.album) return true;
    if (original.duration != updated.duration) return true;
    if ((original.artworkPath ?? '') != (updated.artworkPath ?? '')) {
      return true;
    }
    if ((original.genre ?? '') != (updated.genre ?? '')) return true;
    if (original.trackNumber != updated.trackNumber) return true;
    if (original.year != updated.year) return true;
    return false;
  }

  Future<void> _onSearchTracks(
    SearchTracksEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      print('🔍 BLoC: 搜索音轨: ${event.query}');
      emit(const MusicLibraryLoading());

      final tracks = await _searchTracks(event.query);
      final artists = await _getAllArtists();
      final albums = await _getAllAlbums();
      final directories = await _getLibraryDirectories();
      final webDavSources = await _getWebDavSources();
      final jellyfinSources = await _getJellyfinSources();

      final visibleTracks = _filterVisibleTracks(tracks);
      final hiddenCount = tracks.length - visibleTracks.length;
      if (hiddenCount > 0) {
        print('🌐 BLoC: 搜索结果隐藏 $hiddenCount 首 WebDAV 音轨，等待元数据加载');
      }

      print('🔍 BLoC: 搜索完成 - 找到 ${tracks.length} 首歌曲');

      final currentState = state;
      final currentSortMode = currentState is MusicLibraryLoaded
          ? currentState.sortMode
          : TrackSortMode.titleAZ;
      final effectiveAllTracks = currentState is MusicLibraryLoaded
          ? currentState.allTracks
          : _allTracksCache;

      emit(
        MusicLibraryLoaded(
          tracks: visibleTracks,
          allTracks: effectiveAllTracks,
          artists: artists,
          albums: albums,
          libraryDirectories: directories,
          webDavSources: webDavSources,
          jellyfinSources: jellyfinSources,
          searchQuery: event.query,
          sortMode: currentSortMode,
        ),
      );
    } catch (e) {
      print('❌ BLoC: 搜索失败: $e');
      emit(MusicLibraryError('搜索失败: ${e.toString()}'));
    }
  }

  Future<void> _onScanDirectory(
    ScanDirectoryEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      print('📁 BLoC: 开始扫描目录: ${event.directoryPath}');
      emit(MusicLibraryScanning(event.directoryPath));

      // 获取扫描前的音轨数量
      final tracksBefore = await _getAllTracks();
      final tracksBeforeCount = tracksBefore.length;

      // 执行扫描
      await _scanMusicDirectory(event.directoryPath);

      // 获取扫描后的音轨数量
      final tracksAfter = await _getAllTracks();
      final tracksAfterCount = tracksAfter.length;
      final netChange = tracksAfterCount - tracksBeforeCount;
      final removedCount = netChange < 0 ? -netChange : 0;
      final tracksAdded = netChange > 0 ? netChange : 0;

      if (removedCount > 0) {
        print('📁 BLoC: 扫描完成 - 已移除 $removedCount 首缺失歌曲');
      }
      print('📁 BLoC: 扫描完成 - 添加了 $tracksAdded 首新歌曲');

      // 发送扫描完成状态
      emit(
        MusicLibraryScanComplete(
          tracksAdded: tracksAdded,
          directoryPath: event.directoryPath,
        ),
      );

      // 然后加载所有数据
      await Future.delayed(const Duration(milliseconds: 500));
      add(const LoadAllTracks());
    } catch (e) {
      print('❌ BLoC: 扫描目录失败: $e');
      emit(MusicLibraryError('扫描目录失败: ${e.toString()}'));
    }
  }

  Future<void> _onScanWebDavDirectory(
    ScanWebDavDirectoryEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      print('🌐 BLoC: 开始扫描 WebDAV 目录: ${event.source.rootPath}');
      emit(MusicLibraryScanning(event.source.rootPath));

      final tracksBefore = await _getAllTracks();
      final beforeCount = tracksBefore.length;

      await _scanWebDavDirectory(
        source: event.source,
        password: event.password,
      );

      final tracksAfter = await _getAllTracks();
      final afterCount = tracksAfter.length;
      final netChange = afterCount - beforeCount;
      final removedCount = netChange < 0 ? -netChange : 0;
      final tracksAdded = netChange > 0 ? netChange : 0;

      if (removedCount > 0) {
        print('🌐 BLoC: WebDAV 扫描完成 - 已移除 $removedCount 首缺失歌曲');
      }
      print('🌐 BLoC: WebDAV 扫描完成 - 添加了 $tracksAdded 首新歌曲');

      WebDavSource? updatedSource;
      final sources = await _getWebDavSources();
      try {
        updatedSource = sources.firstWhere(
          (item) =>
              item.baseUrl == event.source.baseUrl &&
              item.rootPath == event.source.rootPath &&
              (item.username ?? '') == (event.source.username ?? ''),
        );
      } catch (_) {
        updatedSource = null;
      }

      emit(
        MusicLibraryScanComplete(
          tracksAdded: tracksAdded,
          directoryPath: event.source.rootPath,
          webDavSource: updatedSource ?? event.source,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      add(const LoadAllTracks());
    } catch (e) {
      print('❌ BLoC: 扫描 WebDAV 目录失败: $e');
      emit(MusicLibraryError('扫描 WebDAV 目录失败: ${e.toString()}'));
    }
  }

  Future<void> _onScanJellyfinLibrary(
    ScanJellyfinLibraryEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      final label = event.source.libraryName ?? event.source.name;
      print('🎵 BLoC: 开始扫描 Jellyfin 媒体库: $label');
      emit(MusicLibraryScanning(label));

      final tracksBefore = await _getAllTracks();
      final beforeCount = tracksBefore.length;

      await _scanJellyfinLibrary(
        source: event.source,
        accessToken: event.accessToken,
      );

      final tracksAfter = await _getAllTracks();
      final afterCount = tracksAfter.length;
      final netChange = afterCount - beforeCount;
      final removedCount = netChange < 0 ? -netChange : 0;
      final tracksAdded = netChange > 0 ? netChange : 0;

      if (removedCount > 0) {
        print('🎵 BLoC: Jellyfin 扫描完成 - 已移除 $removedCount 首缺失歌曲');
      }
      print('🎵 BLoC: Jellyfin 扫描完成 - 添加了 $tracksAdded 首新歌曲');

      JellyfinSource? updatedSource;
      final sources = await _getJellyfinSources();
      try {
        updatedSource = sources.firstWhere((item) => item.id == event.source.id);
      } catch (_) {
        updatedSource = null;
      }

      emit(
        MusicLibraryScanComplete(
          tracksAdded: tracksAdded,
          directoryPath: label,
          jellyfinSource: updatedSource ?? event.source,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      add(const LoadAllTracks());
    } catch (e) {
      print('❌ BLoC: 扫描 Jellyfin 媒体库失败: $e');
      emit(MusicLibraryError('扫描 Jellyfin 媒体库失败: ${e.toString()}'));
    }
  }

  Future<void> _onMountMysteryLibrary(
    MountMysteryLibraryEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      final scanLabel = 'mystery://${event.code}';
      print('🕵️ BLoC: 开始挂载神秘代码 -> ${event.code}');
      emit(MusicLibraryScanning(scanLabel));

      final imported = await _mountMysteryLibrary(
        baseUri: event.baseUri,
        code: event.code,
      );

      print('🕵️ BLoC: 神秘代码挂载完成 - 导入 $imported 首歌曲');

      emit(
        MusicLibraryScanComplete(
          tracksAdded: imported,
          directoryPath: '神秘代码: ${event.code}',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      add(const LoadAllTracks());
    } catch (e) {
      print('❌ BLoC: 挂载神秘代码失败 -> $e');
      emit(MusicLibraryError('挂载神秘代码失败: ${e.toString()}'));
    }
  }

  Future<void> _onUnmountMysteryLibrary(
    UnmountMysteryLibraryEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      print('🕵️ BLoC: 卸载神秘代码 -> ${event.sourceId}');
      await _unmountMysteryLibrary(event.sourceId);
      add(const LoadAllTracks());
    } catch (e) {
      print('❌ BLoC: 卸载神秘代码失败 -> $e');
      emit(MusicLibraryError('卸载神秘代码失败: ${e.toString()}'));
    }
  }

  Future<void> _onLoadAllArtists(
    LoadAllArtistsEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      print('🎤 BLoC: 加载所有艺术家...');
      final artists = await _getAllArtists();
      print('🎤 BLoC: 加载完成 - ${artists.length} 位艺术家');

      if (state is MusicLibraryLoaded) {
        final currentState = state as MusicLibraryLoaded;
        emit(currentState.copyWith(artists: artists));
      }
    } catch (e) {
      print('❌ BLoC: 加载艺术家失败: $e');
      emit(MusicLibraryError('加载艺术家失败: ${e.toString()}'));
    }
  }

  Future<void> _onLoadAllAlbums(
    LoadAllAlbumsEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      print('💿 BLoC: 加载所有专辑...');
      final albums = await _getAllAlbums();
      print('💿 BLoC: 加载完成 - ${albums.length} 张专辑');

      if (state is MusicLibraryLoaded) {
        final currentState = state as MusicLibraryLoaded;
        emit(currentState.copyWith(albums: albums));
      }
    } catch (e) {
      print('❌ BLoC: 加载专辑失败: $e');
      emit(MusicLibraryError('加载专辑失败: ${e.toString()}'));
    }
  }

  Future<void> _onChangeSortMode(
    ChangeSortModeEvent event,
    Emitter<MusicLibraryState> emit,
  ) async {
    final currentState = state;
    if (currentState is! MusicLibraryLoaded) {
      return;
    }

    // 保存排序模式到BinaryConfigStore
    await _configStore.setValue(
      StorageKeys.musicLibrarySortMode,
      event.sortMode.toStorageString(),
    );

    // 对当前显示列表和完整列表重新排序
    final sortedVisibleTracks = _sortTracks(
      currentState.tracks,
      event.sortMode,
    );
    final sortedAllTracks = _sortTracks(currentState.allTracks, event.sortMode);
    _allTracksCache = sortedAllTracks;

    emit(
      currentState.copyWith(
        tracks: sortedVisibleTracks,
        allTracks: sortedAllTracks,
        sortMode: event.sortMode,
      ),
    );
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

  @override
  Future<void> close() {
    _trackUpdateSubscription?.cancel();
    return super.close();
  }
}
