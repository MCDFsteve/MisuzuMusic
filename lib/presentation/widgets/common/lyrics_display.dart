import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/player/player_bloc.dart';
import '../../../domain/entities/lyrics_entities.dart';

class LyricsDisplay extends StatefulWidget {
  const LyricsDisplay({
    super.key,
    required this.lines,
    required this.controller,
    required this.isDarkMode,
  });

  final List<LyricsLine> lines;
  final ScrollController controller;
  final bool isDarkMode;

  @override
  State<LyricsDisplay> createState() => _LyricsDisplayState();
}

class _LyricsDisplayState extends State<LyricsDisplay> {
  int _activeIndex = -1;
  late List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = _generateKeys(widget.lines.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<PlayerBloc>().state;
      final position = _positionFromState(state);
      if (position != null) {
        _updateActiveIndex(position);
      }
    });
  }

  @override
  void didUpdateWidget(covariant LyricsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.length != widget.lines.length) {
      _itemKeys = _generateKeys(widget.lines.length);
    }
  }

  List<GlobalKey> _generateKeys(int length) {
    return List<GlobalKey>.generate(length, (_) => GlobalKey());
  }

  Duration? _positionFromState(PlayerBlocState state) {
    if (state is PlayerPlaying) {
      return state.position;
    }
    if (state is PlayerPaused) {
      return state.position;
    }
    if (state is PlayerLoading) {
      return state.position;
    }
    return null;
  }

  void _updateActiveIndex(Duration position) {
    final lines = widget.lines;
    if (lines.isEmpty) {
      return;
    }

    int index = 0;
    for (int i = 0; i < lines.length; i++) {
      final current = lines[i].timestamp;
      final next = i + 1 < lines.length ? lines[i + 1].timestamp : null;
      if (position < current) {
        index = math.max(0, i - 1);
        break;
      }
      if (next == null || position < next) {
        index = i;
        break;
      }
    }

    if (index != _activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _activeIndex = index;
        });
        _scrollToIndex(index);
      });
    }
  }

  void _scrollToIndex(int index) {
    if (!widget.controller.hasClients) {
      return;
    }
    if (index < 0 || index >= _itemKeys.length) {
      return;
    }

    final context = _itemKeys[index].currentContext;
    if (context == null) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      alignment: 0.45,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutQuad,
    );
  }

  TextStyle _inactiveTextStyle(bool isActive) {
    final baseColor = widget.isDarkMode ? Colors.white70 : Colors.black54;
    return TextStyle(
      fontSize: isActive ? 22 : 15,
      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      color: isActive
          ? (widget.isDarkMode ? Colors.white : Colors.black87)
          : baseColor,
      height: 1.6,
    );
  }

  String _lineText(LyricsLine line) {
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

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return BlocListener<PlayerBloc, PlayerBlocState>(
      listener: (context, state) {
        final position = _positionFromState(state);
        if (position != null) {
          _updateActiveIndex(position);
        }
      },
      child: ListView.builder(
        controller: widget.controller,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 4),
        itemCount: widget.lines.length,
        itemBuilder: (context, index) {
          final line = widget.lines[index];
          final isActive = index == _activeIndex;
          final text = _lineText(line);

          return AnimatedDefaultTextStyle(
            key: _itemKeys[index],
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            style: _inactiveTextStyle(isActive),
            textAlign: TextAlign.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Text(
                text.isEmpty ? ' ' : text,
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
