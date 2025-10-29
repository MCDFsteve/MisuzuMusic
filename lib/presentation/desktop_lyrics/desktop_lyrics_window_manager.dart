import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

class DesktopLyricsWindowManager {
  DesktopLyricsWindowManager._();

  static final DesktopLyricsWindowManager instance =
      DesktopLyricsWindowManager._();

  WindowController? _controller;
  bool _isCreating = false;
  bool _initialized = false;

  void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!_isDesktop) {
      return;
    }

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      switch (call.method) {
        case 'lyrics_window_disposed':
          if (_controller?.windowId == fromWindowId) {
            _controller = null;
          }
          break;
        case 'lyrics_window_ready':
          try {
            await DesktopMultiWindow.invokeMethod(
              fromWindowId,
              'focus_window',
              null,
            );
          } catch (error) {
            debugPrint('Failed to focus lyrics window: $error');
          }
          break;
      }
      return null;
    });
  }

  Future<void> showLyricsWindow() async {
    if (!_isDesktop) {
      return;
    }

    initialize();

    if (_controller == null) {
      await _createWindow();
      return;
    }

    final controller = _controller;
    if (controller == null) {
      return;
    }

    try {
      await controller.show();
      await DesktopMultiWindow.invokeMethod(
        controller.windowId,
        'show_window',
        null,
      );
    } catch (error) {
      debugPrint('Failed to show existing lyrics window: $error');
      _controller = null;
      await _createWindow();
    }
  }

  Future<void> hideLyricsWindow() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.hide();
      await DesktopMultiWindow.invokeMethod(
        controller.windowId,
        'hide_window',
        null,
      );
    } catch (error) {
      debugPrint('Failed to hide lyrics window: $error');
    }
  }

  Future<void> _createWindow() async {
    if (_isCreating) {
      return;
    }
    _isCreating = true;
    try {
      final controller = await DesktopMultiWindow.createWindow(
        jsonEncode({'kind': 'lyrics'}),
      );
      await controller.setTitle('Misuzu Lyrics');
      _controller = controller;
      await controller.show();
    } catch (error, stackTrace) {
      debugPrint('Failed to create lyrics window: $error\n$stackTrace');
      _controller = null;
    } finally {
      _isCreating = false;
    }
  }

  bool get _isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
