import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'protocol/frames.dart';
import 'config.dart';
import 'bytecode/watcher.dart';
import 'bytecode/compiler.dart';
import 'websocket/session.dart';
import 'console/remote_console.dart';

/// The main Oore Dev Server. (V1 - Public IP / QR focus)
///
/// Manages:
/// - WebSocket gateway
/// - File watching + bytecode compilation
/// - Session management for connected devices
/// - Remote console aggregation
class OoreDevServer {
  OoreDevServer._(this._config, this._sessionId);

  final OoreConfig _config;
  final String _sessionId;

  final _sessions = <String, DeviceSession>{};
  final _console = RemoteConsole();

  HttpServer? _server;
  SourceWatcher? _watcher;
  String? _publicIp;

  /// Convenience: run the server as a Flutter app wrapper.
  static Future<void> run({
    required dynamic app, // Widget — typed as dynamic to avoid Flutter dep
    OoreConfig config = const OoreConfig(),
  }) async {
    final server = OoreDevServer._(config, const Uuid().v4());
    await server.start();

    // Run the Flutter app normally alongside the server
    // ignore: avoid_dynamic_calls
    (app as dynamic).run();
  }

  Future<void> start() async {
    _printBanner();

    // Detect IP
    _publicIp = await _detectIp();
    _log('Pairing IP: \x1B[33m$_publicIp\x1B[0m');

    // Start WebSocket server
    final handler = webSocketHandler(_onWebSocketConnect);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _config.port);
    _log('WebSocket server listening on port \x1B[32m${_config.port}\x1B[0m');

    // Show QR code
    if (_config.showQrInTerminal) {
      _printQr();
    }

    // Start file watcher
    if (_config.enableHotReload) {
      _watcher = SourceWatcher(
        watchPath: _config.watchPath,
        debounceMs: _config.debounceMs,
        onChanged: _onSourceChanged,
      );
      await _watcher!.start();
      _log('Watching \x1B[36m${_config.watchPath}\x1B[0m for changes...');
    }
  }

  Future<void> stop() async {
    await _watcher?.stop();
    await _server?.close();
    for (final session in _sessions.values) {
      await session.close();
    }
    _sessions.clear();
  }

  // ── IP Detection ───────────────────────────────────────────────────────────

  Future<String> _detectIp() async {
    try {
      // Priority 1: Configuration override
      if (_config.relayUrl != null) return _config.relayUrl!;

      // Priority 2: Public IP detection (e.g. for devs behind NAT with port forwarding)
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://api.ipify.org'));
      final response = await request.close();
      final ip = await response.transform(const Utf8Decoder()).join();
      return ip.trim();
    } catch (_) {
      // Fallback: Local Network IP
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return '127.0.0.1';
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  void _onWebSocketConnect(WebSocketChannel ws, dynamic protocol) {
    final sessionId = const Uuid().v4();
    final session = DeviceSession(
      id: sessionId,
      ws: ws,
      config: _config,
      onLogEmit: _console.receive,
      onHotReloadAck: _onHotReloadAck,
      onClose: () => _sessions.remove(sessionId),
    );
    _sessions[sessionId] = session;
    session.start();
  }

  // ── Bytecode Pipeline ─────────────────────────────────────────────────────

  Future<void> _onSourceChanged(List<String> changedFiles) async {
    if (_sessions.isEmpty) return;

    _log('⟳  Compiling (${changedFiles.length} file(s) changed)...');
    final stopwatch = Stopwatch()..start();

    try {
      final result = await BytecodeCompiler.compile();
      stopwatch.stop();

      if (!result.success) {
        _logError('✗  Compile failed in ${stopwatch.elapsedMilliseconds}ms');
        for (final err in result.errors) {
          _logError('   ${err.file}:${err.line}:${err.col} — ${err.message}');
        }
        _broadcast(CompileErrorFrame(errors: result.errors));
        return;
      }

      _log('✓  Compiled in ${stopwatch.elapsedMilliseconds}ms '
          '(${_humanBytes(result.bytecode!.length)})');
      _broadcastBytecode(result.bytecode!);
    } catch (e) {
      _logError('✗  Compiler exception: $e');
    }
  }

  void _broadcastBytecode(List<int> bytecode) {
    for (final session in _sessions.values) {
      session.pushBytecode(bytecode);
    }
  }

  void _broadcast(dynamic frame) {
    for (final session in _sessions.values) {
      session.sendJson(frame);
    }
  }

  void _onHotReloadAck(String deviceName, HotReloadAckFrame ack) {
    if (ack.success) {
      _log('✓  ${deviceName} reloaded in ${ack.durationMs}ms');
    } else {
      _logError('✗  ${deviceName} reload failed: ${ack.error}');
    }
  }

  // ── Terminal Output ───────────────────────────────────────────────────────

  void _printBanner() {
    print('''
\x1B[32m
  ╔═══════════════════════════════════╗
  ║   ○ OORE DEV SERVER  v1.0.0      ║
  ║      [PUBLIC IP MODE]             ║
  ╚═══════════════════════════════════╝
\x1B[0m  Session: $_sessionId
  Port:    ${_config.port}
''');
  }

  void _printQr() {
    final payload = '{"ip":"$_publicIp","port":${_config.port},"secret":"$_sessionId"}';
    print('''
  \x1B[36mPAIRING READY\x1B[0m
  Scan this code in Oore Go to connect:

  $payload

  (Manual entry: $_publicIp:${_config.port})
''');
  }

  void _log(String msg) => print('  \x1B[36m[oore]\x1B[0m $msg');
  void _logError(String msg) => print('  \x1B[31m[oore]\x1B[0m $msg');

  String _humanBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
