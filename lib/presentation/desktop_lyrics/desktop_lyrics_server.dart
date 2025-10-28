import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/constants/desktop_lyrics_constants.dart';
import '../../core/services/desktop_lyrics_bridge.dart';
import 'desktop_lyrics_window_manager.dart';

class DesktopLyricsServer {
  DesktopLyricsServer._();

  static final DesktopLyricsServer instance = DesktopLyricsServer._();

  HttpServer? _server;
  bool _starting = false;
  DesktopLyricsUpdate? _lastUpdate;
  final List<WebSocket> _clients = [];

  Future<void> start() async {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return;
    }

    if (_server != null || _starting) {
      return;
    }

    _starting = true;
    try {
      final server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        DesktopLyricsConstants.defaultPort,
        shared: true,
      );
      _server = server;
      _listen(server);
      debugPrint(
        'DesktopLyricsServer started on ${server.address.address}:${server.port}',
      );
    } on SocketException catch (error) {
      debugPrint('DesktopLyricsServer failed to bind: $error');
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    final server = _server;
    if (server == null) {
      return;
    }
    _server = null;
    await server.close(force: true);
    for (final client in List<WebSocket>.from(_clients)) {
      await client.close(WebSocketStatus.normalClosure, 'server-stopped');
    }
    _clients.clear();
  }

  void _listen(HttpServer server) {
    unawaited(
      server.forEach((request) async {
        try {
          await _handleRequest(request);
        } catch (error, stackTrace) {
          debugPrint('DesktopLyricsServer request error: $error\n$stackTrace');
          if (!request.response.headersSent) {
            request.response.statusCode = HttpStatus.internalServerError;
          }
          await request.response.close();
        }
      }),
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    switch (path) {
      case '/health':
        await _respondJson(request, {'status': 'ok'});
        break;
      case '/lyrics':
        if (request.method == 'GET') {
          await _handleGetLyrics(request);
        } else if (request.method == 'POST') {
          await _handlePostLyrics(request);
        } else {
          await _respondStatus(request, HttpStatus.methodNotAllowed);
        }
        break;
      case '/show':
        if (request.method == 'POST') {
          await DesktopLyricsWindowManager.instance.showLyricsWindow();
          await _respondJson(request, {'status': 'shown'});
        } else {
          await _respondStatus(request, HttpStatus.methodNotAllowed);
        }
        break;
      case '/hide':
        if (request.method == 'POST') {
          await DesktopLyricsWindowManager.instance.hideLyricsWindow();
          await _respondJson(request, {'status': 'hidden'});
        } else {
          await _respondStatus(request, HttpStatus.methodNotAllowed);
        }
        break;
      case '/stream':
        await _handleStream(request);
        break;
      default:
        await _respondStatus(request, HttpStatus.notFound);
    }
  }

  Future<void> _handleGetLyrics(HttpRequest request) async {
    final update = _lastUpdate;
    if (update == null) {
      await _respondStatus(request, HttpStatus.noContent);
      return;
    }
    await _respondJson(request, update.toJson());
  }

  Future<void> _handlePostLyrics(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final Map<String, dynamic> json;
    if (body.isEmpty) {
      json = const {};
    } else {
      json = jsonDecode(body) as Map<String, dynamic>;
    }

    final update = DesktopLyricsUpdate.fromJson(json);
    _lastUpdate = update;
    await _respondJson(request, update.toJson());
    _broadcastUpdate(update);
  }

  Future<void> _handleStream(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      await _respondStatus(request, HttpStatus.badRequest);
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    _clients.add(socket);
    final update = _lastUpdate;
    if (update != null) {
      socket.add(jsonEncode(update.toJson()));
    }

    socket.done.whenComplete(() => _clients.remove(socket));
  }

  void _broadcastUpdate(DesktopLyricsUpdate update) {
    final payload = jsonEncode(update.toJson());
    for (final socket in List<WebSocket>.from(_clients)) {
      if (socket.readyState == WebSocket.open) {
        socket.add(payload);
      } else {
        _clients.remove(socket);
      }
    }
  }

  Future<void> _respondJson(HttpRequest request, Map<String, dynamic> data) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(data));
    await request.response.close();
  }

  Future<void> _respondStatus(HttpRequest request, int statusCode) async {
    request.response.statusCode = statusCode;
    await request.response.close();
  }
}
