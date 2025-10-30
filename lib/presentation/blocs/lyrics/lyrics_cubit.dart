import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/lyrics_entities.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/usecases/lyrics_usecases.dart';

part 'lyrics_state.dart';

class LyricsCubit extends Cubit<LyricsState> {
  LyricsCubit({
    required FindLyricsFile findLyricsFile,
    required LoadLyricsFromFile loadLyricsFromFile,
    required FetchOnlineLyrics fetchOnlineLyrics,
    required GetLyrics getLyrics,
  }) : _findLyricsFile = findLyricsFile,
       _loadLyricsFromFile = loadLyricsFromFile,
       _fetchOnlineLyrics = fetchOnlineLyrics,
       _getLyrics = getLyrics,
       super(const LyricsInitial());

  final FindLyricsFile _findLyricsFile;
  final LoadLyricsFromFile _loadLyricsFromFile;
  final FetchOnlineLyrics _fetchOnlineLyrics;
  final GetLyrics _getLyrics;
  String? _activeTrackId;

  Future<void> loadLyricsForTrack(
    Track track, {
    bool forceRemote = false,
  }) async {
    if (isClosed) return;
    final String requestTrackId = track.id;
    _activeTrackId = requestTrackId;
    emit(const LyricsLoading());
    try {
      final bool skipLocalSources = forceRemote;

      final lyricsFromFile = skipLocalSources
          ? null
          : await _loadLyricsFromAssociatedFile(track);
      if (_shouldAbort(requestTrackId)) return;

      // Always attempt to refresh from cloud so server updates are reflected
      final cloudLyrics = await _loadLyricsFromOnline(track, cloudOnly: true);
      if (_shouldAbort(requestTrackId)) return;
      if (cloudLyrics != null && cloudLyrics.lines.isNotEmpty) {
        print('🎼 LyricsCubit: 使用云端歌词');
        emit(LyricsLoaded(_withSource(cloudLyrics, LyricsSource.nipaplay)));
        return;
      }

      if (!skipLocalSources &&
          lyricsFromFile != null &&
          lyricsFromFile.lines.isNotEmpty) {
        print('🎼 LyricsCubit: 使用本地歌词');
        emit(LyricsLoaded(_withSource(lyricsFromFile, LyricsSource.local)));
        return;
      }

      if (!skipLocalSources) {
        final cached = await _getLyrics(track.id);
        if (_shouldAbort(requestTrackId)) return;
        if (cached != null && cached.lines.isNotEmpty) {
          print('🎼 LyricsCubit: 使用缓存歌词');
          emit(LyricsLoaded(_withSource(cached, LyricsSource.cached)));
          return;
        }
      }

      final onlineLyrics = await _loadLyricsFromOnline(track);
      if (_shouldAbort(requestTrackId)) return;
      if (onlineLyrics != null && onlineLyrics.lines.isNotEmpty) {
        print('🎼 LyricsCubit: 使用网络歌曲歌词');
        emit(LyricsLoaded(_withSource(onlineLyrics, LyricsSource.netease)));
        return;
      }

      if (_shouldAbort(requestTrackId)) return;
      emit(const LyricsEmpty());
    } catch (e) {
      if (_shouldAbort(requestTrackId)) return;
      emit(LyricsError(e.toString()));
    }
  }

  Future<Lyrics?> _loadLyricsFromAssociatedFile(Track track) async {
    final lyricsPath = await _safeFindLyricsPath(track);
    if (lyricsPath == null) {
      return null;
    }

    print('🎼 LyricsCubit: 准备从歌词文件加载 -> $lyricsPath');
    final lyrics = await _loadLyricsFromFile(lyricsPath, track.id);
    if (lyrics == null || lyrics.lines.isEmpty) {
      print('🎼 LyricsCubit: 文件存在但解析结果为空');
      return null;
    }
    print('🎼 LyricsCubit: 成功解析到 ${lyrics.lines.length} 行歌词');
    return lyrics;
  }

  Future<String?> _safeFindLyricsPath(Track track) async {
    final filePath = track.filePath;
    if (filePath.isEmpty) {
      print('🎼 LyricsCubit: 音频轨道缺少文件路径，无法搜索歌词');
      return null;
    }

    print('🎼 LyricsCubit: 开始查找歌词，音频文件 -> $filePath');
    try {
      final audioFile = File(filePath);
      if (!audioFile.existsSync()) {
        print('🎼 LyricsCubit: 音频文件不存在，无法定位歌词');
        return null;
      }

      final directory = audioFile.parent;
      final availableLrc = <String>[];
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.lrc')) {
          availableLrc.add(entity.path);
        }
      }
      if (availableLrc.isEmpty) {
        print('🎼 LyricsCubit: 同目录未找到任何 .lrc 文件');
      } else {
        print('🎼 LyricsCubit: 目录下的 .lrc 文件列表:');
        for (final path in availableLrc) {
          print('  • $path');
        }
      }

      final lyricsPath = await _findLyricsFile(filePath);
      if (lyricsPath == null) {
        print('🎼 LyricsCubit: 未匹配到同名歌词文件');
        return null;
      }

      print('🎼 LyricsCubit: 找到同名歌词文件 -> $lyricsPath');
      return lyricsPath;
    } catch (_) {
      print('🎼 LyricsCubit: 查找歌词过程中发生异常，已忽略');
      return null;
    }
  }

  Future<Lyrics?> _loadLyricsFromOnline(
    Track track, {
    bool cloudOnly = false,
  }) async {
    final title = track.title.trim();
    if (title.isEmpty) {
      return null;
    }

    try {
      final lyrics = await _fetchOnlineLyrics(
        track: track,
        cloudOnly: cloudOnly,
      );
      if (lyrics != null) {
        print('🎼 LyricsCubit: 在线歌词获取成功');
      } else {
        print('🎼 LyricsCubit: 在线歌词未匹配到结果');
      }
      return lyrics;
    } catch (e) {
      print('🎼 LyricsCubit: 在线歌词获取失败 -> $e');
      return null;
    }
  }

  bool _needsTranslationUpgrade(Lyrics lyrics, Track track) {
    // 用户更倾向使用本地/云端提供的歌词，不再额外尝试网络歌曲翻译
    return false;
  }

  Lyrics _withSource(Lyrics lyrics, LyricsSource source) {
    return Lyrics(
      trackId: lyrics.trackId,
      lines: lyrics.lines,
      format: lyrics.format,
      source: source,
    );
  }

  bool _shouldAbort(String requestTrackId) {
    return isClosed || _activeTrackId != requestTrackId;
  }
}
