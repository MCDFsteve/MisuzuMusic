import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/lyrics_entities.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/usecases/lyrics_usecases.dart';

part 'lyrics_state.dart';

class LyricsCubit extends Cubit<LyricsState> {
  LyricsCubit({required GetLyrics getLyrics})
      : _getLyrics = getLyrics,
        super(const LyricsInitial());

  final GetLyrics _getLyrics;

  Future<void> loadLyricsForTrack(Track track) async {
    emit(const LyricsLoading());
    try {
      final lyrics = await _getLyrics(track.id);
      if (lyrics == null || lyrics.lines.isEmpty) {
        emit(const LyricsEmpty());
        return;
      }
      emit(LyricsLoaded(lyrics));
    } catch (e) {
      emit(LyricsError(e.toString()));
    }
  }
}
