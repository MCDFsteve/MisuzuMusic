part of 'lyrics_cubit.dart';

abstract class LyricsState extends Equatable {
  const LyricsState();

  @override
  List<Object?> get props => [];
}

class LyricsInitial extends LyricsState {
  const LyricsInitial();
}

class LyricsLoading extends LyricsState {
  const LyricsLoading();
}

class LyricsLoaded extends LyricsState {
  const LyricsLoaded(this.lyrics);

  final Lyrics lyrics;

  @override
  List<Object?> get props => [lyrics];
}

class LyricsEmpty extends LyricsState {
  const LyricsEmpty();
}

class LyricsError extends LyricsState {
  const LyricsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
