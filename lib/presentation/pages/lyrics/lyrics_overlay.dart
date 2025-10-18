import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../domain/entities/lyrics_entities.dart';
import '../../../domain/entities/music_entities.dart';
import '../../../domain/usecases/lyrics_usecases.dart';
import '../../blocs/lyrics/lyrics_cubit.dart';
import '../../blocs/player/player_bloc.dart';
import '../../widgets/common/adaptive_scrollbar.dart';
import '../../widgets/common/artwork_thumbnail.dart';

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

  @override
  void initState() {
    super.initState();
    _currentTrack = widget.initialTrack;
    _lyricsScrollController = ScrollController();
    _lyricsCubit = LyricsCubit(getLyrics: sl<GetLyrics>())
      ..loadLyricsForTrack(_currentTrack);
  }

  @override
  void didUpdateWidget(covariant LyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTrack.id != oldWidget.initialTrack.id) {
      _currentTrack = widget.initialTrack;
      _lyricsCubit.loadLyricsForTrack(_currentTrack);
      _resetScroll();
    }
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    _lyricsCubit.close();
    super.dispose();
  }

  void _resetScroll() {
    if (_lyricsScrollController.hasClients) {
      _lyricsScrollController.jumpTo(0);
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
          final nextTrack = _extractTrack(playerState);
          if (nextTrack != null && nextTrack.id != _currentTrack.id) {
            if (!mounted) return;
            setState(() => _currentTrack = nextTrack);
            _lyricsCubit.loadLyricsForTrack(nextTrack);
            _resetScroll();
          }
        },
        child: BlocListener<LyricsCubit, LyricsState>(
          listener: (context, state) {
            if (state is LyricsLoaded || state is LyricsEmpty) {
              _resetScroll();
            }
          },
          child: _LyricsLayout(
            track: _currentTrack,
            lyricsScrollController: _lyricsScrollController,
            isMac: isMac,
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
  });

  final Track track;
  final ScrollController lyricsScrollController;
  final bool isMac;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets contentPadding = isMac
        ? const EdgeInsets.fromLTRB(32, 32, 32, 32)
        : const EdgeInsets.fromLTRB(20, 24, 20, 24);

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
                    track: track,
                    coverSize: coverSize,
                    isMac: isMac,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  color: dividerColor.withOpacity(0.35),
                ),
                Expanded(
                  flex: 13,
                  child: _LyricsPanel(
                    isDarkMode: isDarkMode,
                    scrollController: lyricsScrollController,
                    track: track,
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
        ? MacosTheme.of(context).typography.title1.copyWith(fontWeight: FontWeight.w600)
        : Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600) ??
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    final TextStyle subtitleStyle = isMac
        ? MacosTheme.of(context).typography.body.copyWith(
              color: MacosTheme.of(context).typography.body.color?.withOpacity(0.75),
            )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ) ??
            const TextStyle(fontSize: 14, color: Colors.black54);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ArtworkThumbnail(
            artworkPath: track.artworkPath,
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
          const SizedBox(height: 24),
          SizedBox(
            width: math.min(480, coverSize * 1.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  track.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  '${track.artist} · ${track.album}',
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
  });

  final bool isDarkMode;
  final ScrollController scrollController;
  final Track track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: BlocBuilder<LyricsCubit, LyricsState>(
        builder: (context, state) {
          return AdaptiveScrollbar(
            isDarkMode: isDarkMode,
            controller: scrollController,
            margin: const EdgeInsets.only(right: 4),
            builder: (controller) => _buildLyricsContent(
              context,
              state,
              controller,
              isDarkMode,
            ),
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
  ) {
    final TextStyle baseStyle = TextStyle(
      fontSize: 18,
      height: 1.5,
      color: isDarkMode ? Colors.white : Colors.black87,
    );

    if (state is LyricsLoading || state is LyricsInitial) {
      return ListView(
        controller: controller,
        children: const [
          SizedBox(height: 80),
          Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }

    if (state is LyricsError) {
      return _buildInfoMessage(
        controller,
        title: '歌词加载失败',
        subtitle: state.message,
        isDarkMode: isDarkMode,
      );
    }

    if (state is LyricsEmpty) {
      return _buildInfoMessage(
        controller,
        title: '暂无歌词',
        subtitle: '暂未找到 ${track.title} 的歌词。',
        isDarkMode: isDarkMode,
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
        );
      }

      return ListView.separated(
        controller: controller,
        itemCount: lines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final LyricsLine line = lines[index];
          final String text = _resolveLineText(line);
          return Text(
            text.isEmpty ? ' ' : text,
            style: baseStyle,
            textAlign: TextAlign.left,
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInfoMessage(
    ScrollController controller, {
    required String title,
    required String subtitle,
    required bool isDarkMode,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const double contentEstimate = 72;
        final double verticalPadding = math.max(
          0,
          (constraints.maxHeight - contentEstimate) * 0.5,
        );

        return ListView(
          controller: controller,
          padding: EdgeInsets.only(top: verticalPadding, bottom: verticalPadding),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: titleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: subtitleStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _resolveLineText(LyricsLine line) {
    if (line.originalText.trim().isNotEmpty) {
      return line.originalText.trim();
    }
    if (line.annotatedTexts.isNotEmpty) {
      final buffer = StringBuffer();
      for (final annotated in line.annotatedTexts) {
        buffer.write(annotated.original);
      }
      return buffer.toString();
    }
    return '';
  }
}
