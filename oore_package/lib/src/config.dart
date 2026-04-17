import 'package:meta/meta.dart';

/// Configuration for the Oore Dev Server.
@immutable
class OoreConfig {
  const OoreConfig({
    this.port = 7777,
    this.watchPath = 'lib/',
    this.enableRemoteConsole = true,
    this.enableHotReload = true,
    this.enableDeltaPatch = true,
    this.debounceMs = 200,
    this.showQrInTerminal = true,
    this.relayUrl,
    this.minLauncherFlutterVersion = '3.22.0',
    this.logPath,
  });

  /// WebSocket server port.
  final int port;

  /// Directory to watch for source changes.
  final String watchPath;

  /// Relay remote console logs from devices to the terminal.
  final bool enableRemoteConsole;

  /// Push bytecode and trigger hot reload on file save.
  final bool enableHotReload;

  /// Use bsdiff delta patches instead of full bytecode pushes when smaller.
  final bool enableDeltaPatch;

  /// Milliseconds to debounce file change events.
  final int debounceMs;

  /// Display a QR code in the terminal for device pairing.
  final bool showQrInTerminal;

  /// Optional Phase 2: Oore Hub relay URL (e.g. wss://hub.oore.dev)
  final String? relayUrl;

  /// Warn if connected launcher was built with an older Flutter version.
  final String minLauncherFlutterVersion;

  /// Optional path to write rotating log file.
  final String? logPath;

  OoreConfig copyWith({
    int? port,
    String? watchPath,
    bool? enableRemoteConsole,
    bool? enableHotReload,
    bool? enableDeltaPatch,
    int? debounceMs,
    bool? showQrInTerminal,
    String? relayUrl,
    String? minLauncherFlutterVersion,
    String? logPath,
  }) {
    return OoreConfig(
      port: port ?? this.port,
      watchPath: watchPath ?? this.watchPath,
      enableRemoteConsole: enableRemoteConsole ?? this.enableRemoteConsole,
      enableHotReload: enableHotReload ?? this.enableHotReload,
      enableDeltaPatch: enableDeltaPatch ?? this.enableDeltaPatch,
      debounceMs: debounceMs ?? this.debounceMs,
      showQrInTerminal: showQrInTerminal ?? this.showQrInTerminal,
      relayUrl: relayUrl ?? this.relayUrl,
      minLauncherFlutterVersion:
          minLauncherFlutterVersion ?? this.minLauncherFlutterVersion,
      logPath: logPath ?? this.logPath,
    );
  }
}
