import 'dart:async';
import '../protocol/frames.dart';

/// Aggregates LOG_EMIT frames from connected devices and prints them
/// to the developer's terminal with ANSI color formatting.
class RemoteConsole {
  final _controller = StreamController<LogEmitFrame>.broadcast();

  Stream<LogEmitFrame> get stream => _controller.stream;

  void receive(LogEmitFrame frame) {
    _controller.add(frame);
    _print(frame);
  }

  void _print(LogEmitFrame frame) {
    final time = _formatTime(frame.timestamp);
    final level = _colorLevel(frame.level);
    final device = '\x1B[35m${frame.deviceId.substring(0, 8)}\x1B[0m';
    final tag = frame.tag != null ? '\x1B[36m[${frame.tag}]\x1B[0m ' : '';
    final message = frame.message;

    print('  $time $level $device $tag$message');
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '\x1B[90m$h:$m:$s.$ms\x1B[0m';
  }

  String _colorLevel(LogLevel level) {
    return switch (level) {
      LogLevel.debug => '\x1B[90m[DBG]\x1B[0m',
      LogLevel.info  => '\x1B[32m[INF]\x1B[0m',
      LogLevel.warn  => '\x1B[33m[WRN]\x1B[0m',
      LogLevel.error => '\x1B[31m[ERR]\x1B[0m',
    };
  }

  void dispose() => _controller.close();
}
