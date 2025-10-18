import 'package:get_it/get_it.dart';

import '../../data/datasources/local/database_helper.dart';
import '../../data/datasources/local/music_local_datasource.dart';
import '../../data/datasources/local/music_local_datasource_impl.dart';
import '../../data/datasources/local/lyrics_local_datasource.dart';
import '../../data/datasources/local/lyrics_local_datasource_impl.dart';
import '../../data/repositories/music_library_repository_impl.dart';
import '../../data/repositories/lyrics_repository_impl.dart';
import '../../data/repositories/playback_history_repository_impl.dart';
import '../../data/services/audio_player_service_impl.dart';
import '../../data/services/japanese_processing_service_impl.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../../domain/repositories/playback_history_repository.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/services/japanese_processing_service.dart';
import '../../domain/usecases/music_usecases.dart';
import '../../domain/usecases/player_usecases.dart';
import '../theme/theme_controller.dart';
import '../../domain/usecases/lyrics_usecases.dart';
import '../storage/storage_path_provider.dart';
import '../storage/binary_config_store.dart';

final sl = GetIt.instance;

class DependencyInjection {
  static Future<void> init() async {
    print('🔧 开始初始化依赖注入...');

    try {
      // Storage setup
      print('📁 配置存储路径与配置文件...');
      final storagePathProvider = StoragePathProvider();
      await storagePathProvider.ensureBaseDir();
      final configStore = BinaryConfigStore(storagePathProvider);
      await configStore.init();
      sl.registerSingleton(storagePathProvider);
      sl.registerSingleton(configStore);

      // Core
      print('🗄️ 初始化数据库...');
      sl.registerLazySingleton(() => DatabaseHelper(sl()));

      // Data sources
      print('📊 注册数据源...');
      sl.registerLazySingleton<MusicLocalDataSource>(
        () => MusicLocalDataSourceImpl(sl()),
      );

      sl.registerLazySingleton<LyricsLocalDataSource>(
        () => LyricsLocalDataSourceImpl(sl(), sl()),
      );

      // Repositories
      print('📚 注册仓库...');
      sl.registerLazySingleton<MusicLibraryRepository>(
        () => MusicLibraryRepositoryImpl(
          localDataSource: sl(),
        ),
      );

      sl.registerLazySingleton<LyricsRepository>(
        () => LyricsRepositoryImpl(
          localDataSource: sl(),
          japaneseProcessingService: sl(),
        ),
      );

      sl.registerLazySingleton<PlaybackHistoryRepository>(
        () => PlaybackHistoryRepositoryImpl(sl()),
      );

      // Services
      print('🎵 注册服务...');
      sl.registerLazySingleton<AudioPlayerService>(
        () => AudioPlayerServiceImpl(sl(), sl()),
      );

      sl.registerLazySingleton<JapaneseProcessingService>(
        () => JapaneseProcessingServiceImpl(),
      );

      sl.registerLazySingleton(() => ThemeController(sl()));

      // Use cases
      print('⚙️ 注册用例...');
      sl.registerLazySingleton(() => GetAllTracks(sl()));
      sl.registerLazySingleton(() => SearchTracks(sl()));
      sl.registerLazySingleton(() => ScanMusicDirectory(sl()));
      sl.registerLazySingleton(() => GetAllArtists(sl()));
      sl.registerLazySingleton(() => GetAllAlbums(sl()));

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
      sl.registerLazySingleton(() => SaveLyrics(sl()));
      sl.registerLazySingleton(() => FindLyricsFile(sl()));

      // Initialize services
      print('🚀 初始化服务...');
      await sl<JapaneseProcessingService>().initialize();
      await sl<ThemeController>().load();

      print('✅ 依赖注入初始化完成！');
    } catch (e) {
      print('❌ 依赖注入初始化失败: $e');
      rethrow;
    }
  }
}
