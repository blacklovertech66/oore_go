import 'package:flutter/material.dart';

class PerformanceGraph extends StatelessWidget {
  const PerformanceGraph({
    super.key,
    required this.values,
    required this.color,
    this.maxValue = 60,
  });

  final List<double> values;
  final Color color;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(60, 24),
      painter: _GraphPainter(
        values: values,
        color: color,
        maxValue: maxValue,
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double maxValue;

  _GraphPainter({
    required this.values,
    required this.color,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final xStep = size.width / 60; // Show last 60 points

    for (var i = 0; i < values.length; i++) {
      final x = i * xStep;
      final y = size.height - (values[i] / maxValue * size.height).clamp(0, size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw gradient fill
    final fillPath = Path.from(path)
      ..lineTo(values.length * xStep, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}
