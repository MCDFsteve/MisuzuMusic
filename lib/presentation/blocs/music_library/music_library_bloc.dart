import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/entities/music_entities.dart';
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

class LoadAllArtistsEvent extends MusicLibraryEvent {
  const LoadAllArtistsEvent();
}

class LoadAllAlbumsEvent extends MusicLibraryEvent {
  const LoadAllAlbumsEvent();
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
  final List<Artist> artists;
  final List<Album> albums;
  final String? searchQuery;

  const MusicLibraryLoaded({
    required this.tracks,
    required this.artists,
    required this.albums,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [tracks, artists, albums, searchQuery];

  MusicLibraryLoaded copyWith({
    List<Track>? tracks,
    List<Artist>? artists,
    List<Album>? albums,
    String? searchQuery,
  }) {
    return MusicLibraryLoaded(
      tracks: tracks ?? this.tracks,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class MusicLibraryScanComplete extends MusicLibraryState {
  final int tracksAdded;
  final String directoryPath;

  const MusicLibraryScanComplete({
    required this.tracksAdded,
    required this.directoryPath,
  });

  @override
  List<Object> get props => [tracksAdded, directoryPath];
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

  MusicLibraryBloc({
    required GetAllTracks getAllTracks,
    required SearchTracks searchTracks,
    required ScanMusicDirectory scanMusicDirectory,
    required GetAllArtists getAllArtists,
    required GetAllAlbums getAllAlbums,
  })  : _getAllTracks = getAllTracks,
        _searchTracks = searchTracks,
        _scanMusicDirectory = scanMusicDirectory,
        _getAllArtists = getAllArtists,
        _getAllAlbums = getAllAlbums,
        super(const MusicLibraryInitial()) {

    on<LoadAllTracks>(_onLoadAllTracks);
    on<SearchTracksEvent>(_onSearchTracks);
    on<ScanDirectoryEvent>(_onScanDirectory);
    on<LoadAllArtistsEvent>(_onLoadAllArtists);
    on<LoadAllAlbumsEvent>(_onLoadAllAlbums);
  }

  Future<void> _onLoadAllTracks(
    LoadAllTracks event,
    Emitter<MusicLibraryState> emit,
  ) async {
    try {
      print('🎵 BLoC: 开始加载所有音轨...');
      emit(const MusicLibraryLoading());

      final tracks = await _getAllTracks();
      final artists = await _getAllArtists();
      final albums = await _getAllAlbums();

      print('🎵 BLoC: 加载完成 - ${tracks.length} 首歌曲, ${artists.length} 位艺术家, ${albums.length} 张专辑');

      emit(MusicLibraryLoaded(
        tracks: tracks,
        artists: artists,
        albums: albums,
      ));
    } catch (e) {
      print('❌ BLoC: 加载音轨失败: $e');
      emit(MusicLibraryError('加载音乐库失败: ${e.toString()}'));
    }
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

      print('🔍 BLoC: 搜索完成 - 找到 ${tracks.length} 首歌曲');

      emit(MusicLibraryLoaded(
        tracks: tracks,
        artists: artists,
        albums: albums,
        searchQuery: event.query,
      ));
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
      final tracksAdded = tracksAfterCount - tracksBeforeCount;

      print('📁 BLoC: 扫描完成 - 添加了 $tracksAdded 首新歌曲');

      // 发送扫描完成状态
      emit(MusicLibraryScanComplete(
        tracksAdded: tracksAdded,
        directoryPath: event.directoryPath,
      ));

      // 然后加载所有数据
      await Future.delayed(const Duration(milliseconds: 500));
      add(const LoadAllTracks());

    } catch (e) {
      print('❌ BLoC: 扫描目录失败: $e');
      emit(MusicLibraryError('扫描目录失败: ${e.toString()}'));
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
}