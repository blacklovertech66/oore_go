import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oore_flutter/oore_flutter.dart';
import '../protocol/olp_client.dart';

/// Industrial HUD overlay displayed on top of the running user app.
///
/// Shows:
/// - Connection status (server name, project)
/// - FPS counter
/// - Memory usage
/// - Reload count
/// - Last log line
///
/// Toggle with 3-finger long press. Drag to reposition.
class HudOverlay extends StatefulWidget {
  const HudOverlay({
    super.key,
    required this.child,
    required this.connectionStatus,
    required this.serverName,
    required this.projectName,
    required this.reloadCount,
    required this.lastLog,
  });

  final Widget child;
  final ConnectionStatus connectionStatus;
  final String serverName;
  final String projectName;
  final int reloadCount;
  final LogEmitFrame? lastLog;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> with TickerProviderStateMixin {
  bool _visible = true;
  Offset _position = const Offset(16, 60);
  double _fps = 0;
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();

  late final Ticker _fpsTicker;

  @override
  void initState() {
    super.initState();
    _fpsTicker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _frameCount++;
    final now = DateTime.now();
    final diff = now.difference(_lastFpsTime).inMilliseconds;
    if (diff >= 500) {
      if (mounted) {
        setState(() {
          _fps = (_frameCount * 1000) / diff;
          _frameCount = 0;
          _lastFpsTime = now;
        });
      }
    }
  }

  @override
  void dispose() {
    _fpsTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        setState(() => _visible = !_visible);
        HapticFeedback.mediumImpact();
      },
      child: Stack(
        children: [
          widget.child,
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _visible ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_visible,
              child: Stack(
                children: [
                  Positioned(
                    left: _position.dx,
                    top: _position.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _position = Offset(
                            (_position.dx + details.delta.dx).clamp(0,
                                MediaQuery.of(context).size.width - 240),
                            (_position.dy + details.delta.dy).clamp(0,
                                MediaQuery.of(context).size.height - 100),
                          );
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: _HudWidget(
                            connectionStatus: widget.connectionStatus,
                            serverName: widget.serverName,
                            projectName: widget.projectName,
                            fps: _fps,
                            reloadCount: widget.reloadCount,
                            lastLog: widget.lastLog,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudWidget extends StatelessWidget {
  const _HudWidget({
    required this.connectionStatus,
    required this.serverName,
    required this.projectName,
    required this.fps,
    required this.reloadCount,
    required this.lastLog,
  });

  final ConnectionStatus connectionStatus;
  final String serverName;
  final String projectName;
  final double fps;
  final int reloadCount;
  final LogEmitFrame? lastLog;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.82),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _statusColor.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: Row(
              children: [
                _StatusDot(color: _statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'OORE  $serverName  $projectName',
                    style: _mono(10, _statusColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _Stat(label: 'FPS', value: fps.toStringAsFixed(0)),
                const SizedBox(width: 12),
                _Stat(label: 'RELOAD', value: reloadCount.toString()),
                const SizedBox(width: 12),
                _Stat(label: 'STATUS', value: _statusLabel),
              ],
            ),
          ),
          if (lastLog != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
              ),
              child: Text(
                '[${lastLog!.level.name.toUpperCase()}] ${lastLog!.message}',
                style: _mono(9, _logColor(lastLog!.level)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Color get _statusColor {
    return switch (connectionStatus) {
      ConnectionStatus.authenticated => const Color(0xFF00E5A0),
      ConnectionStatus.connected => const Color(0xFF0096FF),
      ConnectionStatus.connecting => const Color(0xFFF5C542),
      ConnectionStatus.error => const Color(0xFFFF5E57),
      ConnectionStatus.disconnected => const Color(0xFF5A6A7E),
    };
  }

  String get _statusLabel {
    return switch (connectionStatus) {
      ConnectionStatus.authenticated => 'LIVE',
      ConnectionStatus.connected => 'CONN',
      ConnectionStatus.connecting => 'WAIT',
      ConnectionStatus.error => 'ERR',
      ConnectionStatus.disconnected => 'OFF',
    };
  }

  Color _logColor(LogLevel level) {
    return switch (level) {
      LogLevel.error => const Color(0xFFFF5E57),
      LogLevel.warn => const Color(0xFFF5C542),
      LogLevel.info => const Color(0xFF00E5A0),
      LogLevel.debug => const Color(0xFF5A6A7E),
    };
  }

  TextStyle _mono(double size, Color color) => TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        color: color,
        letterSpacing: 0.5,
        height: 1.3,
      );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 7,
              color: Color(0xFF5A6A7E),
              letterSpacing: 0.8,
            )),
        Text(value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.bold,
            )),
      ],
    );
  }
}
