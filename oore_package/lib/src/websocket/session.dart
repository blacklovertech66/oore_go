import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/frames.dart';
import '../config.dart';

/// Manages a single connected device session on the dev server side.
class DeviceSession {
  DeviceSession({
    required this.id,
    required this.ws,
    required this.config,
    required this.onLogEmit,
    required this.onHotReloadAck,
    required this.onClose,
  });

  final String id;
  final WebSocketChannel ws;
  final OoreConfig config;
  final void Function(LogEmitFrame) onLogEmit;
  final void Function(String deviceName, HotReloadAckFrame) onHotReloadAck;
  final void Function() onClose;

  DeviceInfo? _deviceInfo;
  StreamSubscription? _sub;
  String? _pendingBytecodeId;

  String get deviceName => _deviceInfo?.name ?? 'Unknown Device';

  void start() {
    _sub = ws.stream.listen(
      _onMessage,
      onDone: _onClose,
      onError: (_) => _onClose(),
    );
  }

  Future<void> pushBytecode(List<int> bytecode) async {
    final payload = Uint8List.fromList(bytecode);
    final encoded = BinaryFrameEncoder.encode(payload);

    // Prepend 0x01 type byte (full bytecode)
    final frame = Uint8List(encoded.length + 1);
    frame[0] = 0x01;
    frame.setRange(1, frame.length, encoded);

    ws.sink.add(frame);

    // Compute SHA-256 id
    _pendingBytecodeId = _sha256Hex(payload);

    // Send HOT_RELOAD signal
    sendJson(HotReloadFrame(
      bytecodeId: _pendingBytecodeId!,
      preserveState: false,
    ).toJson());
  }

  void sendJson(Map<String, dynamic> json) {
    ws.sink.add(jsonEncode(json));
  }

  Future<void> close() async {
    await _sub?.cancel();
    await ws.sink.close();
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;
    final json = jsonDecode(message) as Map<String, dynamic>;
    final type = json['type'] as String;

    switch (type) {
      case 'HELLO':
        _handleHello(HelloFrame.fromJson(json));
        break;
      case 'HOT_RELOAD_ACK':
        final ack = HotReloadAckFrame.fromJson(json);
        onHotReloadAck(deviceName, ack);
        break;
      case 'LOG_EMIT':
        onLogEmit(LogEmitFrame.fromJson(json));
        break;
    }
  }

  void _handleHello(HelloFrame hello) {
    _deviceInfo = hello.device;
    // TODO: validate HMAC token
    sendJson(HelloAckFrame(
      sessionId: id,
      projectName: 'oore_project', // from pubspec
      hasBytecode: false,
      flutterVersion: '3.22.0',
    ).toJson());
  }

  void _onClose() {
    _sub?.cancel();
    onClose();
  }

  String _sha256Hex(Uint8List bytes) {
    // Placeholder — use package:crypto in production
    return bytes.length.toRadixString(16).padLeft(64, '0');
  }
}
