import 'dart:math';
import 'package:flutter/material.dart';

class GaugeView extends StatelessWidget {
  final double speed;
  final int satellites;
  final bool hasGPS;

  const GaugeView({
    super.key,
    required this.speed,
    required this.satellites,
    required this.hasGPS,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(300, 300),
        painter: SpeedometerPainter(speed: speed),
      ),
    );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double speed;

  SpeedometerPainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Draw outer circle
    final outerPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.95, outerPaint);

    // Draw inner circle
    final innerPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.85, innerPaint);

    // Draw tick marks and labels
    for (int i = 0; i <= 100; i += 1) {
      final angle = (i / 100) * 180 - 180; // -180 to 0 degrees
      final radians = angle * pi / 180;

      final tickLength = i % 17 == 0 ? 20.0 : (i % 5 == 0 ? 12.0 : 6.0);
      final tickWidth = i % 17 == 0 ? 2.0 : 1.0;

      final startX = center.dx + (radius * 0.75) * cos(radians);
      final startY = center.dy + (radius * 0.75) * sin(radians);
      final endX = center.dx + (radius * 0.75 - tickLength) * cos(radians);
      final endY = center.dy + (radius * 0.75 - tickLength) * sin(radians);

      final tickPaint = Paint()
        ..color = Colors.white38
        ..strokeWidth = tickWidth;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);

      // Draw number labels
      if (i % 17 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: i.toString(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final labelX = center.dx + (radius * 0.6) * cos(radians) - textPainter.width / 2;
        final labelY = center.dy + (radius * 0.6) * sin(radians) - textPainter.height / 2;

        textPainter.paint(canvas, Offset(labelX, labelY));
      }
    }

    // Draw speed needle
    final currentSpeed = speed.clamp(0.0, 100.0);
    final needleAngle = (currentSpeed / 100) * 180 - 180;
    final needleRadians = needleAngle * pi / 180;

    final needlePath = Path();
    needlePath.moveTo(center.dx, center.dy);
    needlePath.lineTo(
      center.dx + (radius * 0.7) * cos(needleRadians),
      center.dy + (radius * 0.7) * sin(needleRadians),
    );

    final needlePaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(needlePath, needlePaint);

    // Draw center circle
    final centerCirclePaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, centerCirclePaint);

    final centerInnerPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, centerInnerPaint);

    // Draw speed text
    final speedText = TextPainter(
      text: TextSpan(
        text: speed.toInt().toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 64,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    speedText.layout();
    speedText.paint(
      canvas,
      Offset(
        center.dx - speedText.width / 2,
        center.dy + radius * 0.2,
      ),
    );

    // Draw km/h label
    final unitText = TextPainter(
      text: const TextSpan(
        text: 'km/h',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 18,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    unitText.layout();
    unitText.paint(
      canvas,
      Offset(
        center.dx - unitText.width / 2,
        center.dy + radius * 0.4,
      ),
    );
  }

  @override
  bool shouldRepaint(SpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed;
  }
}
