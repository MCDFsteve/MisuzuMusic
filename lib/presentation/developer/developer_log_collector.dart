import 'dart:collection';

import 'package:flutter/foundation.dart';

/// 日志级别，用于在开发者工具中筛选输出。
enum DeveloperLogLevel { info, error }

/// 单条日志的结构化表示。
class DeveloperLogEntry {
  DeveloperLogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  final DateTime timestamp;
  final String message;
  final DeveloperLogLevel level;

  String formattedTimestamp() => DeveloperLogCollector._formatTimestamp(timestamp);
}

/// 收集运行时产生的日志，供开发者选项界面展示。
class DeveloperLogCollector {
  DeveloperLogCollector._();

  static final DeveloperLogCollector instance = DeveloperLogCollector._();

  static const int _maxEntries = 1000;

  final ListQueue<DeveloperLogEntry> _buffer = ListQueue<DeveloperLogEntry>();
  final ValueNotifier<List<DeveloperLogEntry>> _logsNotifier =
      ValueNotifier<List<DeveloperLogEntry>>(const <DeveloperLogEntry>[]);

  DebugPrintCallback? _originalDebugPrint;
  bool _initialized = false;
  int _suppressedPrintDepth = 0;

  ValueListenable<List<DeveloperLogEntry>> get logsListenable => _logsNotifier;

  /// 初始化调试输出的拦截逻辑。必须在应用启动时调用一次。
  void initialize() {
    if (_initialized) {
      return;
    }

    _originalDebugPrint ??= debugPrint;

    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) {
        return;
      }

      addMessage(message);

      final original = _originalDebugPrint;
      if (original == null) {
        return;
      }

      _withSuppressedPrints(() {
        original(message, wrapWidth: wrapWidth);
      });
    };

    _initialized = true;
  }

  /// 判断当前是否需要跳过 Zone 中的 print 拦截，避免重复收集。
  bool get isSuppressingPrints => _suppressedPrintDepth > 0;

  /// 将原始消息拆分并写入缓冲区。
  void addMessage(String message) {
    final normalized = message.replaceAll('\r\n', '\n').split('\n');
    for (final raw in normalized) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        continue;
      }
      _pushLine(line, DeveloperLogLevel.info);
    }
  }

  /// 记录未捕获异常的栈信息。
  void addError(Object error, StackTrace stackTrace) {
    _pushLine('未捕获异常: $error', DeveloperLogLevel.error);
    final stack = stackTrace.toString().trim();
    if (stack.isEmpty) {
      return;
    }

    for (final line in stack.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        continue;
      }
      _pushLine(trimmed, DeveloperLogLevel.error);
    }
  }

  /// 清空所有已收集的日志。
  void clear() {
    _buffer.clear();
    _logsNotifier.value = const <DeveloperLogEntry>[];
  }

  void _pushLine(String line, DeveloperLogLevel level) {
    final entry = DeveloperLogEntry(
      timestamp: DateTime.now(),
      message: line,
      level: level,
    );
    _buffer.addLast(entry);

    if (_buffer.length > _maxEntries) {
      _buffer.removeFirst();
    }

    _logsNotifier.value = List<DeveloperLogEntry>.unmodifiable(_buffer);
  }

  void _withSuppressedPrints(VoidCallback callback) {
    _suppressedPrintDepth++;
    try {
      callback();
    } finally {
      _suppressedPrintDepth--;
    }
  }

  static String _formatTimestamp(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final buffer = StringBuffer()
      ..write(twoDigits(time.hour))
      ..write(':')
      ..write(twoDigits(time.minute))
      ..write(':')
      ..write(twoDigits(time.second))
      ..write('.')
      ..write(time.millisecond.toString().padLeft(3, '0'));
    return buffer.toString();
  }
}
