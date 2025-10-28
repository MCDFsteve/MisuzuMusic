import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/desktop_lyrics_constants.dart';

class DesktopLyricsBridge {
  DesktopLyricsBridge({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri(
        scheme: 'http',
        host: DesktopLyricsConstants.defaultHost,
        port: DesktopLyricsConstants.defaultPort,
        path: path,
      );

  Future<bool> ping({Duration? timeout}) async {
    try {
      final response = await _client
          .get(_uri('/health'))
          .timeout(timeout ?? DesktopLyricsConstants.requestTimeout);
      debugPrint('桌面歌词健康检查响应: ${response.statusCode}');
      return response.statusCode == 200;
    } on TimeoutException catch (error) {
      developer.log('桌面歌词健康检查超时', error: error, name: 'DesktopLyricsBridge');
      return false;
    } catch (error) {
      developer.log('桌面歌词健康检查失败', error: error, name: 'DesktopLyricsBridge');
      return false;
    }
  }

  Future<bool> showWindow() async {
    try {
      final response = await _client
          .post(_uri('/show'))
          .timeout(DesktopLyricsConstants.requestTimeout);
      debugPrint('桌面歌词窗口显示响应: ${response.statusCode}');
      return response.statusCode == 200;
    } on TimeoutException catch (error) {
      developer.log('桌面歌词窗口显示请求超时', error: error, name: 'DesktopLyricsBridge');
      return false;
    } catch (error) {
      developer.log('桌面歌词窗口显示请求失败', error: error, name: 'DesktopLyricsBridge');
      return false;
    }
  }

  Future<bool> update(DesktopLyricsUpdate update) async {
    try {
      final response = await _client
          .post(
            _uri('/lyrics'),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(update.toJson()),
          )
          .timeout(DesktopLyricsConstants.requestTimeout);
      debugPrint('桌面歌词更新响应: ${response.statusCode}');
      return response.statusCode == 200;
    } on TimeoutException catch (error) {
      developer.log('桌面歌词更新请求超时', error: error, name: 'DesktopLyricsBridge');
      return false;
    } catch (error) {
      developer.log('桌面歌词更新请求失败', error: error, name: 'DesktopLyricsBridge');
      return false;
    }
  }

  Future<bool> clear() => update(const DesktopLyricsUpdate());

  void dispose() {
    _client.close();
  }
}

class DesktopLyricsUpdate {
  const DesktopLyricsUpdate({
    this.trackId,
    this.title,
    this.artist,
    this.activeLine,
    this.nextLine,
    this.positionMs,
    this.isPlaying,
    this.activeSegments,
    this.nextSegments,
    this.activeTranslation,
    this.nextTranslation,
    this.showTranslation,
  });

  final String? trackId;
  final String? title;
  final String? artist;
  final String? activeLine;
  final String? nextLine;
  final int? positionMs;
  final bool? isPlaying;
  final List<DesktopLyricsSegment>? activeSegments;
  final List<DesktopLyricsSegment>? nextSegments;
  final String? activeTranslation;
  final String? nextTranslation;
  final bool? showTranslation;

  Map<String, dynamic> toJson() {
    return {
      if (trackId != null) 'track_id': trackId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (activeLine != null) 'active_line': activeLine,
      if (nextLine != null) 'next_line': nextLine,
      if (positionMs != null) 'position_ms': positionMs,
      if (isPlaying != null) 'is_playing': isPlaying,
      if (activeSegments != null)
        'active_segments': activeSegments!
            .map((segment) => segment.toJson())
            .toList(growable: false),
      if (nextSegments != null)
        'next_segments': nextSegments!
            .map((segment) => segment.toJson())
            .toList(growable: false),
      if (activeTranslation != null) 'active_translation': activeTranslation,
      if (nextTranslation != null) 'next_translation': nextTranslation,
      if (showTranslation != null) 'show_translation': showTranslation,
    };
  }

  DesktopLyricsUpdate copyWith({
    String? trackId,
    String? title,
    String? artist,
    String? activeLine,
    String? nextLine,
    int? positionMs,
    bool? isPlaying,
    List<DesktopLyricsSegment>? activeSegments,
    List<DesktopLyricsSegment>? nextSegments,
    String? activeTranslation,
    String? nextTranslation,
    bool? showTranslation,
  }) {
    return DesktopLyricsUpdate(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      activeLine: activeLine ?? this.activeLine,
      nextLine: nextLine ?? this.nextLine,
      positionMs: positionMs ?? this.positionMs,
      isPlaying: isPlaying ?? this.isPlaying,
      activeSegments: activeSegments ?? this.activeSegments,
      nextSegments: nextSegments ?? this.nextSegments,
      activeTranslation: activeTranslation ?? this.activeTranslation,
      nextTranslation: nextTranslation ?? this.nextTranslation,
      showTranslation: showTranslation ?? this.showTranslation,
    );
  }
}

class DesktopLyricsSegment {
  const DesktopLyricsSegment({
    required this.original,
    required this.annotation,
    required this.type,
  });

  final String original;
  final String annotation;
  final String type;

  Map<String, String> toJson() {
    return {
      'original': original,
      'annotation': annotation,
      'type': type,
    };
  }
}
