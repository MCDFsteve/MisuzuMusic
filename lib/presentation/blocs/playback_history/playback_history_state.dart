import 'package:equatable/equatable.dart';

import '../../../domain/entities/music_entities.dart';

enum PlaybackHistoryStatus { loading, loaded, empty, error }

class PlaybackHistoryState extends Equatable {
  const PlaybackHistoryState({
    required this.status,
    required this.entries,
    this.errorMessage,
  });

  final PlaybackHistoryStatus status;
  final List<PlaybackHistoryEntry> entries;
  final String? errorMessage;

  factory PlaybackHistoryState.loading() => const PlaybackHistoryState(
        status: PlaybackHistoryStatus.loading,
        entries: [],
      );

  factory PlaybackHistoryState.empty() => const PlaybackHistoryState(
        status: PlaybackHistoryStatus.empty,
        entries: [],
      );

  factory PlaybackHistoryState.loaded(List<PlaybackHistoryEntry> entries) =>
      PlaybackHistoryState(
        status: PlaybackHistoryStatus.loaded,
        entries: entries,
      );

  factory PlaybackHistoryState.error(String message) => PlaybackHistoryState(
        status: PlaybackHistoryStatus.error,
        entries: const [],
        errorMessage: message,
      );

  @override
  List<Object?> get props => [status, entries, errorMessage];
}
