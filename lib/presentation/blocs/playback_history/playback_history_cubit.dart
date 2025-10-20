import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/music_entities.dart';
import '../../../domain/repositories/playback_history_repository.dart';
import 'playback_history_state.dart';

class PlaybackHistoryCubit extends Cubit<PlaybackHistoryState> {
  PlaybackHistoryCubit(this._repository)
    : super(PlaybackHistoryState.loading()) {
    _initialize();
  }

  final PlaybackHistoryRepository _repository;
  StreamSubscription<List<PlaybackHistoryEntry>>? _subscription;
  StreamSubscription<Track>? _trackUpdateSubscription;

  Future<void> _initialize() async {
    try {
      final entries = await _repository.getHistory(limit: 100);
      if (!isClosed) {
        emit(
          entries.isEmpty
              ? PlaybackHistoryState.empty()
              : PlaybackHistoryState.loaded(entries),
        );
      }

      _subscription = _repository
          .watchHistory(limit: 100)
          .listen(
            (entries) {
              if (!isClosed) {
                emit(
                  entries.isEmpty
                      ? PlaybackHistoryState.empty()
                      : PlaybackHistoryState.loaded(entries),
                );
              }
            },
            onError: (error) {
              if (!isClosed) {
                emit(PlaybackHistoryState.error(error.toString()));
              }
            },
          );

      _trackUpdateSubscription = _repository.watchTrackUpdates().listen(
        _handleTrackUpdate,
      );
    } catch (e) {
      emit(PlaybackHistoryState.error(e.toString()));
    }
  }

  void _handleTrackUpdate(Track track) {
    final currentState = state;
    if (isClosed || currentState.status != PlaybackHistoryStatus.loaded) {
      return;
    }

    final entries = currentState.entries;
    final index = entries.indexWhere((entry) => entry.track.id == track.id);
    if (index == -1) {
      return;
    }

    final existing = entries[index];
    if (existing.track == track) {
      return;
    }

    final updatedEntries = List<PlaybackHistoryEntry>.from(entries);
    updatedEntries[index] = existing.copyWith(track: track);
    emit(PlaybackHistoryState.loaded(updatedEntries));
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _trackUpdateSubscription?.cancel();
    return super.close();
  }
}
