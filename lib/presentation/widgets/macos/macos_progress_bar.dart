import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../blocs/player/player_bloc.dart';

class MacOSProgressBar extends StatefulWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final Color primaryColor;
  final Color secondaryColor;
  final ValueChanged<bool>? onHoverChanged;

  const MacOSProgressBar({
    super.key,
    required this.progress,
    required this.position,
    required this.duration,
    required this.primaryColor,
    required this.secondaryColor,
    this.onHoverChanged,
  });

  @override
  State<MacOSProgressBar> createState() => _MacOSProgressBarState();
}

class _MacOSProgressBarState extends State<MacOSProgressBar> {
  static const _transitionDuration = Duration(milliseconds: 200);
  static const _trackHeight = 2.0;
  static const _knobDiameter = 10.0;
  static const _timeLabelWidth = 48.0;
  static const _timeGap = -5.0;
  static const double _timeVerticalOffset = 0.3;

  bool _isHovering = false;
  bool _isDragging = false;

  double get _clampedProgress => widget.progress.clamp(0.0, 1.0).toDouble();

  void _updateHovering(bool value) {
    if (_isHovering == value) {
      return;
    }

    setState(() {
      _isHovering = value;
    });
    widget.onHoverChanged?.call(_isHovering);
  }

  void _seekToRelative(double relative) {
    final durationInMs = widget.duration.inMilliseconds;
    if (durationInMs <= 0) {
      return;
    }

    final clampedRelative = relative.clamp(0.0, 1.0).toDouble();
    final newPosition = Duration(
      milliseconds: (durationInMs * clampedRelative).round(),
    );
    context.read<PlayerBloc>().add(PlayerSeekTo(newPosition));
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _updateHovering(true),
      onExit: (_) => _updateHovering(false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 0.0;
          final knobRadius = _knobDiameter / 2;
          final knobCenter = trackWidth * _clampedProgress;
          final maxLeft = math.max(0.0, trackWidth - _knobDiameter);
          final knobLeft = (knobCenter - knobRadius).clamp(0.0, maxLeft);
          final showKnob = _isHovering || _isDragging;

          void handleEvent(Offset localPosition) {
            if (trackWidth <= 0) {
              return;
            }
            final clampedDx = localPosition.dx.clamp(0.0, trackWidth) as double;
            _seekToRelative(clampedDx / trackWidth);
          }

          final theme = MacosTheme.of(context);
          final showTimes = _isHovering || _isDragging;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) => handleEvent(details.localPosition),
            onHorizontalDragStart: (details) {
              setState(() => _isDragging = true);
              handleEvent(details.localPosition);
            },
            onHorizontalDragUpdate: (details) =>
                handleEvent(details.localPosition),
            onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
            onHorizontalDragCancel: () => setState(() => _isDragging = false),
            child: SizedBox(
              height: _knobDiameter,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildTrack(trackWidth),
                  ),
                  Positioned(
                    left: knobLeft,
                    top: 0,
                    child: IgnorePointer(
                      ignoring: !showKnob,
                      child: AnimatedOpacity(
                        duration: _transitionDuration,
                        curve: Curves.easeInOut,
                        opacity: showKnob ? 1.0 : 0.0,
                        child: AnimatedScale(
                          duration: _transitionDuration,
                          curve: Curves.easeInOut,
                          scale: showKnob ? 1.0 : 0.8,
                          child: _buildKnob(),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedOpacity(
                      duration: _transitionDuration,
                      curve: Curves.easeInOut,
                      opacity: showTimes ? 1.0 : 0.0,
                      child: _buildTimeLabels(theme),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrack(double width) {
    final barRadius = BorderRadius.circular(_trackHeight / 2);
    final filledWidth = width * _clampedProgress;

    return SizedBox(
      width: width,
      height: _trackHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.secondaryColor.withOpacity(0.3),
          borderRadius: barRadius,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: _trackHeight,
            width: filledWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.primaryColor,
                borderRadius: barRadius,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKnob() {
    final theme = MacosTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: _knobDiameter,
      height: _knobDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.primaryColor,
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black26,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDarkMode
              ? MacosColors.controlBackgroundColor
              : Colors.black.withOpacity(0.12),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildTimeLabels(MacosThemeData theme) {
    final textStyle = theme.typography.caption1.copyWith(
      fontSize: 10,
      color: widget.secondaryColor,
      height: 1.0,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_timeLabelWidth - _timeGap,
          top: 0,
          bottom: 0,
          child: SizedBox(
            width: _timeLabelWidth,
            height: _knobDiameter,
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, _timeVerticalOffset),
                child: Text(
                  _formatDuration(widget.position),
                  textAlign: TextAlign.right,
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -_timeLabelWidth - _timeGap,
          top: 0,
          bottom: 0,
          child: SizedBox(
            width: _timeLabelWidth,
            height: _knobDiameter,
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, _timeVerticalOffset),
                child: Text(
                  _formatDuration(widget.duration),
                  textAlign: TextAlign.left,
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
