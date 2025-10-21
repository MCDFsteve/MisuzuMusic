import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/di/dependency_injection.dart';
import '../../domain/entities/music_entities.dart';
import '../../domain/entities/webdav_entities.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../../domain/repositories/playback_history_repository.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/usecases/music_usecases.dart';
import '../../domain/usecases/player_usecases.dart';
import '../blocs/music_library/music_library_bloc.dart';
import '../blocs/playback_history/playback_history_cubit.dart';
import '../blocs/playback_history/playback_history_state.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/playlists/playlists_cubit.dart';
import '../widgets/common/adaptive_scrollbar.dart';
import '../widgets/common/artwork_thumbnail.dart';
import '../widgets/common/library_search_field.dart';
import '../widgets/common/track_list_tile.dart';
import '../widgets/common/hover_glow_overlay.dart';
import '../widgets/macos/collection/collection_overview_grid.dart';
import '../widgets/macos/collection/collection_summary_card.dart';
import '../widgets/macos/macos_player_control_bar.dart';
import '../widgets/macos/macos_track_list_view.dart';
import 'lyrics/lyrics_overlay.dart';
import 'settings/settings_view.dart';

part 'home/home_page_content.dart';
part 'home/widgets/macos_glass_header.dart';
part 'home/widgets/macos_navigation_pane.dart';
part 'home/widgets/blurred_artwork_background.dart';
part 'home/widgets/playlist_message.dart';
part 'home/dialogs/webdav_connection_dialog.dart';
part 'home/dialogs/webdav_directory_picker_dialog.dart';
part 'home/dialogs/playlist_modal_components.dart';
part 'home/dialogs/playlist_creation_dialog.dart';
part 'home/views/music_library_view.dart';
part 'home/views/playlist_view.dart';
part 'home/views/playlists_view.dart';
part 'home/sheets/playlist_selection_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => MusicLibraryBloc(
            getAllTracks: sl<GetAllTracks>(),
            searchTracks: sl<SearchTracks>(),
            scanMusicDirectory: sl<ScanMusicDirectory>(),
            getAllArtists: sl<GetAllArtists>(),
            getAllAlbums: sl<GetAllAlbums>(),
            getLibraryDirectories: sl<GetLibraryDirectories>(),
            scanWebDavDirectory: sl<ScanWebDavDirectory>(),
            getWebDavSources: sl<GetWebDavSources>(),
            ensureWebDavTrackMetadata: sl<EnsureWebDavTrackMetadata>(),
            getWebDavPassword: sl<GetWebDavPassword>(),
            removeLibraryDirectory: sl<RemoveLibraryDirectory>(),
            deleteWebDavSource: sl<DeleteWebDavSource>(),
            watchTrackUpdates: sl<WatchTrackUpdates>(),
          )..add(const LoadAllTracks()),
        ),
        BlocProvider(
          create: (context) => PlayerBloc(
            playTrack: sl<PlayTrack>(),
            pausePlayer: sl<PausePlayer>(),
            resumePlayer: sl<ResumePlayer>(),
            stopPlayer: sl<StopPlayer>(),
            seekToPosition: sl<SeekToPosition>(),
            setVolume: sl<SetVolume>(),
            skipToNext: sl<SkipToNext>(),
            skipToPrevious: sl<SkipToPrevious>(),
            audioPlayerService: sl<AudioPlayerService>(),
          )..add(const PlayerRestoreLastSession()),
        ),
        BlocProvider(
          create: (context) =>
              PlaybackHistoryCubit(sl<PlaybackHistoryRepository>()),
        ),
        BlocProvider(
          create: (context) => PlaylistsCubit(sl<MusicLibraryRepository>()),
        ),
      ],
      child: const _MediaControlShortcutScope(
        child: HomePageContent(),
      ),
    );
  }
}

class _MediaControlShortcutScope extends StatelessWidget {
  const _MediaControlShortcutScope({required this.child});

  final Widget child;

  static final Map<LogicalKeySet, Intent> _shortcuts = <LogicalKeySet, Intent>{
    LogicalKeySet(LogicalKeyboardKey.mediaTrackPrevious): const _PreviousTrackIntent(),
    LogicalKeySet(LogicalKeyboardKey.mediaPlayPause): const _TogglePlayPauseIntent(),
    LogicalKeySet(LogicalKeyboardKey.mediaTrackNext): const _NextTrackIntent(),
    LogicalKeySet(LogicalKeyboardKey.f7): const _PreviousTrackIntent(),
    LogicalKeySet(LogicalKeyboardKey.f8): const _TogglePlayPauseIntent(),
    LogicalKeySet(LogicalKeyboardKey.f9): const _NextTrackIntent(),
  };

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return child;
    }

    void dispatchPrevious() {
      context.read<PlayerBloc>().add(const PlayerSkipPrevious());
    }

    void dispatchNext() {
      context.read<PlayerBloc>().add(const PlayerSkipNext());
    }

    void dispatchToggle() {
      final bloc = context.read<PlayerBloc>();
      final state = bloc.state;
      if (state is PlayerPlaying) {
        bloc.add(const PlayerPause());
      } else if (state is PlayerPaused) {
        bloc.add(const PlayerResume());
      }
    }

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PreviousTrackIntent: CallbackAction<_PreviousTrackIntent>(
            onInvoke: (_) {
              dispatchPrevious();
              return null;
            },
          ),
          _TogglePlayPauseIntent: CallbackAction<_TogglePlayPauseIntent>(
            onInvoke: (_) {
              dispatchToggle();
              return null;
            },
          ),
          _NextTrackIntent: CallbackAction<_NextTrackIntent>(
            onInvoke: (_) {
              dispatchNext();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          canRequestFocus: true,
          includeSemantics: false,
          child: child,
        ),
      ),
    );
  }
}

class _PreviousTrackIntent extends Intent {
  const _PreviousTrackIntent();
}

class _TogglePlayPauseIntent extends Intent {
  const _TogglePlayPauseIntent();
}

class _NextTrackIntent extends Intent {
  const _NextTrackIntent();
}
