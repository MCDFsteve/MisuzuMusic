import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:misuzu_music/presentation/pages/home_page.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/services/lrc_export_service.dart';
import '../../../core/services/desktop_lyrics_bridge.dart';
import '../../../domain/entities/lyrics_entities.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/usecases/lyrics_usecases.dart';
import '../../blocs/lyrics/lyrics_cubit.dart';
import '../../blocs/player/player_bloc.dart';
import '../../widgets/common/artwork_thumbnail.dart';
import '../../widgets/common/hover_glow_overlay.dart';
import '../../widgets/common/lyrics_display.dart';
import '../../../core/constants/mystery_library_constants.dart';
import '../../../core/widgets/modal_dialog.dart' hide showPlaylistModalDialog;
import '../../utils/track_display_utils.dart';

class LyricsOverlay extends StatefulWidget {
  const LyricsOverlay({
    super.key,
    required this.initialTrack,
    required this.isMac,
  });

  final Track initialTrack;
  final bool isMac;

  @override
  State<LyricsOverlay> createState() => _LyricsOverlayState();
}

class _LyricsOverlayState extends State<LyricsOverlay> {
  late Track _currentTrack;
  late final ScrollController _lyricsScrollController;
  late final LyricsCubit _lyricsCubit;
  late final DesktopLyricsBridge _desktopLyricsBridge;
  static bool _lastTranslationPreference = true;
  bool _showTranslation = _lastTranslationPreference;
  bool _desktopLyricsActive = false;
  bool _desktopLyricsBusy = false;
  bool _desktopLyricsErrorNotified = false;
  List<LyricsLine> _activeLyricsLines = const [];
  LyricsLine? _activeDesktopLine;
  int _activeDesktopIndex = -1;
  Duration? _currentPosition;
  bool _isPlaying = false;
  String? _lastDesktopPayloadSignature;
  bool _isSendingDesktopUpdate = false;
  bool _shouldResendDesktopUpdate = false;

  @override
  void initState() {
    super.initState();
    _currentTrack = widget.initialTrack;
    _lyricsScrollController = ScrollController();
    _desktopLyricsBridge = sl<DesktopLyricsBridge>();
    _lyricsCubit = LyricsCubit(
      findLyricsFile: sl<FindLyricsFile>(),
      loadLyricsFromFile: sl<LoadLyricsFromFile>(),
      fetchOnlineLyrics: sl<FetchOnlineLyrics>(),
      getLyrics: sl<GetLyrics>(),
    )..loadLyricsForTrack(_currentTrack);

    final initialPlayerState = context.read<PlayerBloc>().state;
    _updatePlaybackStateFromPlayer(initialPlayerState, notify: false);
  }

  @override
  void didUpdateWidget(covariant LyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTrack != oldWidget.initialTrack) {
      _currentTrack = widget.initialTrack;
      _lyricsCubit.loadLyricsForTrack(_currentTrack);
      _resetScroll();
      _activeLyricsLines = const [];
      _activeDesktopLine = null;
      _activeDesktopIndex = -1;
      _lastDesktopPayloadSignature = null;
      if (_desktopLyricsActive) {
        _scheduleDesktopLyricsUpdate(force: true);
      }
    }
  }

  @override
  void dispose() {
    if (_desktopLyricsActive) {
      _desktopLyricsActive = false;
      unawaited(_desktopLyricsBridge.clear());
    }
    _lyricsScrollController.dispose();
    _lyricsCubit.close();
    super.dispose();
  }

  void _resetScroll() {
    if (_lyricsScrollController.hasClients) {
      _lyricsScrollController.jumpTo(0);
    }
  }

  void _toggleTranslationVisibility() {
    if (!mounted) return;
    setState(() {
      _showTranslation = !_showTranslation;
    });
    _lastTranslationPreference = _showTranslation;
    if (_desktopLyricsActive) {
      _scheduleDesktopLyricsUpdate(force: true);
    }
  }

  void _scheduleDesktopLyricsUpdate({bool force = false}) {
    if (!_desktopLyricsActive) {
      return;
    }
    unawaited(_sendDesktopLyricsUpdate(force: force));
  }

  Future<void> _sendDesktopLyricsUpdate({bool force = false}) async {
    if (!_desktopLyricsActive) {
      return;
    }
    if (_isSendingDesktopUpdate) {
      if (force) {
        _shouldResendDesktopUpdate = true;
      }
      return;
    }

    final update = _buildDesktopLyricsUpdate();
    if (update == null) {
      return;
    }

    debugPrint('桌面歌词payload: ${jsonEncode(update.toJson())}');

    final signature = _signatureForUpdate(update);
    if (!force && _lastDesktopPayloadSignature == signature) {
      return;
    }

    _isSendingDesktopUpdate = true;
    try {
      final success = await _desktopLyricsBridge.update(update);
      if (success) {
        _lastDesktopPayloadSignature = signature;
        _desktopLyricsErrorNotified = false;
      } else {
        _lastDesktopPayloadSignature = null;
        if (!_desktopLyricsErrorNotified) {
          _desktopLyricsErrorNotified = true;
          if (mounted) {
            setState(() {
              _desktopLyricsActive = false;
            });
            unawaited(
              _showDesktopLyricsError('桌面歌词助手未响应，请确认已运行并允许网络访问。'),
            );
          }
        }
      }
    } finally {
      _isSendingDesktopUpdate = false;
      if (_shouldResendDesktopUpdate) {
        _shouldResendDesktopUpdate = false;
        await _sendDesktopLyricsUpdate(force: true);
      }
    }
  }

  DesktopLyricsUpdate? _buildDesktopLyricsUpdate() {
    final track = _currentTrack;
    if (track == null) {
      return null;
    }

    return DesktopLyricsUpdate(
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      activeLine: _sanitizeLine(_activeDesktopLine),
      nextLine: _sanitizeLine(_resolveNextDesktopLine()),
      positionMs: _currentPosition?.inMilliseconds,
      isPlaying: _isPlaying,
      activeSegments: _segmentsForLine(_activeDesktopLine),
      nextSegments: _segmentsForLine(_resolveNextDesktopLine()),
      activeTranslation: _showTranslation
          ? _lineTranslation(_activeDesktopLine)
          : null,
      nextTranslation:
          _showTranslation ? _lineTranslation(_resolveNextDesktopLine()) : null,
      showTranslation: _showTranslation,
    );
  }

  String _signatureForUpdate(DesktopLyricsUpdate update) {
    return jsonEncode(update.toJson());
  }

  String? _sanitizeLine(LyricsLine? line) {
    if (line == null) {
      return null;
    }
    final text = line.originalText.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  LyricsLine? _resolveNextDesktopLine() {
    final nextIndex = _activeDesktopIndex + 1;
    if (nextIndex < 0 || nextIndex >= _activeLyricsLines.length) {
      return null;
    }
    return _activeLyricsLines[nextIndex];
  }

  List<DesktopLyricsSegment>? _segmentsForLine(LyricsLine? line) {
    if (line == null) {
      return null;
    }
    if (line.annotatedTexts.isEmpty) {
      debugPrint('桌面歌词行缺少注音: ${line.originalText}');
      return null;
    }

    final segments = line.annotatedTexts
        .where((segment) => segment.original.isNotEmpty)
        .map(
          (segment) => DesktopLyricsSegment(
            original: segment.original,
            annotation: segment.annotation.trim(),
            type: segment.type.name,
          ),
        )
        .toList(growable: false);

    if (segments.isEmpty) {
      debugPrint('桌面歌词行注音过滤后为空: ${line.originalText}');
      return null;
    }
    debugPrint('桌面歌词行注音段数量: ${segments.length} -> ${line.originalText}');
    return segments;
  }

  String? _lineTranslation(LyricsLine? line) {
    final translation = line?.translatedText?.trim();
    if (translation == null || translation.isEmpty) {
      if (line != null) {
        debugPrint('桌面歌词行缺少翻译: ${line.originalText}');
      }
      return null;
    }
    return translation;
  }

  Future<void> _toggleDesktopLyricsAssistant() async {
    if (_desktopLyricsBusy) {
      return;
    }
    debugPrint(
      _desktopLyricsActive ? '准备关闭桌面歌词窗口' : '准备开启桌面歌词窗口',
    );
    setState(() {
      _desktopLyricsBusy = true;
    });

    try {
      if (_desktopLyricsActive) {
        await _disableDesktopLyrics();
      } else {
        await _enableDesktopLyrics();
      }
    } finally {
      if (mounted) {
        setState(() {
          _desktopLyricsBusy = false;
        });
      }
    }
  }

  Future<void> _enableDesktopLyrics() async {
    final track = _currentTrack;
    if (track == null) {
      await _showDesktopLyricsError('当前没有正在播放的歌曲，无法开启桌面歌词。');
      return;
    }

    final isAlive = await _desktopLyricsBridge.ping();
    if (!isAlive) {
      await _showDesktopLyricsError('未检测到桌面歌词助手，请先启动 misuzu-lyrics 程序。');
      return;
    }

    final shown = await _desktopLyricsBridge.showWindow();
    if (!shown) {
      await _showDesktopLyricsError('无法显示桌面歌词窗口，请检查助手程序状态。');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _desktopLyricsActive = true;
      _desktopLyricsErrorNotified = false;
      _lastDesktopPayloadSignature = null;
    });

    _syncDesktopLyricsState();
    await _sendDesktopLyricsUpdate(force: true);
  }

  Future<void> _disableDesktopLyrics({bool clear = true}) async {
    _shouldResendDesktopUpdate = false;
    if (!mounted) {
      if (clear) {
        unawaited(_desktopLyricsBridge.clear());
      }
      return;
    }

    setState(() {
      _desktopLyricsActive = false;
      _desktopLyricsErrorNotified = false;
      _lastDesktopPayloadSignature = null;
    });

    if (clear) {
      await _desktopLyricsBridge.clear();
    }
  }

  Future<void> _showDesktopLyricsError(String message) async {
    if (!mounted) {
      return;
    }

    await showPlaylistModalDialog(
      context: context,
      builder: (context) => PlaylistModalScaffold(
        title: '桌面歌词不可用',
        body: Text(message, locale: Locale("zh-Hans", "zh")),
        actions: [
          SheetActionButton.primary(
            label: '确定',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        maxWidth: 360,
      ),
    );
  }

  void _updatePlaybackStateFromPlayer(
    PlayerBlocState state, {
    bool notify = true,
  }) {
    Duration? position;
    bool playing = false;

    if (state is PlayerPlaying) {
      position = state.position;
      playing = true;
    } else if (state is PlayerPaused) {
      position = state.position;
      playing = false;
    } else if (state is PlayerLoading) {
      position = state.position;
      playing = false;
    }

    final bool playingChanged = playing != _isPlaying;
    _isPlaying = playing;
    _currentPosition = position;

    if (notify && playingChanged) {
      _scheduleDesktopLyricsUpdate(force: true);
    }
  }

  void _handleActiveIndexChanged(int index) {
    _activeDesktopIndex = index;
    if (index < 0 || index >= _activeLyricsLines.length) {
      _activeDesktopLine = null;
    } else {
      _activeDesktopLine = _activeLyricsLines[index];
    }
    debugPrint('桌面歌词当前索引更新: $index');
    if (_desktopLyricsActive) {
      _scheduleDesktopLyricsUpdate();
    }
  }

  void _handleActiveLineChanged(LyricsLine? line) {
    _activeDesktopLine = line;
    if (line == null) {
      _activeDesktopIndex = -1;
    }
    if (_desktopLyricsActive) {
      _scheduleDesktopLyricsUpdate();
    }
  }

  void _syncDesktopLyricsState() {
    if (_activeLyricsLines.isEmpty) {
      _activeDesktopLine = null;
      _activeDesktopIndex = -1;
      return;
    }

    final Duration? position = _currentPosition;
    if (position == null) {
      _activeDesktopIndex = 0;
      _activeDesktopLine = _activeLyricsLines.first;
      return;
    }

    int index = 0;
    for (int i = 0; i < _activeLyricsLines.length; i++) {
      final current = _activeLyricsLines[i].timestamp;
      final Duration? next = i + 1 < _activeLyricsLines.length
          ? _activeLyricsLines[i + 1].timestamp
          : null;
      if (position < current) {
        index = math.max(0, i - 1);
        break;
      }
      if (next == null || position < next) {
        index = i;
        break;
      }
    }

    _activeDesktopIndex = index;
    _activeDesktopLine = _activeLyricsLines[index];
  }

  Future<void> _reportError() async {
    const url = 'https://nipaplay.aimes-soft.com/lyrics_service.php';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showPlaylistModalDialog(
            context: context,
            builder: (context) => PlaylistModalScaffold(
              title: '无法打开链接',
              body: const Text(
                '无法打开浏览器，请手动访问:\nhttps://nipaplay.aimes-soft.com/lyrics_service.php',
                locale: Locale("zh-Hans", "zh"),
              ),
              actions: [
                SheetActionButton.primary(
                  label: '确定',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              maxWidth: 400,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showPlaylistModalDialog(
          context: context,
          builder: (context) => PlaylistModalScaffold(
            title: '打开链接出错',
            body: Text('打开浏览器时出错: $e', locale: Locale("zh-Hans", "zh")),
            actions: [
              SheetActionButton.primary(
                label: '确定',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            maxWidth: 400,
          ),
        );
      }
    }
  }

  Future<void> _downloadLrcFile() async {
    final lyricsState = _lyricsCubit.state;
    if (lyricsState is! LyricsLoaded || _currentTrack == null) {
      return;
    }

    try {
      // Generate LRC content
      final lrcContent = LrcExportService.formatLyricsToLrc(
        lyrics: lyricsState.lyrics,
        title: _currentTrack!.title,
        artist: _currentTrack!.artist,
        album: _currentTrack!.album,
      );

      // Generate filename
      final filename = LrcExportService.generateFilename(
        artist: _currentTrack!.artist,
        title: _currentTrack!.title,
        trackId: _currentTrack!.id,
      );

      // Save file
      final success = await LrcExportService.saveToFile(
        lrcContent: lrcContent,
        filename: filename,
      );

      if (mounted) {
        if (success) {
          // Show success message
          showPlaylistModalDialog(
            context: context,
            builder: (context) => PlaylistModalScaffold(
              title: '下载成功',
              body: const Text(
                'LRC歌词文件已保存到您选择的位置',
                locale: Locale("zh-Hans", "zh"),
              ),
              actions: [
                SheetActionButton.primary(
                  label: '确定',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              maxWidth: 300,
            ),
          );
        } else {
          // Show error message
          showPlaylistModalDialog(
            context: context,
            builder: (context) => PlaylistModalScaffold(
              title: '下载失败',
              body: const Text(
                '无法保存LRC文件，请检查文件夹权限设置',
                locale: Locale("zh-Hans", "zh"),
              ),
              actions: [
                SheetActionButton.primary(
                  label: '确定',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              maxWidth: 300,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = '下载LRC文件时出错: $e';
        showPlaylistModalDialog(
          context: context,
          builder: (context) => PlaylistModalScaffold(
            title: '下载出错',
            body: Text(errorMessage, locale: Locale("zh-Hans", "zh")),
            actions: [
              SheetActionButton.primary(
                label: '确定',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            maxWidth: 300,
          ),
        );
      }
    }
  }

  Track? _extractTrack(PlayerBlocState state) {
    if (state is PlayerPlaying) {
      return state.track;
    }
    if (state is PlayerPaused) {
      return state.track;
    }
    if (state is PlayerLoading) {
      return state.track;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMac = widget.isMac;

    return BlocProvider.value(
      value: _lyricsCubit,
      child: BlocListener<PlayerBloc, PlayerBlocState>(
        listener: (context, playerState) {
          _updatePlaybackStateFromPlayer(playerState);
          final nextTrack = _extractTrack(playerState);
          if (nextTrack != null && nextTrack != _currentTrack) {
            if (!mounted) return;
            setState(() => _currentTrack = nextTrack);
            _lyricsCubit.loadLyricsForTrack(nextTrack);
            _resetScroll();
            _activeLyricsLines = const [];
            _activeDesktopLine = null;
            _activeDesktopIndex = -1;
            _lastDesktopPayloadSignature = null;
            if (_desktopLyricsActive) {
              _scheduleDesktopLyricsUpdate(force: true);
            }
          }
        },
        child: BlocListener<LyricsCubit, LyricsState>(
          listener: (context, state) {
            if (state is LyricsLoaded || state is LyricsEmpty) {
              _resetScroll();
            }
    if (state is LyricsLoaded) {
      _activeLyricsLines = state.lyrics.lines;
      _activeDesktopIndex = -1;
      _activeDesktopLine = null;
      _lastDesktopPayloadSignature = null;
      _syncDesktopLyricsState();
      if (_desktopLyricsActive) {
        _scheduleDesktopLyricsUpdate(force: true);
      }
    } else if (state is LyricsEmpty || state is LyricsError) {
      _activeLyricsLines = const [];
              _activeDesktopLine = null;
              _activeDesktopIndex = -1;
              _lastDesktopPayloadSignature = null;
              if (_desktopLyricsActive) {
                _scheduleDesktopLyricsUpdate(force: true);
              }
            }
          },
          child: _LyricsLayout(
            track: _currentTrack,
            lyricsScrollController: _lyricsScrollController,
            isMac: isMac,
            showTranslation: _showTranslation,
            onToggleTranslation: _toggleTranslationVisibility,
            onDownloadLrc: _downloadLrcFile,
            onReportError: _reportError,
            onToggleDesktopLyrics: () =>
                unawaited(_toggleDesktopLyricsAssistant()),
            isDesktopLyricsActive: _desktopLyricsActive,
            isDesktopLyricsBusy: _desktopLyricsBusy,
            onActiveIndexChanged: _handleActiveIndexChanged,
            onActiveLineChanged: _handleActiveLineChanged,
          ),
        ),
      ),
    );
  }
}

class _LyricsLayout extends StatelessWidget {
  const _LyricsLayout({
    required this.track,
    required this.lyricsScrollController,
    required this.isMac,
    required this.showTranslation,
    required this.onToggleTranslation,
    required this.onDownloadLrc,
    required this.onReportError,
    required this.onToggleDesktopLyrics,
    required this.isDesktopLyricsActive,
    required this.isDesktopLyricsBusy,
    required this.onActiveIndexChanged,
    required this.onActiveLineChanged,
  });

  final Track track;
  final ScrollController lyricsScrollController;
  final bool isMac;
  final bool showTranslation;
  final VoidCallback onToggleTranslation;
  final VoidCallback onDownloadLrc;
  final VoidCallback onReportError;
  final VoidCallback onToggleDesktopLyrics;
  final bool isDesktopLyricsActive;
  final bool isDesktopLyricsBusy;
  final ValueChanged<int> onActiveIndexChanged;
  final ValueChanged<LyricsLine?> onActiveLineChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedTrack = applyDisplayInfo(
      track,
      deriveTrackDisplayInfo(track),
    );
    final EdgeInsets contentPadding = EdgeInsets.zero;

    return Container(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double coverSize = _resolveCoverSize(constraints.maxWidth);
          final bool isDarkMode = isMac
              ? MacosTheme.of(context).brightness == Brightness.dark
              : Theme.of(context).brightness == Brightness.dark;
          final DividerThemeData dividerTheme = DividerTheme.of(context);
          final Color dividerColor = isMac
              ? MacosTheme.of(context).dividerColor.withOpacity(0.35)
              : dividerTheme.color ?? Theme.of(context).dividerColor;

          return Padding(
            padding: contentPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 10,
                  child: _CoverColumn(
                    track: normalizedTrack,
                    coverSize: coverSize,
                    isMac: isMac,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 50,
                  ),
                  color: dividerColor.withOpacity(0.35),
                ),
                Expanded(
                  flex: 13,
                  child: _LyricsPanel(
                    isDarkMode: isDarkMode,
                    scrollController: lyricsScrollController,
                    track: normalizedTrack,
                    showTranslation: showTranslation,
                    onToggleTranslation: onToggleTranslation,
                    onDownloadLrc: onDownloadLrc,
                    onReportError: onReportError,
                    onToggleDesktopLyrics: onToggleDesktopLyrics,
                    isDesktopLyricsActive: isDesktopLyricsActive,
                    isDesktopLyricsBusy: isDesktopLyricsBusy,
                    onActiveIndexChanged: onActiveIndexChanged,
                    onActiveLineChanged: onActiveLineChanged,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _resolveCoverSize(double maxWidth) {
    if (!maxWidth.isFinite) {
      return 320;
    }
    final double base = math.max(220, maxWidth * 0.28);
    return base.clamp(220, 420);
  }
}

class _CoverColumn extends StatelessWidget {
  const _CoverColumn({
    required this.track,
    required this.coverSize,
    required this.isMac,
  });

  final Track track;
  final double coverSize;
  final bool isMac;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = isMac
        ? MacosTheme.of(
            context,
          ).typography.title1.copyWith(fontWeight: FontWeight.w600)
        : Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ) ??
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    final TextStyle subtitleStyle = isMac
        ? MacosTheme.of(context).typography.body.copyWith(
            color: MacosTheme.of(
              context,
            ).typography.body.color?.withOpacity(0.75),
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ) ??
              const TextStyle(fontSize: 14, color: Colors.black54);

    String? remoteArtworkUrl;
    if (track.sourceType == TrackSourceType.netease) {
      remoteArtworkUrl = track.httpHeaders?['x-netease-cover'];
    } else {
      remoteArtworkUrl =
          MysteryLibraryConstants.buildArtworkUrl(
            track.httpHeaders,
            thumbnail: false,
          ) ??
          MysteryLibraryConstants.buildArtworkUrl(
            track.httpHeaders,
            thumbnail: true,
          );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          HoverGlowOverlay(
            isDarkMode: isMac
                ? MacosTheme.of(context).brightness == Brightness.dark
                : Theme.of(context).brightness == Brightness.dark,
            borderRadius: BorderRadius.circular(24),
            glowRadius: 1.05,
            glowOpacity: 0.85,
            blurSigma: 0,
            cursor: SystemMouseCursors.basic,
            child: ArtworkThumbnail(
              artworkPath: track.artworkPath,
              remoteImageUrl: remoteArtworkUrl,
              size: coverSize,
              borderRadius: BorderRadius.circular(20),
              backgroundColor: isMac
                  ? MacosColors.controlBackgroundColor
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderColor: isMac
                  ? MacosTheme.of(context).dividerColor
                  : Theme.of(context).dividerColor,
              placeholder: Icon(
                CupertinoIcons.music_note,
                color: isMac
                    ? MacosColors.systemGrayColor
                    : Theme.of(context).hintColor.withOpacity(0.6),
                size: coverSize * 0.28,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: math.min(480, coverSize * 1.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  track.title,
                  textAlign: TextAlign.center,
                  locale: Locale("zh-Hans", "zh"),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  '${track.artist} · ${track.album}',
                  locale: Locale("zh-Hans", "zh"),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({
    required this.isDarkMode,
    required this.scrollController,
    required this.track,
    required this.showTranslation,
    required this.onToggleTranslation,
    required this.onDownloadLrc,
    required this.onReportError,
    required this.onToggleDesktopLyrics,
    required this.isDesktopLyricsActive,
    required this.isDesktopLyricsBusy,
    required this.onActiveIndexChanged,
    required this.onActiveLineChanged,
  });

  final bool isDarkMode;
  final ScrollController scrollController;
  final Track track;
  final bool showTranslation;
  final VoidCallback onToggleTranslation;
  final VoidCallback onDownloadLrc;
  final VoidCallback onReportError;
  final VoidCallback onToggleDesktopLyrics;
  final bool isDesktopLyricsActive;
  final bool isDesktopLyricsBusy;
  final ValueChanged<int> onActiveIndexChanged;
  final ValueChanged<LyricsLine?> onActiveLineChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final behavior = ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false);
          final viewportHeight = constraints.maxHeight;
          return BlocBuilder<LyricsCubit, LyricsState>(
            builder: (context, state) {
              final Widget content = ScrollConfiguration(
                behavior: behavior,
                child: _buildLyricsContent(
                  context,
                  state,
                  scrollController,
                  isDarkMode,
                  viewportHeight,
                  showTranslation,
                ),
              );

              final bool canToggle =
                  state is LyricsLoaded && _hasAnyTranslation(state.lyrics);

              final bool showReportError =
                  state is LyricsLoaded &&
                  state.lyrics.source == LyricsSource.nipaplay;

              return Stack(
                children: [
                  Positioned.fill(child: content),
                  if (showReportError)
                    Positioned(
                      bottom: 190,
                      right: 12,
                      child: _ReportErrorButton(
                        isDarkMode: isDarkMode,
                        onPressed: onReportError,
                      ),
                    ),
                  Positioned(
                    bottom: 130,
                    right: 12,
                    child: _DownloadLrcButton(
                      isDarkMode: isDarkMode,
                      isEnabled: state is LyricsLoaded,
                      onPressed: state is LyricsLoaded ? onDownloadLrc : null,
                    ),
                  ),
                  Positioned(
                    bottom: 75,
                    right: 12,
                    child: _DesktopLyricsToggleButton(
                      isDarkMode: isDarkMode,
                      isActive: isDesktopLyricsActive,
                      isBusy: isDesktopLyricsBusy,
                      onPressed: onToggleDesktopLyrics,
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 12,
                    child: _TranslationToggleButton(
                      isDarkMode: isDarkMode,
                      isActive: showTranslation,
                      isEnabled: canToggle,
                      onPressed: canToggle ? onToggleTranslation : null,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLyricsContent(
    BuildContext context,
    LyricsState state,
    ScrollController controller,
    bool isDarkMode,
    double viewportHeight,
    bool showTranslation,
  ) {
    if (state is LyricsLoading || state is LyricsInitial) {
      return _buildInfoMessage(
        controller,
        title: '歌词获取中',
        subtitle: '正在加载 ${track.title} 的歌词…',
        isDarkMode: isDarkMode,
        viewportHeight: viewportHeight,
      );
    }

    if (state is LyricsError) {
      return _buildInfoMessage(
        controller,
        title: '歌词加载失败',
        subtitle: state.message,
        isDarkMode: isDarkMode,
        viewportHeight: viewportHeight,
      );
    }

    if (state is LyricsEmpty) {
      return _buildInfoMessage(
        controller,
        title: '暂无歌词',
        subtitle: '暂未找到 ${track.title} 的歌词。',
        isDarkMode: isDarkMode,
        viewportHeight: viewportHeight,
      );
    }

      if (state is LyricsLoaded) {
        final lines = state.lyrics.lines;
        if (lines.isEmpty) {
          return _buildInfoMessage(
            controller,
            title: '暂无歌词',
            subtitle: '暂未找到 ${track.title} 的歌词。',
            isDarkMode: isDarkMode,
            viewportHeight: viewportHeight,
          );
        }

        return LyricsDisplay(
          key: ValueKey(track.id),
          lines: lines,
          controller: controller,
          isDarkMode: isDarkMode,
          showTranslation: showTranslation,
          onActiveIndexChanged: onActiveIndexChanged,
          onActiveLineChanged: onActiveLineChanged,
        );
      }

    return const SizedBox.shrink();
  }

  Widget _buildInfoMessage(
    ScrollController controller, {
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required double viewportHeight,
  }) {
    final TextStyle titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: isDarkMode ? Colors.white : Colors.black87,
    );
    final TextStyle subtitleStyle = TextStyle(
      fontSize: 14,
      color: isDarkMode ? Colors.white70 : Colors.black54,
    );

    const double estimate = 72;
    final double padding = viewportHeight.isFinite
        ? math.max(0, (viewportHeight - estimate) * 0.5)
        : 160;

    return ListView(
      controller: controller,
      padding: EdgeInsets.only(top: padding, bottom: padding),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                locale: Locale("zh-Hans", "zh"),
                style: titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                locale: Locale("zh-Hans", "zh"),
                style: subtitleStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasAnyTranslation(Lyrics lyrics) {
    return lyrics.lines.any(
      (line) => (line.translatedText ?? '').trim().isNotEmpty,
    );
  }
}

class _TranslationToggleButton extends StatelessWidget {
  const _TranslationToggleButton({
    required this.isDarkMode,
    required this.isActive,
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isDarkMode;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isDarkMode ? Colors.white : Colors.black;
    final String tooltip = isEnabled ? (isActive ? '隐藏翻译' : '显示翻译') : '暂无可用翻译';
    final String assetPath = !isEnabled
        ? 'icons/tran2.png'
        : (isActive ? 'icons/tran.png' : 'icons/tran2.png');

    final double iconSize = 25;
    final Color activeColor = iconColor;
    final Color inactiveColor = iconColor.withOpacity(0.82);
    final Color disabledColor = iconColor.withOpacity(0.42);

    return MacosTooltip(
      message: tooltip,
      child: _HoverGlyphButton(
        enabled: isEnabled,
        onPressed: onPressed,
        assetPath: assetPath,
        size: iconSize,
        baseColor: isEnabled
            ? (isActive ? inactiveColor : inactiveColor)
            : disabledColor,
        hoverColor: isEnabled ? activeColor : disabledColor,
        disabledColor: disabledColor,
      ),
    );
  }
}

class _HoverGlyphButton extends StatefulWidget {
  const _HoverGlyphButton({
    required this.enabled,
    required this.onPressed,
    required this.baseColor,
    required this.hoverColor,
    required this.disabledColor,
    this.assetPath,
    this.icon,
    this.size = 30,
  }) : assert(
         assetPath != null || icon != null,
         'assetPath or icon must be provided',
       );

  final bool enabled;
  final VoidCallback? onPressed;
  final String? assetPath;
  final IconData? icon;
  final Color baseColor;
  final Color hoverColor;
  final Color disabledColor;
  final double size;

  @override
  State<_HoverGlyphButton> createState() => _HoverGlyphButtonState();
}

class _HoverGlyphButtonState extends State<_HoverGlyphButton> {
  bool _hovering = false;
  bool _pressing = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  void _setHovering(bool value) {
    if (!_enabled || _hovering == value) return;
    setState(() => _hovering = value);
  }

  void _setPressing(bool value) {
    if (!_enabled || _pressing == value) return;
    setState(() => _pressing = value);
  }

  Color get _currentColor {
    if (!_enabled) {
      return widget.disabledColor;
    }
    if (_hovering) {
      return widget.hoverColor;
    }
    return widget.baseColor;
  }

  double get _currentScale {
    if (!_enabled) {
      return 1.0;
    }
    if (_pressing) {
      return 0.95;
    }
    if (_hovering) {
      return 1.05;
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final Widget glyph;
    if (widget.icon != null) {
      glyph = Icon(
        widget.icon,
        size: widget.size,
        color: _pressing && _enabled ? widget.hoverColor : _currentColor,
      );
    } else {
      glyph = MacosImageIcon(
        AssetImage(widget.assetPath!),
        size: widget.size,
        color: _pressing && _enabled ? widget.hoverColor : _currentColor,
      );
    }

    final child = AnimatedScale(
      scale: _currentScale,
      duration: const Duration(milliseconds: 140),
      curve: _pressing ? Curves.easeInOut : Curves.easeOutBack,
      child: glyph,
    );

    final button = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _enabled ? widget.onPressed : null,
      onTapDown: _enabled ? (_) => _setPressing(true) : null,
      onTapUp: _enabled ? (_) => _setPressing(false) : null,
      onTapCancel: _enabled ? () => _setPressing(false) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: SizedBox(width: 30, height: 30, child: Center(child: child)),
      ),
    );

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHovering(true),
      onExit: (_) {
        _setHovering(false);
        _setPressing(false);
      },
      child: button,
    );
  }
}

class _DownloadLrcButton extends StatelessWidget {
  const _DownloadLrcButton({
    required this.isDarkMode,
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isDarkMode;
  final bool isEnabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isDarkMode ? Colors.white : Colors.black;
    final String tooltip = isEnabled ? '下载LRC歌词文件' : '歌词加载中...';

    final double iconSize = 25;
    final Color activeColor = iconColor;
    final Color inactiveColor = iconColor.withOpacity(0.82);
    final Color disabledColor = iconColor.withOpacity(0.42);

    return MacosTooltip(
      message: tooltip,
      child: _DownloadIconButton(
        enabled: isEnabled,
        onPressed: onPressed,
        baseColor: isEnabled ? inactiveColor : disabledColor,
        hoverColor: isEnabled ? activeColor : disabledColor,
        disabledColor: disabledColor,
        size: iconSize,
      ),
    );
  }
}

class _DesktopLyricsToggleButton extends StatelessWidget {
  const _DesktopLyricsToggleButton({
    required this.isDarkMode,
    required this.isActive,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isDarkMode;
  final bool isActive;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isDarkMode ? Colors.white : Colors.black;
    final bool enabled = !isBusy;
    final Color disabledColor = iconColor.withOpacity(0.4);
    final Color baseColor = enabled
        ? (isActive ? iconColor : iconColor.withOpacity(0.78))
        : disabledColor;
    final String tooltip = isBusy
        ? '处理中...'
        : (isActive ? '关闭桌面歌词窗口' : '显示桌面歌词窗口');

    return MacosTooltip(
      message: tooltip,
      child: _HoverGlyphButton(
        enabled: enabled,
        onPressed: enabled ? onPressed : null,
        icon: CupertinoIcons.macwindow,
        size: 26,
        baseColor: baseColor,
        hoverColor: iconColor,
        disabledColor: disabledColor,
      ),
    );
  }
}

class _DownloadIconButton extends StatefulWidget {
  const _DownloadIconButton({
    required this.enabled,
    required this.onPressed,
    required this.baseColor,
    required this.hoverColor,
    required this.disabledColor,
    this.size = 30,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final Color baseColor;
  final Color hoverColor;
  final Color disabledColor;
  final double size;

  @override
  State<_DownloadIconButton> createState() => _DownloadIconButtonState();
}

class _DownloadIconButtonState extends State<_DownloadIconButton> {
  bool _hovering = false;
  bool _pressing = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  void _setHovering(bool value) {
    if (!_enabled || _hovering == value) return;
    setState(() => _hovering = value);
  }

  void _setPressing(bool value) {
    if (!_enabled || _pressing == value) return;
    setState(() => _pressing = value);
  }

  Color get _currentColor {
    if (!_enabled) {
      return widget.disabledColor;
    }
    if (_hovering) {
      return widget.hoverColor;
    }
    return widget.baseColor;
  }

  double get _currentScale {
    if (!_enabled) {
      return 1.0;
    }
    if (_pressing) {
      return 0.95;
    }
    if (_hovering) {
      return 1.05;
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final child = Transform.scale(
      scale: _currentScale,
      child: Icon(
        CupertinoIcons.cloud_download,
        size: widget.size,
        color: _currentColor,
      ),
    );

    final button = GestureDetector(
      onTap: _enabled ? widget.onPressed : null,
      onTapDown: _enabled ? (_) => _setPressing(true) : null,
      onTapUp: _enabled ? (_) => _setPressing(false) : null,
      onTapCancel: _enabled ? () => _setPressing(false) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: SizedBox(width: 30, height: 30, child: Center(child: child)),
      ),
    );

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHovering(true),
      onExit: (_) {
        _setHovering(false);
        _setPressing(false);
      },
      child: button,
    );
  }
}

class _ReportErrorButton extends StatefulWidget {
  const _ReportErrorButton({required this.isDarkMode, required this.onPressed});

  final bool isDarkMode;
  final VoidCallback onPressed;

  @override
  State<_ReportErrorButton> createState() => _ReportErrorButtonState();
}

class _ReportErrorButtonState extends State<_ReportErrorButton> {
  bool _hovering = false;
  bool _pressing = false;

  void _setHovering(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  void _setPressing(bool value) {
    if (_pressing == value) return;
    setState(() => _pressing = value);
  }

  Color get _currentColor {
    final Color iconColor = widget.isDarkMode ? Colors.white : Colors.black;
    if (_hovering) {
      return iconColor;
    }
    return iconColor.withOpacity(0.82);
  }

  double get _currentScale {
    if (_pressing) {
      return 0.95;
    }
    if (_hovering) {
      return 1.05;
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final child = Transform.scale(
      scale: _currentScale,
      child: Icon(CupertinoIcons.pencil, size: 25, color: _currentColor),
    );

    final button = GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => _setPressing(true),
      onTapUp: (_) => _setPressing(false),
      onTapCancel: () => _setPressing(false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: SizedBox(width: 30, height: 30, child: Center(child: child)),
      ),
    );

    return MacosTooltip(
      message: '纠错',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovering(true),
        onExit: (_) {
          _setHovering(false);
          _setPressing(false);
        },
        child: button,
      ),
    );
  }
}
