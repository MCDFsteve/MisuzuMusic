import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data/datasources/local/database_helper.dart';
import '../../data/datasources/local/music_local_datasource.dart';
import '../../data/datasources/local/music_local_datasource_impl.dart';
import '../../data/datasources/local/lyrics_local_datasource.dart';
import '../../data/datasources/local/lyrics_local_datasource_impl.dart';
import '../../data/repositories/music_library_repository_impl.dart';
import '../../data/repositories/netease_repository_impl.dart';
import '../../data/repositories/lyrics_repository_impl.dart';
import '../../data/repositories/playback_history_repository_impl.dart';
import '../../data/services/audio_player_service_impl.dart';
import '../../data/services/misuzu_audio_handler.dart';
import '../../data/services/cloud_playlist_api.dart';
import '../../data/services/remote_lyrics_api.dart';
import '../../data/services/song_detail_service.dart';
import '../../data/services/song_id_mapping_service.dart';
import '../../data/services/netease_id_resolver.dart';
import '../../data/datasources/remote/netease_api_client.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../../domain/repositories/netease_repository.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../../domain/repositories/playback_history_repository.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/usecases/music_usecases.dart';
import '../../domain/usecases/player_usecases.dart';
import '../localization/locale_controller.dart';
import '../settings/online_metadata_controller.dart';
import '../theme/theme_controller.dart';
import '../../domain/usecases/lyrics_usecases.dart';
import '../storage/storage_path_provider.dart';
import '../storage/sandbox_path_codec.dart';
import '../storage/binary_config_store.dart';
import '../../data/storage/playlist_file_storage.dart';
import '../../data/storage/netease_session_store.dart';
import '../services/desktop_lyrics_bridge.dart';
import '../services/carplay_service.dart';
import '../services/file_association_service.dart';

final sl = GetIt.instance;

class DependencyInjection {
  static Future<void> init() async {
    print('🔧 开始初始化依赖注入...');

    try {
      _configureDatabaseFactory();
      JustAudioMediaKit.ensureInitialized(macOS: true);

      // Storage setup
      print('📁 配置存储路径与配置文件...');
      final storagePathProvider = StoragePathProvider();
      await storagePathProvider.ensureBaseDir();
      final configStore = BinaryConfigStore(storagePathProvider);
      await configStore.init();
      sl.registerSingleton(storagePathProvider);
      sl.registerSingleton(configStore);
      sl.registerLazySingleton(() => SandboxPathCodec());
      sl.registerLazySingleton(() => PlaylistFileStorage(sl(), sl()));
      sl.registerLazySingleton(() => NeteaseSessionStore(sl()));

      // Core
      print('🗄️ 初始化数据库...');
      sl.registerLazySingleton(() => DatabaseHelper(sl()));

      // Data sources
      print('📊 注册数据源...');
      sl.registerLazySingleton<MusicLocalDataSource>(
        () => MusicLocalDataSourceImpl(sl(), sl(), sl()),
      );

      sl.registerLazySingleton<LyricsLocalDataSource>(
        () => LyricsLocalDataSourceImpl(sl(), sl()),
      );

      // Repositories
      print('📚 注册仓库...');
      sl.registerLazySingleton<NeteaseApiClient>(() => NeteaseApiClient());
      sl.registerLazySingleton(() => SongIdMappingService());
      sl.registerLazySingleton(
        () => NeteaseIdResolver(mappingService: sl(), neteaseApiClient: sl()),
      );
      sl.registerLazySingleton(() => CloudPlaylistApi());
      sl.registerLazySingleton(() => RemoteLyricsApi());
      sl.registerLazySingleton(() => SongDetailService());

      sl.registerLazySingleton<MusicLibraryRepository>(
        () => MusicLibraryRepositoryImpl(
          localDataSource: sl(),
          configStore: sl(),
          neteaseApiClient: sl(),
          neteaseIdResolver: sl(),
          cloudPlaylistApi: sl(),
        ),
      );

      sl.registerLazySingleton<NeteaseRepository>(
        () => NeteaseRepositoryImpl(apiClient: sl(), sessionStore: sl()),
      );

      sl.registerLazySingleton<LyricsRepository>(
        () => LyricsRepositoryImpl(
          localDataSource: sl(),
          neteaseApiClient: sl(),
          remoteLyricsApi: sl(),
          neteaseIdResolver: sl(),
        ),
      );

      sl.registerLazySingleton<PlaybackHistoryRepository>(
        () => PlaybackHistoryRepositoryImpl(sl(), sl()),
      );

      // Services
      print('🎵 注册服务...');
      sl.registerLazySingleton<AudioPlayerService>(
        () => AudioPlayerServiceImpl(
          sl<BinaryConfigStore>(),
          sl<PlaybackHistoryRepository>(),
          sl<MusicLibraryRepository>(),
          sl<NeteaseRepository>(),
          sl(),
        ),
      );

      sl.registerLazySingleton(() => DesktopLyricsBridge());
      sl.registerLazySingleton(() => FileAssociationService());

      print('🎧 初始化音频处理程序...');
      final audioHandler = await AudioService.init(
        builder: () => MisuzuAudioHandler(sl<AudioPlayerService>()),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.aimessoft.misuzumusic.playback',
          androidNotificationChannelName: 'Misuzu Music',
          androidStopForegroundOnPause: true,
        ),
      );
      sl.registerSingleton<AudioHandler>(audioHandler);

      sl.registerLazySingleton(() => CarPlayService(sl(), sl()));
      await sl<CarPlayService>().initialize();

      sl.registerLazySingleton(() => ThemeController(sl()));
      sl.registerLazySingleton(() => LocaleController(sl()));
      sl.registerLazySingleton(() => OnlineMetadataController(sl()));

      // Use cases
      print('⚙️ 注册用例...');
      sl.registerLazySingleton(() => GetAllTracks(sl()));
      sl.registerLazySingleton(() => SearchTracks(sl()));
      sl.registerLazySingleton(() => ImportLocalTracks(sl()));
      sl.registerLazySingleton(() => ScanMusicDirectory(sl()));
      sl.registerLazySingleton(() => ScanWebDavDirectory(sl()));
      sl.registerLazySingleton(() => ScanJellyfinLibrary(sl()));
      sl.registerLazySingleton(() => MountMysteryLibrary(sl()));
      sl.registerLazySingleton(() => UnmountMysteryLibrary(sl()));
      sl.registerLazySingleton(() => GetAllArtists(sl()));
      sl.registerLazySingleton(() => GetAllAlbums(sl()));
      sl.registerLazySingleton(() => GetLibraryDirectories(sl()));
      sl.registerLazySingleton(() => RemoveLibraryDirectory(sl()));
      sl.registerLazySingleton(() => ClearLibrary(sl()));
      sl.registerLazySingleton(() => GetWebDavSources(sl()));
      sl.registerLazySingleton(() => GetWebDavSourceById(sl()));
      sl.registerLazySingleton(() => SaveWebDavSource(sl()));
      sl.registerLazySingleton(() => DeleteWebDavSource(sl()));
      sl.registerLazySingleton(() => GetWebDavPassword(sl()));
      sl.registerLazySingleton(() => TestWebDavConnection(sl()));
      sl.registerLazySingleton(() => ListWebDavDirectory(sl()));
      sl.registerLazySingleton(() => EnsureWebDavTrackMetadata(sl()));
      sl.registerLazySingleton(() => AuthenticateJellyfin(sl()));
      sl.registerLazySingleton(() => GetJellyfinLibraries(sl()));
      sl.registerLazySingleton(() => GetJellyfinSources(sl()));
      sl.registerLazySingleton(() => GetJellyfinSourceById(sl()));
      sl.registerLazySingleton(() => DeleteJellyfinSource(sl()));
      sl.registerLazySingleton(() => GetJellyfinAccessToken(sl()));
      sl.registerLazySingleton(() => WatchTrackUpdates(sl()));

      sl.registerLazySingleton(() => PlayTrack(sl()));
      sl.registerLazySingleton(() => PausePlayer(sl()));
      sl.registerLazySingleton(() => ResumePlayer(sl()));
      sl.registerLazySingleton(() => StopPlayer(sl()));
      sl.registerLazySingleton(() => SeekToPosition(sl()));
      sl.registerLazySingleton(() => SetVolume(sl()));
      sl.registerLazySingleton(() => SkipToNext(sl()));
      sl.registerLazySingleton(() => SkipToPrevious(sl()));

      sl.registerLazySingleton(() => GetLyrics(sl()));
      sl.registerLazySingleton(() => LoadLyricsFromFile(sl()));
      sl.registerLazySingleton(() => LoadLyricsFromMetadata(sl()));
      sl.registerLazySingleton(() => SaveLyrics(sl()));
      sl.registerLazySingleton(() => FindLyricsFile(sl()));
      sl.registerLazySingleton(() => FetchOnlineLyrics(sl()));

      // Initialize services
      print('🚀 初始化服务...');
      await sl<ThemeController>().load();
      await sl<LocaleController>().load();
      await sl<OnlineMetadataController>().load();

      print('✅ 依赖注入初始化完成！');
    } catch (e) {
      print('❌ 依赖注入初始化失败: $e');
      rethrow;
    }
  }

  static void _configureDatabaseFactory() {
    if (Platform.isAndroid || Platform.isIOS) {
      return;
    }

    print('💾 使用 sqflite_common_ffi 初始化桌面数据库工厂...');
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }
}
