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
      if (response.statusCode != 200) {
        developer.log(
          '桌面歌词健康检查异常状态码: ${response.statusCode}',
          name: 'DesktopLyricsBridge',
        );
      }
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
      if (response.statusCode != 200) {
        developer.log(
          '桌面歌词窗口显示异常状态码: ${response.statusCode}',
          name: 'DesktopLyricsBridge',
        );
      }
      return response.statusCode == 200;
    } on TimeoutException catch (error) {
      developer.log('桌面歌词窗口显示请求超时', error: error, name: 'DesktopLyricsBridge');
      return false;
    } catch (error) {
      developer.log('桌面歌词窗口显示请求失败', error: error, name: 'DesktopLyricsBridge');
      return false;
    }
  }

  Future<bool> hideWindow() async {
    try {
      final response = await _client
          .post(_uri('/hide'))
          .timeout(DesktopLyricsConstants.requestTimeout);
      if (response.statusCode != 200) {
        developer.log(
          '桌面歌词窗口隐藏异常状态码: ${response.statusCode}',
          name: 'DesktopLyricsBridge',
        );
      }
      return response.statusCode == 200;
    } on TimeoutException catch (error) {
      developer.log('桌面歌词窗口隐藏请求超时', error: error, name: 'DesktopLyricsBridge');
      return false;
    } catch (error) {
      developer.log('桌面歌词窗口隐藏请求失败', error: error, name: 'DesktopLyricsBridge');
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
      if (response.statusCode != 200) {
        developer.log(
          '桌面歌词更新异常状态码: ${response.statusCode}',
          name: 'DesktopLyricsBridge',
        );
      }
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
  });

  final String? trackId;
  final String? title;
  final String? artist;
  final String? activeLine;
  final String? nextLine;
  final int? positionMs;
  final bool? isPlaying;

  Map<String, dynamic> toJson() {
    return {
      if (trackId != null) 'track_id': trackId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (activeLine != null) 'active_line': activeLine,
      if (nextLine != null) 'next_line': nextLine,
      if (positionMs != null) 'position_ms': positionMs,
      if (isPlaying != null) 'is_playing': isPlaying,
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
  }) {
    return DesktopLyricsUpdate(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      activeLine: activeLine ?? this.activeLine,
      nextLine: nextLine ?? this.nextLine,
      positionMs: positionMs ?? this.positionMs,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  factory DesktopLyricsUpdate.fromJson(Map<String, dynamic> json) {
    return DesktopLyricsUpdate(
      trackId: json['track_id'] as String?,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      activeLine: json['active_line'] as String?,
      nextLine: json['next_line'] as String?,
      positionMs: switch (json['position_ms']) {
        int value => value,
        String value => int.tryParse(value),
        _ => null,
      },
      isPlaying: json['is_playing'] is bool
          ? json['is_playing'] as bool
          : json['is_playing'] is String
              ? (json['is_playing'] as String).toLowerCase() == 'true'
              : null,
    );
  }

  bool get hasAnyContent =>
      (activeLine != null && activeLine!.trim().isNotEmpty) ||
      (nextLine != null && nextLine!.trim().isNotEmpty);
}
