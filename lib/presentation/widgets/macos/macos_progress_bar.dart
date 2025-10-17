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

  const MacOSProgressBar({
    super.key,
    required this.progress,
    required this.position,
    required this.duration,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<MacOSProgressBar> createState() => _MacOSProgressBarState();
}

class _MacOSProgressBarState extends State<MacOSProgressBar> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: _isHovering ? _buildDetailedProgressBar() : _buildSimpleProgressBar(),
      ),
    );
  }

  Widget _buildSimpleProgressBar() {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: widget.secondaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(1.5),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widget.progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: widget.primaryColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // 可交互的进度条
          MacosSlider(
            value: widget.progress.clamp(0.0, 1.0),
            onChanged: (value) {
              if (widget.duration.inMilliseconds > 0) {
                final newPosition = Duration(
                  milliseconds: (widget.duration.inMilliseconds * value).round(),
                );
                context.read<PlayerBloc>().add(PlayerSeekTo(newPosition));
              }
            },
            min: 0.0,
            max: 1.0,
          ),

          const SizedBox(height: 4),

          // 时间显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(widget.position),
                style: MacosTheme.of(context).typography.caption2.copyWith(
                  fontSize: 10,
                  color: widget.secondaryColor,
                ),
              ),
              Text(
                '-${_formatDuration(widget.duration - widget.position)}',
                style: MacosTheme.of(context).typography.caption2.copyWith(
                  fontSize: 10,
                  color: widget.secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}