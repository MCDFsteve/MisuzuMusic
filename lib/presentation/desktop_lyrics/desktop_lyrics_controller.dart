import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/desktop_lyrics_constants.dart';
import '../../core/services/desktop_lyrics_bridge.dart';

class DesktopLyricsStreamController {
  DesktopLyricsStreamController();

  final ValueNotifier<DesktopLyricsUpdate?> updateNotifier =
      ValueNotifier<DesktopLyricsUpdate?>(null);

  WebSocket? _socket;
  bool _disposed = false;
  Timer? _reconnectTimer;

  Future<void> initialize() async {
    await _fetchInitial();
    _connect();
  }

  Future<void> _fetchInitial() async {
    final uri = Uri(
      scheme: 'http',
      host: DesktopLyricsConstants.defaultHost,
      port: DesktopLyricsConstants.defaultPort,
      path: '/lyrics',
    );

    try {
      final response = await http.get(uri).timeout(
            DesktopLyricsConstants.requestTimeout,
          );
      if (response.statusCode == HttpStatus.ok && response.body.isNotEmpty) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        final update = DesktopLyricsUpdate.fromJson(json);
        updateNotifier.value = update;
      }
    } catch (error) {
      debugPrint('Lyrics stream initial fetch failed: $error');
    }
  }

  void _connect() {
    if (_disposed) {
      return;
    }

    final uri = Uri(
      scheme: 'ws',
      host: DesktopLyricsConstants.defaultHost,
      port: DesktopLyricsConstants.defaultPort,
      path: '/stream',
    );

    WebSocket.connect(uri.toString()).then((socket) {
      _socket = socket;
      socket.listen(
        (dynamic data) {
          _handleMessage(data);
        },
        onError: (error) {
          debugPrint('Lyrics stream error: $error');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    }).catchError((error) {
      debugPrint('Lyrics stream connect failed: $error');
      _scheduleReconnect();
    });
  }

  void _handleMessage(dynamic payload) {
    try {
      if (payload is! String) {
        return;
      }
      final Map<String, dynamic> json =
          jsonDecode(payload) as Map<String, dynamic>;
      final update = DesktopLyricsUpdate.fromJson(json);
      updateNotifier.value = update;
    } catch (error) {
      debugPrint('Lyrics stream decode failed: $error');
    }
  }

  void _scheduleReconnect() {
    _socket?.close();
    _socket = null;
    if (_disposed) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 1), _connect);
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close(WebSocketStatus.normalClosure, 'dispose');
    }
    updateNotifier.dispose();
  }
}
