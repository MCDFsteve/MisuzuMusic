import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:misuzu_music/presentation/pages/home_page.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../data/services/song_detail_service.dart';
import '../../../data/services/netease_id_resolver.dart';
import '../../../data/models/netease_models.dart';
import '../../../core/services/lrc_export_service.dart';
import '../../../core/services/desktop_lyrics_bridge.dart';
import '../../../core/constants/app_constants.dart';
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
import '../../../core/utils/platform_utils.dart';
import '../../../l10n/l10n.dart';
import 'package:http/http.dart' as http;

const bool _desktopLyricsVerboseLogging = false;

final RegExp _desktopLyricsHanCharacterRegExp = RegExp(
  r'[\u3400-\u4DBF\u4E00-\u9FFF]',
);

enum _CompactLyricsStage { cover, lyrics, detail }

class LyricsOverlay extends StatefulWidget {
  const LyricsOverlay({
    super.key,
    required this.initialTrack,
    required this.isMac,
    this.bottomSafeInset = 0,
  });

  final Track initialTrack;
  final bool isMac;
  final double bottomSafeInset;

  @override
  State<LyricsOverlay> createState() => _LyricsOverlayState();
}

class _LyricsOverlayState extends State<LyricsOverlay> {
  late Track _currentTrack;
  late final ScrollController _lyricsScrollController;
  late final LyricsCubit _lyricsCubit;
  late final DesktopLyricsBridge _desktopLyricsBridge;
  late final SongDetailService _songDetailService;
  late final NeteaseIdResolver _neteaseIdResolver;
  static bool _lastTranslationPreference = true;
  static LyricsVisualStyle _lastLyricsStyle = LyricsVisualStyle.highlight;
  bool _showTranslation = _lastTranslationPreference;
  LyricsVisualStyle _lyricsStyle = _lastLyricsStyle;
  Color? _artworkGlowColor;
  bool _lyricsHidden = false;
  bool _desktopLyricsActive = false;
  bool _desktopLyricsBusy = false;
  bool _desktopLyricsErrorNotified = false;
  List<LyricsLine> _activeLyricsLines = const [];
  LyricsLine? _activeDesktopLine;
  int _activeDesktopIndex = -1;
  String? _lastDesktopActiveText;
  Duration? _currentPosition;
  bool _isPlaying = false;
  String? _lastDesktopPayloadSignature;
  bool _isSendingDesktopUpdate = false;
  bool _shouldResendDesktopUpdate = false;
  StreamSubscription<PlayerBlocState>? _playerSubscription;
  PlayerBlocState? _lastProcessedPlayerState;
  bool _showTrackDetailPanel = false;
  _CompactLyricsStage _compactLyricsStage = _CompactLyricsStage.cover;
  bool _isLoadingTrackDetail = false;
  bool _isSavingTrackDetail = false;
  String? _trackDetailContent;
  String? _trackDetailFileName;
  String? _trackDetailError;
  String? _trackDetailLoadedKey;
  int _trackDetailRequestToken = 0;
  String? _trackQualityLabel;
  int _trackQualityRequestToken = 0;
  static final Map<String, Color?> _artworkGlowCache = {};

  @override
  void initState() {
    super.initState();
    _currentTrack = widget.initialTrack;
    _lyricsScrollController = ScrollController();
    _desktopLyricsBridge = sl<DesktopLyricsBridge>();
    _songDetailService = sl<SongDetailService>();
    _neteaseIdResolver = sl<NeteaseIdResolver>();
    _lyricsCubit = context.read<LyricsCubit>();
    _ensureLyricsLoaded(_currentTrack);
    _resetDesktopLineCache();
    _loadArtworkGlowColor(_currentTrack);
    _trackQualityLabel = _buildQualityLabel(
      bitrate: _currentTrack.bitrate,
      sampleRate: _currentTrack.sampleRate,
    );
    unawaited(_loadTrackQuality(_currentTrack));

    final initialPlayerState = context.read<PlayerBloc>().state;
    _updatePlaybackStateFromPlayer(initialPlayerState, notify: false);
    _lastProcessedPlayerState = initialPlayerState;
    _playerSubscription = context.read<PlayerBloc>().stream.listen(
      _handlePlayerStateStream,
    );
  }

  @override
  void didUpdateWidget(covariant LyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTrack != oldWidget.initialTrack) {
      _currentTrack = widget.initialTrack;
      _lyricsHidden = false;
      _resetTrackDetailState();
      _ensureLyricsLoaded(_currentTrack);
      _resetScroll();
      _activeLyricsLines = const [];
      _activeDesktopLine = null;
      _activeDesktopIndex = -1;
      _lastDesktopPayloadSignature = null;
      _resetDesktopLineCache();
      _artworkGlowColor = null;
      _loadArtworkGlowColor(_currentTrack);
      _trackQualityLabel = _buildQualityLabel(
        bitrate: _currentTrack.bitrate,
        sampleRate: _currentTrack.sampleRate,
      );
      unawaited(_loadTrackQuality(_currentTrack));
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
      unawaited(_desktopLyricsBridge.hideWindow());
    }
    unawaited(_playerSubscription?.cancel());
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _resetScroll() {
    if (_lyricsScrollController.hasClients) {
      _lyricsScrollController.jumpTo(0);
    }
  }

  void _resetDesktopLineCache() {
    _lastDesktopActiveText = null;
  }

  Future<void> _loadArtworkGlowColor(Track track) async {
    final String cacheKey = track.id;
    if (_artworkGlowCache.containsKey(cacheKey)) {
      if (!mounted) {
        return;
      }
      setState(() {
        _artworkGlowColor = _artworkGlowCache[cacheKey];
      });
      return;
    }

    final Color? glowColor = await _computeArtworkGlowColor(track);
    _artworkGlowCache[cacheKey] = glowColor;
    if (!mounted || track.id != _currentTrack.id) {
      return;
    }
    setState(() {
      _artworkGlowColor = glowColor;
    });
  }

  Future<Color?> _computeArtworkGlowColor(Track track) async {
    try {
      final Uint8List? bytes = await _loadArtworkBytes(track);
      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
        bytes,
      );
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(
        buffer,
      );
      final ui.Codec codec = await descriptor.instantiateCodec(
        targetWidth: 64,
        targetHeight: 64,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();

      if (data == null) {
        return null;
      }

      final Uint8List pixels = data.buffer.asUint8List();
      int r = 0;
      int g = 0;
      int b = 0;
      int count = 0;

      for (int i = 0; i + 3 < pixels.length; i += 4) {
        final int a = pixels[i + 3];
        if (a < 16) {
          continue;
        }
        r += pixels[i];
        g += pixels[i + 1];
        b += pixels[i + 2];
        count++;
      }

      if (count == 0) {
        return null;
      }

      final Color average = Color.fromARGB(
        255,
        r ~/ count,
        g ~/ count,
        b ~/ count,
      );
      return _boostGlowColor(average);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadTrackQuality(Track track) async {
    final initialLabel = _buildQualityLabel(
      bitrate: track.bitrate,
      sampleRate: track.sampleRate,
    );
    if (mounted && initialLabel != _trackQualityLabel) {
      setState(() => _trackQualityLabel = initialLabel);
    }

    if (track.sourceType != TrackSourceType.local) {
      return;
    }

    final file = File(track.filePath);
    if (!await file.exists()) {
      return;
    }

    final requestId = ++_trackQualityRequestToken;
    try {
      final metadata = await readMetadata(file, getImage: false);
      final int? bitrate =
          metadata?.bitrate ??
          await _calculateBitrateFromFile(
            file,
            metadata?.duration ?? track.duration,
          );
      final int? sampleRate = metadata?.sampleRate ?? track.sampleRate;
      final label = _buildQualityLabel(
        bitrate: bitrate,
        sampleRate: sampleRate,
      );
      if (!mounted || requestId != _trackQualityRequestToken) {
        return;
      }
      if (label != null && label != _trackQualityLabel) {
        setState(() => _trackQualityLabel = label);
      }
    } catch (_) {
      // 忽略获取失败，音质信息为可选。
    }
  }

  Future<int?> _calculateBitrateFromFile(File file, Duration duration) async {
    if (duration <= Duration.zero) {
      return null;
    }
    try {
      final length = await file.length();
      if (length <= 0) {
        return null;
      }
      final seconds = duration.inMilliseconds / 1000;
      if (seconds <= 0) {
        return null;
      }
      return (length * 8 / seconds).round();
    } catch (_) {
      return null;
    }
  }

  String? _buildQualityLabel({int? bitrate, int? sampleRate}) {
    final bitrateText = _formatBitrate(bitrate);
    final sampleRateText = _formatSampleRate(sampleRate);
    final parts = <String>[];
    if (bitrateText != null) {
      parts.add(bitrateText);
    }
    if (sampleRateText != null) {
      parts.add(sampleRateText);
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }

  String? _formatBitrate(int? bitrate) {
    if (bitrate == null || bitrate <= 0) {
      return null;
    }
    final kbps = bitrate / 1000;
    final hasFraction = kbps % 1 != 0;
    final String display = hasFraction
        ? (kbps >= 100 ? kbps.toStringAsFixed(0) : kbps.toStringAsFixed(1))
        : kbps.toStringAsFixed(0);
    return '$display kbps';
  }

  String? _formatSampleRate(int? sampleRate) {
    if (sampleRate == null || sampleRate <= 0) {
      return null;
    }
    final khz = sampleRate / 1000;
    final hasFraction = khz % 1 != 0;
    final String display = hasFraction
        ? (khz >= 10 ? khz.toStringAsFixed(1) : khz.toStringAsFixed(2))
        : khz.toStringAsFixed(0);
    return '$display kHz';
  }

  Future<Uint8List?> _loadArtworkBytes(Track track) async {
    final String? artworkPath = track.artworkPath;
    if (artworkPath != null && artworkPath.isNotEmpty) {
      final file = File(artworkPath);
      if (await file.exists()) {
        try {
          if (await file.length() > 0) {
            return await file.readAsBytes();
          }
        } catch (_) {}
      }
    }

    final String? remoteUrl = _resolveArtworkUrl(track);
    if (remoteUrl == null || remoteUrl.isEmpty) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(remoteUrl),
        headers: track.httpHeaders ?? const {},
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}

    return null;
  }

  String? _resolveArtworkUrl(Track track) {
    if (track.sourceType == TrackSourceType.netease) {
      final String? cover = track.httpHeaders?['x-netease-cover'];
      if (cover != null && cover.isNotEmpty) {
        return cover;
      }
    }
    return MysteryLibraryConstants.buildArtworkUrl(
          track.httpHeaders,
          thumbnail: false,
        ) ??
        MysteryLibraryConstants.buildArtworkUrl(
          track.httpHeaders,
          thumbnail: true,
        );
  }

  Color _boostGlowColor(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final double lightness = (hsl.lightness + 0.18).clamp(0.28, 0.75);
    final double saturation = (hsl.saturation + 0.12).clamp(0.0, 1.0);
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  }

  void _resetTrackDetailState() {
    _trackDetailContent = null;
    _trackDetailFileName = null;
    _trackDetailError = null;
    _trackDetailLoadedKey = null;
    _isLoadingTrackDetail = false;
    _isSavingTrackDetail = false;
    _showTrackDetailPanel = false;
    _compactLyricsStage = _CompactLyricsStage.cover;
    _trackDetailRequestToken++;
  }

  void _ensureLyricsLoaded(Track track) {
    final currentState = _lyricsCubit.state;
    final bool needsLoad =
        currentState is! LyricsLoaded ||
        currentState.lyrics.trackId != track.id;
    if (needsLoad) {
      unawaited(_lyricsCubit.loadLyricsForTrack(track));
    }
  }

  String _detailCacheKeyForTrack(Track track) {
    return '${track.id}_${track.title}_${track.artist}_${track.album}';
  }

  void _toggleTrackDetailPanel() {
    _setTrackDetailPanelVisibility(!_showTrackDetailPanel);
  }

  void _setTrackDetailPanelVisibility(bool shouldShow) {
    if (!mounted || _showTrackDetailPanel == shouldShow) {
      return;
    }
    setState(() {
      _showTrackDetailPanel = shouldShow;
      if (!shouldShow) {
        _trackDetailError = null;
      }
    });
    if (shouldShow) {
      unawaited(_ensureTrackDetailLoaded());
    }
  }

  void _cycleCompactLyricsStage() {
    if (!mounted) {
      return;
    }
    final stages = _CompactLyricsStage.values;
    final nextIndex = (_compactLyricsStage.index + 1) % stages.length;
    final nextStage = stages[nextIndex];
    setState(() {
      _compactLyricsStage = nextStage;
    });
    final bool shouldShowDetail = nextStage == _CompactLyricsStage.detail;
    _setTrackDetailPanelVisibility(shouldShowDetail);
  }

  Future<void> _ensureTrackDetailLoaded({bool force = false}) async {
    if (!mounted) {
      return;
    }

    final track = _currentTrack;
    final cacheKey = _detailCacheKeyForTrack(track);

    if (!force) {
      final cached = _songDetailService.getCachedDetail(
        title: track.title,
        artist: track.artist,
        album: track.album,
      );
      if (cached != null) {
        setState(() {
          _trackDetailContent = cached.content;
          _trackDetailFileName = cached.fileName;
          _trackDetailLoadedKey = cacheKey;
          _trackDetailError = null;
        });
        return;
      }
    }

    if (!force &&
        _trackDetailLoadedKey == cacheKey &&
        _trackDetailContent != null &&
        !_isLoadingTrackDetail) {
      return;
    }

    final currentRequestId = ++_trackDetailRequestToken;

    if (mounted) {
      setState(() {
        _isLoadingTrackDetail = true;
        if (force) {
          _trackDetailError = null;
        }
      });
    }

    try {
      final result = await _songDetailService.fetchDetail(
        title: track.title,
        artist: track.artist,
        album: track.album,
        forceRefresh: force,
      );

      if (!mounted || currentRequestId != _trackDetailRequestToken) {
        return;
      }

      setState(() {
        _trackDetailContent = result.content;
        _trackDetailFileName = result.fileName;
        _trackDetailLoadedKey = cacheKey;
        _trackDetailError = null;
      });
    } catch (error) {
      if (!mounted || currentRequestId != _trackDetailRequestToken) {
        return;
      }
      setState(() {
        _trackDetailError = error.toString();
      });
    } finally {
      if (!mounted || currentRequestId != _trackDetailRequestToken) {
        return;
      }
      setState(() {
        _isLoadingTrackDetail = false;
      });
    }
  }

  Future<void> _openTrackDetailEditor() async {
    if (!mounted || _isSavingTrackDetail) {
      return;
    }

    final track = _currentTrack;
    final initialText = _trackDetailContent ?? '';
    final controller = TextEditingController(text: initialText);

    final result = await showPlaylistModalDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;
        final l10n = dialogContext.l10n;
        final borderColor = theme.colorScheme.outline.withOpacity(
          isDark ? 0.28 : 0.2,
        );
        final focusedBorderColor = theme.colorScheme.primary.withOpacity(
          isDark ? 0.55 : 0.48,
        );
        final fillColor = isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.74);
        final hintColor = isDark
            ? Colors.white.withOpacity(0.46)
            : Colors.black.withOpacity(0.48);
        final textColor = isDark
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.85);
        final border = OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 0.8),
        );

        return PlaylistModalScaffold(
          title: l10n.songDetailEditDialogTitle,
          maxWidth: 580,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.songDetailEditDialogSubtitle(track.title, track.artist),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.songDetailEditDialogDescription,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 260,
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: l10n.songDetailEditDialogHint,
                    hintStyle:
                        theme.textTheme.bodySmall?.copyWith(
                          color: hintColor,
                          fontSize: 12,
                        ) ??
                        TextStyle(fontSize: 12, color: hintColor),
                    filled: true,
                    fillColor: fillColor,
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border.copyWith(
                      borderSide: BorderSide(
                        color: focusedBorderColor,
                        width: 1.0,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.multiline,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        height: 1.4,
                        fontSize: 13,
                      ) ??
                      TextStyle(color: textColor, height: 1.4, fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            SheetActionButton.secondary(
              label: l10n.actionCancel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            SheetActionButton.primary(
              label: l10n.actionSave,
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    await _saveTrackDetail(result);
  }

  Future<void> _saveTrackDetail(String content) async {
    if (!mounted) {
      return;
    }

    final trimmed = content;
    final track = _currentTrack;
    final cacheKey = _detailCacheKeyForTrack(track);
    final requestId = ++_trackDetailRequestToken;

    setState(() {
      _isSavingTrackDetail = true;
      _trackDetailError = null;
    });

    try {
      final result = await _songDetailService.saveDetail(
        title: track.title,
        artist: track.artist,
        album: track.album,
        content: trimmed,
        existingFileName: _trackDetailFileName,
      );

      if (!mounted || requestId != _trackDetailRequestToken) {
        return;
      }

      setState(() {
        _trackDetailContent = result.content;
        _trackDetailFileName = result.fileName;
        _trackDetailLoadedKey = cacheKey;
        _trackDetailError = null;
      });

      if (mounted) {
        unawaited(
          showPlaylistModalDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) => PlaylistModalScaffold(
              title: dialogContext.l10n.songDetailSaveSuccessTitle,
              maxWidth: 360,
              body: Text(
                result.created
                    ? dialogContext.l10n.songDetailSaveSuccessCreated
                    : dialogContext.l10n.songDetailSaveSuccessUpdated,
              ),
              actions: [
                SheetActionButton.primary(
                  label: dialogContext.l10n.actionOk,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted || requestId != _trackDetailRequestToken) {
        return;
      }

      setState(() {
        _trackDetailError = error.toString();
      });

      if (mounted) {
        unawaited(
          showPlaylistModalDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) => PlaylistModalScaffold(
              title: dialogContext.l10n.songDetailSaveFailureTitle,
              maxWidth: 360,
              body: Text(
                dialogContext.l10n.songDetailSaveFailureMessage(
                  error.toString(),
                ),
              ),
              actions: [
                SheetActionButton.primary(
                  label: dialogContext.l10n.actionClose,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (!mounted || requestId != _trackDetailRequestToken) {
        return;
      }
      setState(() {
        _isSavingTrackDetail = false;
      });
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

  void _toggleLyricsVisibility() {
    if (!mounted) return;
    setState(() {
      _lyricsHidden = !_lyricsHidden;
    });
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

    if (_desktopLyricsVerboseLogging && kDebugMode) {
      debugPrint('桌面歌词payload: ${jsonEncode(update.toJson())}');
    }

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
            unawaited(_showDesktopLyricsError('桌面歌词助手未响应，请确认已运行并允许网络访问。'));
          }
        }
        _shouldResendDesktopUpdate = true;
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

    final formattedActive = _formatLineForDesktop(
      _activeDesktopLine,
      includeTranslation: _showTranslation,
    );
    final formattedNext = _formatLineForDesktop(
      _resolveNextDesktopLine(),
      includeTranslation: _showTranslation,
    );

    String? activeLine = formattedActive ?? _sanitizeLine(_activeDesktopLine);
    activeLine = activeLine?.trim();
    if (activeLine != null && activeLine.isNotEmpty) {
      _lastDesktopActiveText = activeLine;
    } else {
      activeLine = _lastDesktopActiveText;
    }

    String? nextLine =
        formattedNext ?? _sanitizeLine(_resolveNextDesktopLine());
    nextLine = nextLine?.trim();
    if (nextLine != null && nextLine.isEmpty) {
      nextLine = null;
    }

    return DesktopLyricsUpdate(
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      activeLine: activeLine,
      nextLine: nextLine,
      positionMs: _currentPosition?.inMilliseconds,
      isPlaying: _isPlaying,
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

  String? _lineTranslation(LyricsLine? line) {
    final translation = line?.translatedText?.trim();
    if (translation == null || translation.isEmpty) {
      if (line != null) {
        if (_desktopLyricsVerboseLogging && kDebugMode) {
          debugPrint('桌面歌词行缺少翻译: ${line.originalText}');
        }
      }
      return null;
    }
    return translation;
  }

  String? _formatLineForDesktop(
    LyricsLine? line, {
    required bool includeTranslation,
  }) {
    if (line == null) {
      return null;
    }

    final StringBuffer buffer = StringBuffer();
    if (line.annotatedTexts.isNotEmpty) {
      for (final segment in line.annotatedTexts) {
        final original = segment.original;
        if (original.isEmpty) {
          continue;
        }
        final annotation = segment.annotation.trim();
        final bool hasAnnotation =
            annotation.isNotEmpty && annotation != original.trim();

        if (hasAnnotation &&
            _desktopLyricsHanCharacterRegExp.hasMatch(original)) {
          final matches = _desktopLyricsHanCharacterRegExp
              .allMatches(original)
              .toList();
          if (matches.isNotEmpty) {
            final prefix = original.substring(0, matches.first.start);
            final suffix = original.substring(matches.last.end);
            final core = original.substring(
              matches.first.start,
              matches.last.end,
            );

            if (prefix.isNotEmpty) {
              buffer.write(prefix);
            }
            // Limit annotation to Han characters so surrounding symbols stay separate.
            buffer.write('$core[$annotation]');
            if (suffix.isNotEmpty) {
              buffer.write(suffix);
            }
            continue;
          }
        }

        final bool shouldAnnotate =
            hasAnnotation && segment.type != TextType.other;
        if (shouldAnnotate) {
          buffer.write('$original[$annotation]');
        } else {
          buffer.write(original);
        }
      }
    }

    if (buffer.isEmpty) {
      buffer.write(line.originalText);
    }

    String formatted = buffer.toString().trim();
    if (formatted.isEmpty) {
      return null;
    }

    if (includeTranslation) {
      final translation = _lineTranslation(line);
      if (translation != null) {
        if (!formatted.endsWith(' ')) {
          formatted += ' ';
        }
        formatted += '<$translation>';
      }
    }

    formatted = formatted.trim();
    if (_desktopLyricsVerboseLogging && kDebugMode) {
      debugPrint('桌面歌词格式化: $formatted');
    }
    return formatted.isEmpty ? null : formatted;
  }

  Future<void> _toggleDesktopLyricsAssistant() async {
    if (_desktopLyricsBusy) {
      return;
    }
    debugPrint(_desktopLyricsActive ? '准备关闭桌面歌词窗口' : '准备开启桌面歌词窗口');
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
      await _showDesktopLyricsError('桌面歌词服务不可用，请稍后重试。');
      return;
    }

    final shown = await _desktopLyricsBridge.showWindow();
    if (!shown) {
      await _showDesktopLyricsError('无法显示桌面歌词窗口，请检查服务状态。');
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

    unawaited(_desktopLyricsBridge.hideWindow());
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

  void _handlePlayerStateStream(PlayerBlocState state) {
    if (!mounted) {
      return;
    }

    if (identical(state, _lastProcessedPlayerState)) {
      return;
    }
    _lastProcessedPlayerState = state;
    _processPlayerState(state);
  }

  void _processPlayerState(PlayerBlocState playerState) {
    _updatePlaybackStateFromPlayer(playerState);

    final nextTrack = _extractTrack(playerState);
    if (nextTrack != null && nextTrack != _currentTrack) {
      if (mounted) {
        setState(() {
          _currentTrack = nextTrack;
          _resetTrackDetailState();
          _artworkGlowColor = null;
          _trackQualityLabel = _buildQualityLabel(
            bitrate: nextTrack.bitrate,
            sampleRate: nextTrack.sampleRate,
          );
        });
      }
      _ensureLyricsLoaded(nextTrack);
      _loadArtworkGlowColor(nextTrack);
      unawaited(_loadTrackQuality(nextTrack));
      _resetScroll();
      _activeLyricsLines = const [];
      _activeDesktopLine = null;
      _activeDesktopIndex = -1;
      _lastDesktopPayloadSignature = null;
      _resetDesktopLineCache();
      if (_desktopLyricsActive) {
        _scheduleDesktopLyricsUpdate(force: true);
      }
      return;
    }

    if (_desktopLyricsActive) {
      _scheduleDesktopLyricsUpdate();
    }
  }

  void _handleActiveIndexChanged(int index) {
    _activeDesktopIndex = index;
    if (index < 0 || index >= _activeLyricsLines.length) {
      _activeDesktopLine = null;
    } else {
      _activeDesktopLine = _activeLyricsLines[index];
    }
    if (_desktopLyricsVerboseLogging && kDebugMode) {
      debugPrint('桌面歌词当前索引更新: $index');
    }
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

  void _handleLyricsLineTap(LyricsLine line) {
    context.read<PlayerBloc>().add(PlayerSeekTo(line.timestamp));
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
    if (!mounted) {
      return;
    }

    final action = await showPlaylistModalDialog<_ReportErrorAction>(
      context: context,
      builder: (context) => _ReportErrorActionSheet(track: _currentTrack),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _ReportErrorAction.bindNetease:
        await _startNeteaseCorrectionFlow();
        break;
      case _ReportErrorAction.manualLyrics:
        await _openManualCorrectionPage();
        break;
    }
  }

  Future<void> _openManualCorrectionPage() async {
    const url = 'https://nipaplay.aimes-soft.com/lyrics_service.php';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ LyricsOverlay: 打开纠错链接失败 -> $e');
    }

    if (!mounted) {
      return;
    }

    await showPlaylistModalDialog<void>(
      context: context,
      builder: (context) => PlaylistModalScaffold(
        title: '无法打开浏览器',
        body: const Text(
          '请手动访问以下链接完成纠错：\nhttps://nipaplay.aimes-soft.com/lyrics_service.php',
          locale: Locale('zh-Hans', 'zh'),
        ),
        actions: [
          SheetActionButton.primary(
            label: '好的',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        maxWidth: 420,
      ),
    );
  }

  Future<void> _startNeteaseCorrectionFlow() async {
    if (!mounted) {
      return;
    }

    final track = _currentTrack;
    final hash = track.contentHash?.trim();
    if (hash == null || hash.isEmpty) {
      await _showInfoDialog(
        title: '暂无法纠错',
        message: '当前歌曲尚未生成音频指纹，请先完成一次扫描或播放后再试。',
      );
      return;
    }

    final candidate = await showPlaylistModalDialog<NeteaseSongCandidate>(
      context: context,
      builder: (context) =>
          _NeteaseSongSearchSheet(track: track, resolver: _neteaseIdResolver),
    );

    if (!mounted || candidate == null) {
      return;
    }

    try {
      await _neteaseIdResolver.saveMapping(
        track: track,
        neteaseId: candidate.id,
        source: 'manual',
      );
      await _lyricsCubit.loadLyricsForTrack(track, forceRemote: true);
      if (!mounted) {
        return;
      }
      await _showInfoDialog(
        title: '绑定成功',
        message: '已将《${track.title}》绑定为网络歌曲《${candidate.title}》。',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showInfoDialog(title: '保存失败', message: '提交纠错时出现错误：$e');
    }
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) {
      return;
    }

    await showPlaylistModalDialog<void>(
      context: context,
      builder: (context) => PlaylistModalScaffold(
        title: title,
        body: Text(message, locale: const Locale('zh-Hans', 'zh')),
        actions: [
          SheetActionButton.primary(
            label: '确定',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        maxWidth: 420,
      ),
    );
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

    return BlocListener<LyricsCubit, LyricsState>(
      listener: (context, state) {
        if (state is LyricsLoaded || state is LyricsEmpty) {
          _resetScroll();
        }
        if (state is LyricsLoaded) {
          _activeLyricsLines = state.lyrics.lines;
          _activeDesktopIndex = -1;
          _activeDesktopLine = null;
          _lastDesktopPayloadSignature = null;
          _resetDesktopLineCache();
          _syncDesktopLyricsState();
          if (_desktopLyricsActive) {
            _scheduleDesktopLyricsUpdate(force: true);
          }
        } else if (state is LyricsEmpty || state is LyricsError) {
          _activeLyricsLines = const [];
          _activeDesktopLine = null;
          _activeDesktopIndex = -1;
          _lastDesktopPayloadSignature = null;
          _resetDesktopLineCache();
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
        visualStyle: _lyricsStyle,
        lyricsHidden: _lyricsHidden,
        onToggleTranslation: _toggleTranslationVisibility,
        onToggleLyricsVisibility: _toggleLyricsVisibility,
        onDownloadLrc: _downloadLrcFile,
        onReportError: _reportError,
        onToggleDesktopLyrics: () => unawaited(_toggleDesktopLyricsAssistant()),
        isDesktopLyricsActive: _desktopLyricsActive,
        isDesktopLyricsBusy: _desktopLyricsBusy,
        onActiveIndexChanged: _handleActiveIndexChanged,
        onActiveLineChanged: _handleActiveLineChanged,
        onLineTap: _handleLyricsLineTap,
        showTrackDetail: _showTrackDetailPanel,
        isLoadingTrackDetail: _isLoadingTrackDetail,
        isSavingTrackDetail: _isSavingTrackDetail,
        trackDetailContent: _trackDetailContent,
        trackDetailError: _trackDetailError,
        trackDetailFileName: _trackDetailFileName,
        onToggleTrackDetail: _toggleTrackDetailPanel,
        onEditTrackDetail: _openTrackDetailEditor,
        bottomSafeInset: widget.bottomSafeInset,
        artworkGlowColor: _artworkGlowColor,
        trackQualityLabel: _trackQualityLabel,
        compactStage: _compactLyricsStage,
        onCycleCompactStage: _cycleCompactLyricsStage,
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
    required this.visualStyle,
    this.artworkGlowColor,
    required this.lyricsHidden,
    required this.onToggleTranslation,
    required this.onToggleLyricsVisibility,
    required this.onDownloadLrc,
    required this.onReportError,
    required this.onToggleDesktopLyrics,
    required this.isDesktopLyricsActive,
    required this.isDesktopLyricsBusy,
    required this.onActiveIndexChanged,
    required this.onActiveLineChanged,
    required this.onLineTap,
    required this.showTrackDetail,
    required this.isLoadingTrackDetail,
    required this.isSavingTrackDetail,
    required this.trackDetailContent,
    required this.trackDetailError,
    required this.trackDetailFileName,
    required this.onToggleTrackDetail,
    required this.onEditTrackDetail,
    required this.bottomSafeInset,
    required this.trackQualityLabel,
    required this.compactStage,
    required this.onCycleCompactStage,
  });

  final Track track;
  final ScrollController lyricsScrollController;
  final bool isMac;
  final bool showTranslation;
  final LyricsVisualStyle visualStyle;
  final Color? artworkGlowColor;
  final bool lyricsHidden;
  final VoidCallback onToggleTranslation;
  final VoidCallback onToggleLyricsVisibility;
  final VoidCallback onDownloadLrc;
  final VoidCallback onReportError;
  final VoidCallback onToggleDesktopLyrics;
  final bool isDesktopLyricsActive;
  final bool isDesktopLyricsBusy;
  final ValueChanged<int> onActiveIndexChanged;
  final ValueChanged<LyricsLine?> onActiveLineChanged;
  final ValueChanged<LyricsLine> onLineTap;
  final bool showTrackDetail;
  final bool isLoadingTrackDetail;
  final bool isSavingTrackDetail;
  final String? trackDetailContent;
  final String? trackDetailError;
  final String? trackDetailFileName;
  final VoidCallback onToggleTrackDetail;
  final VoidCallback onEditTrackDetail;
  final double bottomSafeInset;
  final String? trackQualityLabel;
  final _CompactLyricsStage compactStage;
  final VoidCallback onCycleCompactStage;

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
          final bool isDarkMode = isMac
              ? MacosTheme.of(context).brightness == Brightness.dark
              : Theme.of(context).brightness == Brightness.dark;
          final bool useCompactLayout = !isMac && constraints.maxWidth < 860;
          final double coverSize = _resolveCoverSize(constraints.maxWidth);

          final Widget lyricsPanel = _LyricsPanel(
            isDarkMode: isDarkMode,
            scrollController: lyricsScrollController,
            track: normalizedTrack,
            showTranslation: showTranslation,
            visualStyle: visualStyle,
            artworkGlowColor: artworkGlowColor,
            lyricsHidden: lyricsHidden,
            onToggleTranslation: onToggleTranslation,
            onToggleLyricsVisibility: onToggleLyricsVisibility,
            onDownloadLrc: onDownloadLrc,
            onReportError: onReportError,
            onToggleDesktopLyrics: onToggleDesktopLyrics,
            isDesktopLyricsActive: isDesktopLyricsActive,
            isDesktopLyricsBusy: isDesktopLyricsBusy,
            onActiveIndexChanged: onActiveIndexChanged,
            onActiveLineChanged: onActiveLineChanged,
            onLineTap: onLineTap,
            bottomSafeInset: bottomSafeInset,
            isCompactLayout: useCompactLayout,
            onTapToggleDetail: useCompactLayout ? onCycleCompactStage : null,
          );

          if (useCompactLayout) {
            final Widget compactCoverPanel = KeyedSubtree(
              key: const ValueKey('compact-cover-panel'),
              child: _CoverColumn(
                track: normalizedTrack,
                coverSize: coverSize,
                isMac: isMac,
                onTap: onCycleCompactStage,
                qualityText: trackQualityLabel,
              ),
            );

            final Widget compactLyricsPanel = KeyedSubtree(
              key: const ValueKey('compact-lyrics-panel'),
              child: lyricsPanel,
            );

            final Widget compactDetailPanel = KeyedSubtree(
              key: const ValueKey('compact-track-detail'),
              child: _TrackDetailView(
                track: normalizedTrack,
                coverSize: coverSize,
                isMac: isMac,
                isLoadingDetail: isLoadingTrackDetail,
                isSavingDetail: isSavingTrackDetail,
                detailContent: trackDetailContent,
                detailError: trackDetailError,
                detailFileName: trackDetailFileName,
                onToggleDetail: onCycleCompactStage,
                onEditDetail: onEditTrackDetail,
                isCompactLayout: true,
                bottomSafeInset: bottomSafeInset,
              ),
            );

            Widget stageChild = compactLyricsPanel;
            switch (compactStage) {
              case _CompactLyricsStage.cover:
                stageChild = compactCoverPanel;
                break;
              case _CompactLyricsStage.lyrics:
                stageChild = compactLyricsPanel;
                break;
              case _CompactLyricsStage.detail:
                stageChild = compactDetailPanel;
                break;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: stageChild,
              ),
            );
          }

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
                  child: _TrackInfoPanel(
                    track: normalizedTrack,
                    coverSize: coverSize,
                    isMac: isMac,
                    showDetail: showTrackDetail,
                    isLoadingDetail: isLoadingTrackDetail,
                    isSavingDetail: isSavingTrackDetail,
                    detailContent: trackDetailContent,
                    detailError: trackDetailError,
                    detailFileName: trackDetailFileName,
                    onToggleDetail: onToggleTrackDetail,
                    onEditDetail: onEditTrackDetail,
                    qualityText: trackQualityLabel,
                    isCompactLayout: false,
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
                Expanded(flex: 13, child: lyricsPanel),
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

class _TrackInfoPanel extends StatelessWidget {
  const _TrackInfoPanel({
    super.key,
    required this.track,
    required this.coverSize,
    required this.isMac,
    required this.showDetail,
    required this.isLoadingDetail,
    required this.isSavingDetail,
    required this.detailContent,
    required this.detailError,
    required this.detailFileName,
    required this.onToggleDetail,
    required this.onEditDetail,
    this.qualityText,
    this.isCompactLayout = false,
  });

  final Track track;
  final double coverSize;
  final bool isMac;
  final bool showDetail;
  final bool isLoadingDetail;
  final bool isSavingDetail;
  final String? detailContent;
  final String? detailError;
  final String? detailFileName;
  final VoidCallback onToggleDetail;
  final VoidCallback onEditDetail;
  final String? qualityText;
  final bool isCompactLayout;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: showDetail
          ? _TrackDetailView(
              key: const ValueKey('track-detail-view'),
              track: track,
              coverSize: coverSize,
              isMac: isMac,
              isLoadingDetail: isLoadingDetail,
              isSavingDetail: isSavingDetail,
              detailContent: detailContent,
              detailError: detailError,
              detailFileName: detailFileName,
              onToggleDetail: onToggleDetail,
              onEditDetail: onEditDetail,
              isCompactLayout: isCompactLayout,
            )
          : _CoverColumn(
              key: const ValueKey('track-cover-view'),
              track: track,
              coverSize: coverSize,
              isMac: isMac,
              onTap: onToggleDetail,
              qualityText: qualityText,
            ),
    );
  }
}

class _CoverColumn extends StatelessWidget {
  const _CoverColumn({
    super.key,
    required this.track,
    required this.coverSize,
    required this.isMac,
    required this.onTap,
    this.qualityText,
  });

  final Track track;
  final double coverSize;
  final bool isMac;
  final VoidCallback onTap;
  final String? qualityText;

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

    final bool isDarkMode = isMac
        ? MacosTheme.of(context).brightness == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;
    final String? qualityText = this.qualityText;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: HoverGlowOverlay(
              isDarkMode: isDarkMode,
              borderRadius: BorderRadius.circular(24),
              glowRadius: 1.05,
              glowOpacity: 0.85,
              blurSigma: 0,
              cursor: SystemMouseCursors.click,
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
                if (qualityText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    qualityText,
                    locale: const Locale("zh-Hans", "zh"),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle.copyWith(
                      fontSize: (subtitleStyle.fontSize ?? 14) - 1,
                      color: subtitleStyle.color?.withOpacity(0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackDetailView extends StatelessWidget {
  const _TrackDetailView({
    super.key,
    required this.track,
    required this.coverSize,
    required this.isMac,
    required this.isLoadingDetail,
    required this.isSavingDetail,
    required this.detailContent,
    required this.detailError,
    required this.detailFileName,
    required this.onToggleDetail,
    required this.onEditDetail,
    this.isCompactLayout = false,
    this.bottomSafeInset = 0,
  });

  final Track track;
  final double coverSize;
  final bool isMac;
  final bool isLoadingDetail;
  final bool isSavingDetail;
  final String? detailContent;
  final String? detailError;
  final String? detailFileName;
  final VoidCallback onToggleDetail;
  final VoidCallback onEditDetail;
  final bool isCompactLayout;
  final double bottomSafeInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final macTheme = isMac ? MacosTheme.of(context) : null;
        final isDarkMode = isMac
            ? macTheme!.brightness == Brightness.dark
            : theme.brightness == Brightness.dark;
        final l10n = context.l10n;

        final displayWidth = math
            .min(560.0, coverSize * 1.38)
            .clamp(320.0, 620.0);
        final panelHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : math.max(coverSize * 1.05, 420.0);
        final TextStyle headerStyle = isMac
            ? macTheme!.typography.title3.copyWith(fontWeight: FontWeight.w600)
            : theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ) ??
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

        final TextStyle bodyStyle = isMac
            ? macTheme!.typography.body
            : theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
        final Color baseBodyColor =
            bodyStyle.color ?? (isDarkMode ? Colors.white : Colors.black);
        final Color detailTextColor = baseBodyColor.withOpacity(
          isDarkMode ? 0.78 : 0.72,
        );
        final TextStyle metaStyle = bodyStyle.copyWith(
          fontSize: (bodyStyle.fontSize ?? 14) - 1,
          color:
              bodyStyle.color?.withOpacity(0.68) ??
              (isDarkMode
                  ? Colors.white.withOpacity(0.68)
                  : Colors.black.withOpacity(0.62)),
        );

        final String? trimmedError = detailError?.trim();
        final bool hasErrorText =
            trimmedError != null && trimmedError.isNotEmpty;
        final String trimmedContent = detailContent?.trim() ?? '';
        final TextStyle detailTextStyle = bodyStyle.copyWith(
          height: 1.48,
          color: detailTextColor,
        );
        final Color detailDividerColor =
            (isDarkMode ? Colors.white : Colors.black).withOpacity(
              isDarkMode ? 0.18 : 0.12,
            );
        final Color detailSurfaceColor =
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.04);

        if (isLoadingDetail) {
          return Center(
            child: isMac
                ? const ProgressCircle(radius: 16)
                : const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
          );
        }

        Widget detailBody;
        if (hasErrorText) {
          detailBody = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_circle,
                    size: 20,
                    color: isDarkMode
                        ? Colors.orangeAccent.withOpacity(0.9)
                        : Colors.orange.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.songDetailLoadErrorTitle,
                    style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                trimmedError!,
                locale: const Locale('zh-Hans', 'zh'),
                style: bodyStyle.copyWith(
                  fontSize: (bodyStyle.fontSize ?? 14) - 1,
                  color:
                      bodyStyle.color?.withOpacity(0.72) ??
                      (isDarkMode
                          ? Colors.white.withOpacity(0.72)
                          : Colors.black.withOpacity(0.68)),
                ),
              ),
            ],
          );
        } else if (trimmedContent.isEmpty) {
          detailBody = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.songDetailEmptyTitle,
                style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(l10n.songDetailEmptyDescription, style: metaStyle),
            ],
          );
        } else {
          final double baseFontSize = bodyStyle.fontSize ?? 14;
          final MarkdownStyleSheet
          markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: detailTextStyle,
            h1: detailTextStyle.copyWith(
              fontSize: baseFontSize + 10,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            h2: detailTextStyle.copyWith(
              fontSize: baseFontSize + 7,
              fontWeight: FontWeight.w700,
              height: 1.22,
            ),
            h3: detailTextStyle.copyWith(
              fontSize: baseFontSize + 4,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            h4: detailTextStyle.copyWith(
              fontSize: baseFontSize + 2,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
            h5: detailTextStyle.copyWith(
              fontSize: baseFontSize + 1,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
            h6: detailTextStyle.copyWith(
              fontSize: baseFontSize,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
            strong: detailTextStyle.copyWith(fontWeight: FontWeight.w700),
            em: detailTextStyle.copyWith(fontStyle: FontStyle.italic),
            listBullet: detailTextStyle,
            listIndent: 26,
            blockquote: detailTextStyle.copyWith(
              color: detailTextColor.withOpacity(isDarkMode ? 0.9 : 0.82),
            ),
            blockquoteDecoration: BoxDecoration(
              color: detailSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: detailDividerColor, width: 3),
              ),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(top: BorderSide(color: detailDividerColor)),
            ),
            code: detailTextStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: detailSurfaceColor,
            ),
            codeblockPadding: const EdgeInsets.all(12),
            codeblockDecoration: BoxDecoration(
              color: detailSurfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: detailDividerColor),
            ),
            tableHead: detailTextStyle.copyWith(fontWeight: FontWeight.w600),
            tableBody: detailTextStyle,
            tableBorder: TableBorder.all(color: detailDividerColor, width: 0.6),
          );
          detailBody = MarkdownBody(
            data: trimmedContent,
            styleSheet: markdownStyle,
            softLineBreak: true,
            onTapLink: (text, href, title) async {
              if (href == null) {
                return;
              }
              final Uri? uri = Uri.tryParse(href);
              if (uri == null) {
                return;
              }
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (error, stackTrace) {
                debugPrint('歌曲详情链接打开失败: $error\n$stackTrace');
              }
            },
          );
        }

        final Widget editLink = MouseRegion(
          cursor: isSavingDetail
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isSavingDetail ? null : onEditDetail,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(
                isSavingDetail
                    ? l10n.songDetailSavingLabel
                    : l10n.songDetailEditButton,
                style: bodyStyle.copyWith(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                  color:
                      bodyStyle.color ??
                      (isDarkMode
                          ? Colors.white.withOpacity(
                              isSavingDetail ? 0.5 : 0.82,
                            )
                          : Colors.black.withOpacity(
                              isSavingDetail ? 0.5 : 0.78,
                            )),
                ),
              ),
            ),
          ),
        );

        final double scrollVerticalPadding = isCompactLayout ? 0 : 22;
        final double leadingSpacer = isCompactLayout ? 120 : 18;
        final double trailingSpacer = isCompactLayout
            ? (bottomSafeInset + 24)
            : 0;

        List<Widget> buildDetailChildren(Widget detailSection) {
          return [
            SizedBox(height: leadingSpacer),
            Text(track.title, style: headerStyle.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text('${track.artist} · ${track.album}', style: metaStyle),
            const SizedBox(height: 22),
            Text(
              l10n.songDetailSectionTitle,
              style: bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    bodyStyle.color?.withOpacity(0.82) ??
                    (isDarkMode
                        ? Colors.white.withOpacity(0.82)
                        : Colors.black.withOpacity(0.78)),
              ),
            ),
            const SizedBox(height: 16),
            detailSection,
            if (!isSavingDetail)
              Align(alignment: Alignment.centerLeft, child: editLink),
            SizedBox(height: trailingSpacer),
          ];
        }

        Widget buildCompactDetailBody() {
          final ScrollBehavior innerBehavior = ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false);
          final Color surfaceColor = isDarkMode
              ? Colors.white.withOpacity(0.035)
              : Colors.black.withOpacity(0.035);

          Widget buildScrollableDetail() {
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: BoxDecoration(color: surfaceColor),
                child: ScrollConfiguration(
                  behavior: innerBehavior,
                  child: Scrollbar(
                    thumbVisibility: false,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
                      child: detailBody,
                    ),
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 0,
              vertical: scrollVerticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: leadingSpacer),
                Text(track.title, style: headerStyle.copyWith(fontSize: 18)),
                const SizedBox(height: 6),
                Text('${track.artist} · ${track.album}', style: metaStyle),
                const SizedBox(height: 22),
                Text(
                  l10n.songDetailSectionTitle,
                  style: bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        bodyStyle.color?.withOpacity(0.82) ??
                        (isDarkMode
                            ? Colors.white.withOpacity(0.82)
                            : Colors.black.withOpacity(0.78)),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: buildScrollableDetail()),
                if (!isSavingDetail)
                  Align(alignment: Alignment.centerLeft, child: editLink),
                SizedBox(height: trailingSpacer),
              ],
            ),
          );
        }

        Widget buildDefaultDetailBody() {
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 0,
                vertical: scrollVerticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: buildDetailChildren(detailBody),
              ),
            ),
          );
        }

        final Widget detailContentWidget = isCompactLayout
            ? buildCompactDetailBody()
            : buildDefaultDetailBody();

        return Align(
          alignment: isCompactLayout ? Alignment.center : Alignment.centerRight,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleDetail,
              child: SizedBox(
                width: isCompactLayout ? double.infinity : displayWidth,
                height: panelHeight,
                child: detailContentWidget,
              ),
            ),
          ),
        );
      },
    );
  }
}

const double _kLyricsPanelButtonSpacing = 12.0;
const double _kLyricsPanelCompactButtonSpacing = 12.0;
const double _kLyricsPanelTopSpacing = 12.0;
const double _kLyricsPanelCompactTopSpacing = 12.0;
const double _kLyricsPanelBaseBottomInset = 12.0;
const double _kLyricsPanelCompactBaseBottomInset = 12.0;
const double _kLyricsPanelRightInset = 0.0;
const double _kLyricsPanelCompactRightInset = 0.0;
const double _kLyricsPanelButtonRightPadding = 12.0;
const double _kLyricsPanelCompactButtonRightPadding = 0.0;

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({
    required this.isDarkMode,
    required this.scrollController,
    required this.track,
    required this.showTranslation,
    required this.visualStyle,
    this.artworkGlowColor,
    required this.lyricsHidden,
    required this.onToggleTranslation,
    required this.onToggleLyricsVisibility,
    required this.onDownloadLrc,
    required this.onReportError,
    required this.onToggleDesktopLyrics,
    required this.isDesktopLyricsActive,
    required this.isDesktopLyricsBusy,
    required this.onActiveIndexChanged,
    required this.onActiveLineChanged,
    required this.onLineTap,
    required this.bottomSafeInset,
    this.isCompactLayout = false,
    this.onTapToggleDetail,
  });

  final bool isDarkMode;
  final ScrollController scrollController;
  final Track track;
  final bool showTranslation;
  final LyricsVisualStyle visualStyle;
  final Color? artworkGlowColor;
  final bool lyricsHidden;
  final VoidCallback onToggleTranslation;
  final VoidCallback onToggleLyricsVisibility;
  final VoidCallback onDownloadLrc;
  final VoidCallback onReportError;
  final VoidCallback onToggleDesktopLyrics;
  final bool isDesktopLyricsActive;
  final bool isDesktopLyricsBusy;
  final ValueChanged<int> onActiveIndexChanged;
  final ValueChanged<LyricsLine?> onActiveLineChanged;
  final ValueChanged<LyricsLine> onLineTap;
  final double bottomSafeInset;
  final bool isCompactLayout;
  final VoidCallback? onTapToggleDetail;

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = isCompactLayout ? 0 : 24;
    final double buttonSpacing = isCompactLayout
        ? _kLyricsPanelCompactButtonSpacing
        : _kLyricsPanelButtonSpacing;
    final double topSpacing = isCompactLayout
        ? _kLyricsPanelCompactTopSpacing
        : _kLyricsPanelTopSpacing;
    final double bottomInset =
        bottomSafeInset +
        (isCompactLayout
            ? _kLyricsPanelCompactBaseBottomInset
            : _kLyricsPanelBaseBottomInset);
    final double rightInset = isCompactLayout
        ? _kLyricsPanelCompactRightInset
        : _kLyricsPanelRightInset;
    final double floatingButtonsRightPadding = isCompactLayout
        ? _kLyricsPanelCompactButtonRightPadding
        : _kLyricsPanelButtonRightPadding;
    final double floatingButtonsRight =
        rightInset + floatingButtonsRightPadding - horizontalPadding;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final behavior = ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false);
          final viewportHeight = constraints.maxHeight;
          return BlocBuilder<LyricsCubit, LyricsState>(
            builder: (context, state) {
              Widget content = ScrollConfiguration(
                behavior: behavior,
                child: _buildLyricsContent(
                  context,
                  state,
                  scrollController,
                  isDarkMode,
                  viewportHeight,
                  showTranslation,
                  lyricsHidden,
                ),
              );

              if (onTapToggleDetail != null) {
                content = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTapToggleDetail,
                  child: content,
                );
              }

              final bool canToggle =
                  state is LyricsLoaded && _hasAnyTranslation(state.lyrics);
              final bool showDesktopLyricsButton = !isMobilePlatform(
                Theme.of(context).platform,
              );
              final bool canDownload = state is LyricsLoaded;

              final List<Widget> floatingButtons = [
                _LyricsVisibilityButton(
                  isDarkMode: isDarkMode,
                  isHidden: lyricsHidden,
                  onPressed: onToggleLyricsVisibility,
                ),
                SizedBox(height: buttonSpacing),
                _TranslationToggleButton(
                  isDarkMode: isDarkMode,
                  isActive: showTranslation,
                  isEnabled: canToggle,
                  onPressed: canToggle ? onToggleTranslation : null,
                ),
                SizedBox(height: buttonSpacing),
                if (showDesktopLyricsButton) ...[
                  _DesktopLyricsToggleButton(
                    isDarkMode: isDarkMode,
                    isActive: isDesktopLyricsActive,
                    isBusy: isDesktopLyricsBusy,
                    onPressed: onToggleDesktopLyrics,
                  ),
                  SizedBox(height: buttonSpacing),
                ],
                _DownloadLrcButton(
                  isDarkMode: isDarkMode,
                  isEnabled: canDownload,
                  onPressed: canDownload ? onDownloadLrc : null,
                ),
                SizedBox(height: topSpacing),
                _ReportErrorButton(
                  isDarkMode: isDarkMode,
                  onPressed: onReportError,
                ),
              ];

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: content),
                  Positioned(
                    bottom: bottomInset,
                    right: floatingButtonsRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      verticalDirection: VerticalDirection.up,
                      children: floatingButtons,
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
    bool lyricsHidden,
  ) {
    if (lyricsHidden) {
      return _buildInfoMessage(
        controller,
        title: '歌词已关闭',
        subtitle: '点击右下角按钮重新显示歌词。',
        isDarkMode: isDarkMode,
        viewportHeight: viewportHeight,
      );
    }

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
        onLineTap: onLineTap,
        visualStyle: visualStyle,
        glowColor: artworkGlowColor,
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

class _LyricsVisibilityButton extends StatelessWidget {
  const _LyricsVisibilityButton({
    required this.isDarkMode,
    required this.isHidden,
    required this.onPressed,
  });

  final bool isDarkMode;
  final bool isHidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isDarkMode ? Colors.white : Colors.black;
    final Color inactiveColor = iconColor.withOpacity(0.82);
    final Color activeColor = iconColor;
    final Color disabledColor = iconColor.withOpacity(0.42);
    final IconData icon = isHidden
        ? CupertinoIcons.eye
        : CupertinoIcons.eye_slash;
    final String tooltip = isHidden ? '显示歌词' : '关闭歌词';
    final Color baseColor = isHidden ? activeColor : inactiveColor;

    return MacosTooltip(
      message: tooltip,
      child: _HoverGlyphButton(
        enabled: true,
        onPressed: onPressed,
        icon: icon,
        size: 25,
        baseColor: baseColor,
        hoverColor: activeColor,
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
    final Color disabledColor = iconColor.withOpacity(0.42);
    final Color inactiveBase = iconColor.withOpacity(0.82);
    final Color activeBase = iconColor;
    final Color hoverInactive = iconColor;
    final Color hoverActive = iconColor;
    final Color baseColor = enabled
        ? (isActive ? activeBase : inactiveBase)
        : disabledColor;
    final Color hoverColor = enabled
        ? (isActive ? hoverActive : hoverInactive)
        : disabledColor;
    final String tooltip = isBusy
        ? '处理中...'
        : (isActive ? '关闭桌面歌词窗口' : '显示桌面歌词窗口');
    final String assetPath = enabled
        ? (isActive ? 'icons/text.png' : 'icons/text2.png')
        : 'icons/text2.png';

    return MacosTooltip(
      message: tooltip,
      child: _HoverGlyphButton(
        enabled: enabled,
        onPressed: enabled ? onPressed : null,
        assetPath: assetPath,
        size: 26,
        baseColor: baseColor,
        hoverColor: hoverColor,
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

enum _ReportErrorAction { bindNetease, manualLyrics }

class _ReportErrorActionSheet extends StatelessWidget {
  const _ReportErrorActionSheet({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
    );

    return PlaylistModalScaffold(
      title: '纠错网络 ID',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('当前歌曲：${track.title}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          _ReportActionTile(
            icon: CupertinoIcons.search,
            title: '从网络搜索绑定',
            description: '搜索网络歌曲并绑定正确的歌词/封面 ID。',
            onTap: () =>
                Navigator.of(context).pop(_ReportErrorAction.bindNetease),
          ),
          const SizedBox(height: 12),
          _ReportActionTile(
            icon: CupertinoIcons.link,
            title: '手动填写歌词页面',
            description: '打开云歌词页面，直接上传或编辑歌词内容。',
            onTap: () =>
                Navigator.of(context).pop(_ReportErrorAction.manualLyrics),
          ),
          const SizedBox(height: 12),
          Text('提示：绑定后会同步保存到云端，其他设备也会使用该网络 ID。', style: subtitleStyle),
        ],
      ),
      actions: [
        SheetActionButton.secondary(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      maxWidth: 420,
    );
  }
}

class _ReportActionTile extends StatefulWidget {
  const _ReportActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  State<_ReportActionTile> createState() => _ReportActionTileState();
}

class _ReportActionTileState extends State<_ReportActionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = _hovering
        ? theme.colorScheme.primary.withOpacity(0.12)
        : theme.colorScheme.surface.withOpacity(0.4);
    final borderColor = theme.colorScheme.outline.withOpacity(0.18);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 24, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(widget.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeteaseSongSearchSheet extends StatefulWidget {
  const _NeteaseSongSearchSheet({required this.track, required this.resolver});

  final Track track;
  final NeteaseIdResolver resolver;

  @override
  State<_NeteaseSongSearchSheet> createState() =>
      _NeteaseSongSearchSheetState();
}

class _NeteaseSongSearchSheetState extends State<_NeteaseSongSearchSheet> {
  late final TextEditingController _queryController;
  bool _includeArtist = true;
  bool _loading = false;
  List<NeteaseSongCandidate> _results = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.track.title);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _performSearch();
      }
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final keyword = _queryController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = const [];
        _message = '请输入歌曲名称后再搜索';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final artist = widget.track.artist.trim();
    final normalizedArtist =
        !_includeArtist ||
            artist.isEmpty ||
            artist.toLowerCase() == 'unknown artist'
        ? null
        : artist;

    final results = await widget.resolver.searchCandidates(
      keyword: keyword,
      artist: normalizedArtist,
      limit: 20,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _results = results;
      _message = results.isEmpty ? '未找到匹配结果，请尝试调整关键词。' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withOpacity(0.85),
    );

    return PlaylistModalScaffold(
      title: '从网络选择歌曲',
      body: SizedBox(
        width: double.infinity,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '当前歌曲：${widget.track.title} - ${widget.track.artist}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    controller: _queryController,
                    onSubmitted: (_) => _performSearch(),
                    placeholder: '输入关键词搜索网络歌曲',
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton.filled(
                  onPressed: _loading ? null : _performSearch,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: _loading
                      ? const CupertinoActivityIndicator(radius: 10)
                      : const Text('搜索'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CupertinoSwitch(
                  value: _includeArtist,
                  onChanged: (value) {
                    setState(() => _includeArtist = value);
                    _performSearch();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('匹配时包含歌手名称，以提高准确度', style: subtitleStyle)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _buildResultList(theme),
            ),
          ],
        ),
      ),
      actions: [
        SheetActionButton.secondary(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      maxWidth: 560,
    );
  }

  Widget _buildResultList(ThemeData theme) {
    if (_message != null) {
      return Center(child: Text(_message!, style: theme.textTheme.bodyMedium));
    }

    if (_results.isEmpty) {
      return Center(child: Text('暂无匹配结果', style: theme.textTheme.bodyMedium));
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final candidate = _results[index];
        return _NeteaseCandidateTile(
          candidate: candidate,
          onTap: () => Navigator.of(context).pop(candidate),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: _results.length,
    );
  }
}

class _NeteaseCandidateTile extends StatelessWidget {
  const _NeteaseCandidateTile({required this.candidate, required this.onTap});

  final NeteaseSongCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withOpacity(0.2);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    candidate.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(candidate.durationLabel, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(candidate.displayArtists, style: theme.textTheme.bodyMedium),
            if (candidate.album.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('专辑：${candidate.album}', style: subtitleStyle),
            ],
            if (candidate.aliasLabel != null &&
                candidate.aliasLabel!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('别名：${candidate.aliasLabel}', style: subtitleStyle),
              ),
          ],
        ),
      ),
    );
  }
}
