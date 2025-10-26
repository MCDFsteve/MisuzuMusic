import 'package:flutter/foundation.dart';

bool isDesktopPlatform([TargetPlatform? platform]) {
  final target = platform ?? defaultTargetPlatform;
  return target == TargetPlatform.macOS ||
      target == TargetPlatform.windows ||
      target == TargetPlatform.linux;
}

bool isMobilePlatform([TargetPlatform? platform]) {
  final target = platform ?? defaultTargetPlatform;
  return target == TargetPlatform.android || target == TargetPlatform.iOS;
}

bool prefersMacLikeUi([TargetPlatform? platform]) {
  return isDesktopPlatform(platform);
}
