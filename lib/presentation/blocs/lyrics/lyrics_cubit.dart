import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/lyrics_entities.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/usecases/lyrics_usecases.dart';

part 'lyrics_state.dart';

class LyricsCubit extends Cubit<LyricsState> {
  LyricsCubit({
    required GetLyrics getLyrics,
    required FindLyricsFile findLyricsFile,
    required LoadLyricsFromFile loadLyricsFromFile,
    required SaveLyrics saveLyrics,
  })  : _getLyrics = getLyrics,
        _findLyricsFile = findLyricsFile,
        _loadLyricsFromFile = loadLyricsFromFile,
        _saveLyrics = saveLyrics,
        super(const LyricsInitial());

  final GetLyrics _getLyrics;
  final FindLyricsFile _findLyricsFile;
  final LoadLyricsFromFile _loadLyricsFromFile;
  final SaveLyrics _saveLyrics;

  Future<void> loadLyricsForTrack(Track track) async {
    emit(const LyricsLoading());
    try {
      Lyrics? lyrics = await _getLyrics(track.id);

      if (lyrics == null || lyrics.lines.isEmpty) {
        final lyricsPath = await _safeFindLyricsPath(track);
        if (lyricsPath != null) {
          lyrics = await _loadLyricsFromFile(lyricsPath, track.id);
          if (lyrics != null && lyrics.lines.isNotEmpty) {
            await _saveLyrics(lyrics);
          }
        }
      }

      if (lyrics == null || lyrics.lines.isEmpty) {
        emit(const LyricsEmpty());
        return;
      }

      emit(LyricsLoaded(lyrics));
    } catch (e) {
      emit(LyricsError(e.toString()));
    }
  }

  Future<String?> _safeFindLyricsPath(Track track) async {
    final filePath = track.filePath;
    if (filePath.isEmpty) {
      return null;
    }
    try {
      return await _findLyricsFile(filePath);
    } catch (_) {
      return null;
    }
  }
}
