import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'src/protocol/olp_client.dart';
import 'src/vm/oore_runtime.dart';
import 'src/hud/hud_overlay.dart';

void main() {
  runApp(const OoreGoApp());
}

class OoreGoApp extends StatelessWidget {
  const OoreGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oore Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'monospace', // Industrial feel
        colorSchemeSeed: const Color(0xFF00E5A0),
      ),
      home: const DiscoveryScreen(),
    );
  }
}

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _onScan(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      setState(() => _isScanning = false);
      _connect(barcode.rawValue!);
    }
  }

  void _connect(String qrData) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SessionScreen(qrData: qrData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: Stack(
        children: [
          // Background Radar Animation
          Positioned.fill(
            child: CustomPaint(
              painter: _RadarPainter(
                animation: _radarController,
                color: const Color(0xFF00E5A0).withOpacity(0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildHeader(),
                const Spacer(),
                _buildDiscoveryTarget(),
                const Spacer(),
                _buildFooter(),
                const SizedBox(height: 48),
              ],
            ),
          ),

          if (_isScanning) _buildScannerOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF00E5A0),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'OORE GO',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'SOVEREIGN INDUSTRIAL DISCOVERY',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryTarget() {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _isScanning = true),
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00E5A0).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating Ring
              RotationTransition(
                turns: _radarController,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5A0).withOpacity(0.4),
                      width: 2,
                      style: BorderStyle.none,
                    ),
                  ),
                  child: CustomPaint(painter: _DashedCirclePainter()),
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 64,
                    color: Color(0xFF00E5A0),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'PAIR DEVICE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Color(0xFF00E5A0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_tethering, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  'READY FOR OLP PUSH',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: MobileScanner(onDetect: _onScan),
            ),
            Container(
              padding: const EdgeInsets.all(32),
              color: Colors.black,
              child: SafeArea(
                top: false,
                child: OutlinedButton(
                  onPressed: () => setState(() => _isScanning = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ABORT SCAN', style: TextStyle(letterSpacing: 2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _RadarPainter({required this.animation, required this.color}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, (size.width / 8) * i * (1 + (animation.value * 0.1)), paint);
    }

    // Draw sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withOpacity(0), color],
        stops: const [0.75, 1.0],
        transform: GradientRotation(animation.value * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: size.width));

    canvas.drawCircle(center, size.width, sweepPaint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const double dashWidth = 5.0;
    const double dashSpace = 5.0;
    double currentAngle = 0.0;
    final double radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);

    while (currentAngle < 2 * math.pi) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        dashWidth / radius,
        false,
        paint,
      );
      currentAngle += (dashWidth + dashSpace) / radius;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.qrData});
  final String qrData;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  OlpClient? _client;
  OoreRuntime? _runtime;
  int _reloadCount = 0;
  LogEmitFrame? _lastLog;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  void _initConnection() {
    _client = OlpClient(
      host: 'localhost', 
      port: 7777,
      deviceInfo: const DeviceInfo(
        id: 'dev-wsl',
        name: 'WSL Industrial Runner',
        os: 'android',
        osVersion: '14',
        flutterEvalVersion: '3.41.7',
      ),
      sessionSecret: 'sovereign-key',
    );

    _runtime = OoreRuntime(
      onLogEmit: (log) {
        setState(() => _lastLog = log);
        _client?.sendLogEmit(log);
      },
      onReloadComplete: (ms) {
        setState(() => _reloadCount++);
      },
    );

    _client!.onBytecodeReceived = (bytes) => _runtime!.loadBytecode(bytes, 'remote');
    _client!.onHotReload = (frame) => _runtime!.hotReload(frame);
    _client!.connect();
  }

  @override
  void dispose() {
    _client?.disconnect();
    _runtime?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HudOverlay(
      connectionStatus: _client?.status ?? ConnectionStatus.disconnected,
      serverName: _client?.host ?? '...',
      projectName: 'Oore Build',
      reloadCount: _reloadCount,
      lastLog: _lastLog,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E5A0),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'INITIALIZING OORE RUNTIME',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'WAITING FOR BYTECOE PUSH...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 8,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
