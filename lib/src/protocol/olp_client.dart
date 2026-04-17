import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'package:oore_flutter/oore_flutter.dart';
import 'reconnect_policy.dart';

/// OLP WebSocket client — runs inside Oore Go on the device.
/// Handles connection lifecycle, frame parsing, and reconnection. (V1 - QR focus)
class OlpClient {
  OlpClient({
    required this.host,
    required this.port,
    required this.deviceInfo,
    required this.sessionSecret,
    ReconnectPolicy? reconnectPolicy,
  }) : _reconnectPolicy = reconnectPolicy ?? ExponentialBackoffPolicy();

  final String host;
  final int port;
  final DeviceInfo deviceInfo;
  final String sessionSecret;
  final ReconnectPolicy _reconnectPolicy;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _disposed = false;

  // ── Public callbacks ───────────────────────────────────────────────────────

  void Function(Uint8List bytecode)? onBytecodeReceived;
  void Function(Uint8List delta)? onDeltaReceived;
  void Function(HotReloadFrame frame)? onHotReload;
  void Function(CompileErrorFrame frame)? onCompileError;
  void Function(ConnectionStatus status)? onStatusChanged;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_disposed) return;
    _setStatus(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://$host:$port');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _setStatus(ConnectionStatus.connected);
      _reconnectPolicy.reset();

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
      );

      _sendHello();
    } catch (e) {
      _onError(e);
    }
  }

  Future<void> disconnect() async {
    _disposed = true;
    await _sub?.cancel();
    await _channel?.sink.close(ws_status.goingAway);
    _setStatus(ConnectionStatus.disconnected);
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  void _sendHello() {
    final token = _computeHmac(sessionSecret, deviceInfo.id);
    final frame = HelloFrame(
      version: '1.0',
      device: deviceInfo,
      capabilities: ['HOT_RELOAD', 'LOG_EMIT', 'DELTA_PATCH'],
      token: token,
    );
    _sendJson(frame.toJson());
  }

  void sendHotReloadAck(HotReloadAckFrame ack) => _sendJson(ack.toJson());
  void sendLogEmit(LogEmitFrame log) => _sendJson(log.toJson());

  void _sendJson(Map<String, dynamic> json) {
    _channel?.sink.add(jsonEncode(json));
  }

  // ── Receiving ─────────────────────────────────────────────────────────────

  void _onMessage(dynamic message) {
    if (message is String) {
      _handleJsonFrame(message);
    } else if (message is List<int>) {
      _handleBinaryFrame(Uint8List.fromList(message));
    }
  }

  void _handleJsonFrame(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final type = json['type'] as String;

    switch (type) {
      case 'HELLO_ACK':
        _setStatus(ConnectionStatus.authenticated);
        break;
      case 'HOT_RELOAD':
        onHotReload?.call(HotReloadFrame.fromJson(json));
        break;
      case 'COMPILE_ERROR':
        onCompileError?.call(CompileErrorFrame.fromJson(json));
        break;
      case 'PING':
        _sendJson({'type': 'PONG'});
        break;
    }
  }

  void _handleBinaryFrame(Uint8List frame) {
    if (frame.isEmpty) return;

    final frameType = frame[0];
    final payload = BinaryFrameEncoder.decode(frame.sublist(1));

    if (frameType == 0x01) {
      onBytecodeReceived?.call(payload);
    } else if (frameType == 0x02) {
      onDeltaReceived?.call(payload);
    }
  }

  // ── Reconnection ──────────────────────────────────────────────────────────

  void _onError(Object error) {
    _setStatus(ConnectionStatus.error);
    if (!_disposed) _scheduleReconnect();
  }

  void _onDisconnected() {
    _setStatus(ConnectionStatus.disconnected);
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() async {
    final delay = _reconnectPolicy.nextDelay();
    await Future.delayed(delay);
    if (!_disposed) await connect();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setStatus(ConnectionStatus s) {
    _status = s;
    onStatusChanged?.call(s);
  }

  String _computeHmac(String secret, String data) {
    // V1 Placeholder: Simple concatenation. 
    // In production: use package:crypto Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(data))
    return base64Encode(utf8.encode('$secret:$data'));
  }
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  authenticated,
  error,
}
