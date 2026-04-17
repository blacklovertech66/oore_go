import 'dart:convert';
import 'dart:typed_data';

/// OoreLink Protocol (OLP) — Frame definitions
/// All JSON frames share a `type` discriminator field.
/// Binary frames (PUSH_BYTECODE, PUSH_DELTA) have a fixed binary header.

// ─── JSON Frame Types ────────────────────────────────────────────────────────

enum OlpFrameType {
  hello,
  helloAck,
  hotReload,
  hotReloadAck,
  logEmit,
  compileError,
  missingPlugin,
  ping,
  pong,
}

// ─── HELLO ────────────────────────────────────────────────────────────────────

class HelloFrame {
  const HelloFrame({
    required this.version,
    required this.device,
    required this.capabilities,
    required this.token,
  });

  final String version;
  final DeviceInfo device;
  final List<String> capabilities;
  final String token; // HMAC-SHA256(sessionSecret, deviceId)

  factory HelloFrame.fromJson(Map<String, dynamic> json) => HelloFrame(
        version: json['version'] as String,
        device: DeviceInfo.fromJson(json['device'] as Map<String, dynamic>),
        capabilities: List<String>.from(json['capabilities'] as List),
        token: json['token'] as String,
      );

  Map<String, dynamic> toJson() => {
        'type': 'HELLO',
        'version': version,
        'device': device.toJson(),
        'capabilities': capabilities,
        'token': token,
      };
}

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.os,
    required this.osVersion,
    required this.flutterEvalVersion,
  });

  final String id;
  final String name;
  final String os; // 'android' | 'ios'
  final String osVersion;
  final String flutterEvalVersion;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        os: json['os'] as String,
        osVersion: json['osVersion'] as String,
        flutterEvalVersion: json['flutterEvalVersion'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'os': os,
        'osVersion': osVersion,
        'flutterEvalVersion': flutterEvalVersion,
      };
}

// ─── HELLO_ACK ───────────────────────────────────────────────────────────────

class HelloAckFrame {
  const HelloAckFrame({
    required this.sessionId,
    required this.projectName,
    required this.hasBytecode,
    required this.flutterVersion,
  });

  final String sessionId;
  final String projectName;
  final bool hasBytecode;
  final String flutterVersion;

  Map<String, dynamic> toJson() => {
        'type': 'HELLO_ACK',
        'sessionId': sessionId,
        'projectName': projectName,
        'hasBytecode': hasBytecode,
        'flutterVersion': flutterVersion,
      };

  factory HelloAckFrame.fromJson(Map<String, dynamic> json) => HelloAckFrame(
        sessionId: json['sessionId'] as String,
        projectName: json['projectName'] as String,
        hasBytecode: json['hasBytecode'] as bool,
        flutterVersion: json['flutterVersion'] as String,
      );
}

// ─── HOT_RELOAD ──────────────────────────────────────────────────────────────

class HotReloadFrame {
  const HotReloadFrame({
    required this.bytecodeId,
    this.preserveState = false,
  });

  final String bytecodeId; // SHA-256 of .evc bytes
  final bool preserveState;

  Map<String, dynamic> toJson() => {
        'type': 'HOT_RELOAD',
        'bytecodeId': bytecodeId,
        'preserveState': preserveState,
      };

  factory HotReloadFrame.fromJson(Map<String, dynamic> json) => HotReloadFrame(
        bytecodeId: json['bytecodeId'] as String,
        preserveState: (json['preserveState'] as bool?) ?? false,
      );
}

// ─── HOT_RELOAD_ACK ──────────────────────────────────────────────────────────

class HotReloadAckFrame {
  const HotReloadAckFrame({
    required this.bytecodeId,
    required this.durationMs,
    required this.success,
    this.error,
  });

  final String bytecodeId;
  final int durationMs;
  final bool success;
  final String? error;

  Map<String, dynamic> toJson() => {
        'type': 'HOT_RELOAD_ACK',
        'bytecodeId': bytecodeId,
        'durationMs': durationMs,
        'success': success,
        if (error != null) 'error': error,
      };

  factory HotReloadAckFrame.fromJson(Map<String, dynamic> json) =>
      HotReloadAckFrame(
        bytecodeId: json['bytecodeId'] as String,
        durationMs: json['durationMs'] as int,
        success: json['success'] as bool,
        error: json['error'] as String?,
      );
}

// ─── LOG_EMIT ─────────────────────────────────────────────────────────────────

enum LogLevel { debug, info, warn, error }

class LogEmitFrame {
  const LogEmitFrame({
    required this.deviceId,
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
  });

  final String deviceId;
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;

  Map<String, dynamic> toJson() => {
        'type': 'LOG_EMIT',
        'deviceId': deviceId,
        'timestamp': timestamp.toIso8601String(),
        'level': level.name.toUpperCase(),
        'message': message,
        if (tag != null) 'tag': tag,
      };

  factory LogEmitFrame.fromJson(Map<String, dynamic> json) => LogEmitFrame(
        deviceId: json['deviceId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: LogLevel.values.firstWhere(
            (l) => l.name.toUpperCase() == (json['level'] as String)),
        message: json['message'] as String,
        tag: json['tag'] as String?,
      );
}

// ─── COMPILE_ERROR ───────────────────────────────────────────────────────────

class CompileError {
  const CompileError({
    required this.file,
    required this.line,
    required this.col,
    required this.message,
  });

  final String file;
  final int line;
  final int col;
  final String message;

  Map<String, dynamic> toJson() => {
        'file': file,
        'line': line,
        'col': col,
        'message': message,
      };
}

class CompileErrorFrame {
  const CompileErrorFrame({required this.errors});

  final List<CompileError> errors;

  Map<String, dynamic> toJson() => {
        'type': 'COMPILE_ERROR',
        'errors': errors.map((e) => e.toJson()).toList(),
      };
}

// ─── Binary Frame Codec ───────────────────────────────────────────────────────
// Layout: [4 magic][4 length][4 crc32][N payload]

const _kMagic = 0x4F4F5245; // "OORE"

class BinaryFrameEncoder {
  /// Encodes bytecode payload into an OLP binary frame.
  static Uint8List encode(Uint8List payload) {
    final crc = _crc32(payload);
    final buffer = ByteData(12 + payload.length);
    buffer.setUint32(0, _kMagic, Endian.big);
    buffer.setUint32(4, payload.length, Endian.big);
    buffer.setUint32(8, crc, Endian.big);
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(12, 12 + payload.length, payload);
    return bytes;
  }

  /// Decodes an OLP binary frame, verifying magic and CRC.
  static Uint8List decode(Uint8List frame) {
    if (frame.length < 12) throw const FormatException('Frame too short');
    final view = ByteData.sublistView(frame);
    final magic = view.getUint32(0, Endian.big);
    if (magic != _kMagic) throw const FormatException('Invalid magic bytes');
    final length = view.getUint32(4, Endian.big);
    final crc = view.getUint32(8, Endian.big);
    final payload = frame.sublist(12, 12 + length);
    if (_crc32(payload) != crc) throw const FormatException('CRC32 mismatch');
    return payload;
  }

  static int _crc32(Uint8List data) {
    // Simple CRC32 implementation
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }
}

// ─── JSON Frame Dispatcher ────────────────────────────────────────────────────

Map<String, dynamic> decodeJsonFrame(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;
