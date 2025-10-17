import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../blocs/player/player_bloc.dart';

class MacOSVolumeControl extends StatelessWidget {
  final double volume;
  final Color iconColor;

  const MacOSVolumeControl({
    super.key,
    required this.volume,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MacosIcon(
          CupertinoIcons.speaker_1_fill,
          size: 14,
          color: iconColor,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90, // 增加音量滑块宽度
          child: MacosSlider(
            value: volume.clamp(0.0, 1.0),
            onChanged: (value) {
              context.read<PlayerBloc>().add(PlayerSetVolume(value));
            },
            min: 0.0,
            max: 1.0,
          ),
        ),
      ],
    );
  }
}