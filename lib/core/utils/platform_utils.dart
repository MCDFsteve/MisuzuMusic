import 'dart:ui' as ui;

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
  final target = platform ?? defaultTargetPlatform;
  if (isDesktopPlatform(target)) {
    return true;
  }
  return _isTabletFormFactor(target);
}

bool _isTabletFormFactor(TargetPlatform platform) {
  if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
    return false;
  }

  final view = ui.PlatformDispatcher.instance.views.isNotEmpty
      ? ui.PlatformDispatcher.instance.views.first
      : null;
  if (view == null) {
    return false;
  }

  final double devicePixelRatio = view.devicePixelRatio;
  if (devicePixelRatio <= 0) {
    return false;
  }

  final double logicalShortestSide =
      view.physicalSize.shortestSide / devicePixelRatio;
  if (!logicalShortestSide.isFinite) {
    return false;
  }

  const double tabletThreshold = 600;
  return logicalShortestSide >= tabletThreshold;
}
