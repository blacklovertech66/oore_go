import 'dart:async';
import 'dart:typed_data';

import 'package:oore_flutter/oore_flutter.dart';
import '../protocol/olp_client.dart';

/// Wraps the flutter_eval runtime for Oore Go.
///
/// Responsibilities:
/// - Load and execute .evc bytecode
/// - Handle hot reload (dispose + reinitialize)
/// - Intercept print() / log output → relay as LOG_EMIT
/// - Manage plugin bridge registration
class OoreRuntime {
  OoreRuntime({
    required this.onLogEmit,
    required this.onReloadComplete,
    required this.pluginRegistry,
  });

  final void Function(LogEmitFrame) onLogEmit;
  final void Function(int durationMs) onReloadComplete;
  final PluginRegistry pluginRegistry;

  dynamic _runtime;
  Uint8List? _currentBytecode;
  String? _currentBytecodeId;
  bool _isLoading = false;

  // ── Bytecode Management ───────────────────────────────────────────────────

  /// Load full bytecode and execute.
  Future<void> loadBytecode(Uint8List evc, String bytecodeId) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      _currentBytecode = evc;
      _currentBytecodeId = bytecodeId;
      await _initRuntime(evc);
    } finally {
      _isLoading = false;
    }
  }

  /// Apply a bsdiff delta patch and reload.
  Future<void> applyDelta(Uint8List delta, String bytecodeId) async {
    if (_currentBytecode == null) {
      throw StateError('Cannot apply delta: no base bytecode loaded');
    }
    final patched = _applyBsdiff(_currentBytecode!, delta);
    await loadBytecode(patched, bytecodeId);
  }

  /// Hot reload: tear down current runtime, start fresh with new bytecode.
  Future<HotReloadAckFrame> hotReload(HotReloadFrame frame) async {
    final stopwatch = Stopwatch()..start();

    try {
      await _disposeRuntime();
      if (_currentBytecode == null) {
        throw StateError('No bytecode to reload');
      }
      await _initRuntime(_currentBytecode!);
      stopwatch.stop();
      onReloadComplete(stopwatch.elapsedMilliseconds);

      return HotReloadAckFrame(
        bytecodeId: frame.bytecodeId,
        durationMs: stopwatch.elapsedMilliseconds,
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      return HotReloadAckFrame(
        bytecodeId: frame.bytecodeId,
        durationMs: stopwatch.elapsedMilliseconds,
        success: false,
        error: e.toString(),
      );
    }
  }

  // ── Runtime Lifecycle ─────────────────────────────────────────────────────

  Future<void> _initRuntime(Uint8List evc) async {
    // Real implementation:
    // _runtime = EvcRuntime.ofProgram(evc, plugins: pluginRegistry.all);
    // _interceptLogs();
    // await _runtime.executeLib('package:user_app/main.dart', 'main', []);

    // Placeholder:
    _log('Loading ${evc.length} bytes of bytecode...');
  }

  Future<void> _disposeRuntime() async {
    // await _runtime?.dispose();
    _runtime = null;
  }

  void _interceptLogs() {
    // Wrap dart:developer log + Zone to intercept print()
  }

  void _emitLog(LogLevel level, String message, {String? tag}) {
    onLogEmit(LogEmitFrame(
      deviceId: 'local', // replaced with real device ID in production
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
    ));
  }

  void _log(String msg) => _emitLog(LogLevel.debug, msg, tag: 'OoreRuntime');

  // ── Delta Patching ────────────────────────────────────────────────────────

  Uint8List _applyBsdiff(Uint8List base, Uint8List delta) {
    // Real implementation: use bsdiff/bspatch from package:archive or native
    throw UnimplementedError('bspatch not yet implemented');
  }

  // ── Disposal ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _disposeRuntime();
  }
}

// ── Plugin Registry ───────────────────────────────────────────────────────────

abstract class EvalPlugin {
  String get identifier;
  void configureForRuntime(dynamic runtime);
}

class PluginRegistry {
  final _plugins = <EvalPlugin>[];

  PluginRegistry register(EvalPlugin plugin) {
    _plugins.add(plugin);
    return this;
  }

  List<EvalPlugin> get all => List.unmodifiable(_plugins);

  bool supports(String packageUri) =>
      _plugins.any((p) => p.identifier == packageUri);
}

// ── Built-in Plugin Stubs ─────────────────────────────────────────────────────

class CameraPlugin extends EvalPlugin {
  @override
  String get identifier => 'package:camera/camera.dart';

  @override
  void configureForRuntime(dynamic runtime) {}
}

class SecureStoragePlugin extends EvalPlugin {
  @override
  String get identifier => 'package:flutter_secure_storage/flutter_secure_storage.dart';

  @override
  void configureForRuntime(dynamic runtime) {}
}

class BiometricsPlugin extends EvalPlugin {
  @override
  String get identifier => 'package:local_auth/local_auth.dart';

  @override
  void configureForRuntime(dynamic runtime) {}
}
