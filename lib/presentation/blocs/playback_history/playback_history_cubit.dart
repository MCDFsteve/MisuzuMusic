import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/music_entities.dart';
import '../../../domain/repositories/playback_history_repository.dart';
import 'playback_history_state.dart';

class PlaybackHistoryCubit extends Cubit<PlaybackHistoryState> {
  PlaybackHistoryCubit(this._repository) : super(PlaybackHistoryState.loading()) {
    _initialize();
  }

  final PlaybackHistoryRepository _repository;
  StreamSubscription<List<PlaybackHistoryEntry>>? _subscription;

  Future<void> _initialize() async {
    try {
      final entries = await _repository.getHistory(limit: 100);
      if (!isClosed) {
        emit(entries.isEmpty
            ? PlaybackHistoryState.empty()
            : PlaybackHistoryState.loaded(entries));
      }

      _subscription = _repository.watchHistory(limit: 100).listen((entries) {
        if (!isClosed) {
          emit(entries.isEmpty
              ? PlaybackHistoryState.empty()
              : PlaybackHistoryState.loaded(entries));
        }
      }, onError: (error) {
        if (!isClosed) {
          emit(PlaybackHistoryState.error(error.toString()));
        }
      });
    } catch (e) {
      emit(PlaybackHistoryState.error(e.toString()));
    }
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
