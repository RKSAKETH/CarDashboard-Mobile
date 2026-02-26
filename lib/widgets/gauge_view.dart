import 'dart:math';
import 'package:flutter/material.dart';

class GaugeView extends StatefulWidget {
  final double speed;
  final int satellites;
  final bool hasGPS;
  final bool isOverLimit;
  final int? speedLimit;

  const GaugeView({
    super.key,
    required this.speed,
    required this.satellites,
    required this.hasGPS,
    this.isOverLimit = false,
    this.speedLimit,
  });

  @override
  State<GaugeView> createState() => _GaugeViewState();
}

class _GaugeViewState extends State<GaugeView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(GaugeView old) {
    super.didUpdateWidget(old);
    if (widget.isOverLimit && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isOverLimit && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Speedometer gauge with optional red pulse
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, child) => Transform.scale(
              scale: widget.isOverLimit ? _scaleAnim.value : 1.0,
              child: child,
            ),
            child: CustomPaint(
              size: const Size(300, 300),
              painter: SpeedometerPainter(
                speed: widget.speed,
                isOverLimit: widget.isOverLimit,
                speedLimit: widget.speedLimit,
              ),
            ),
          ),

          // Speed limit badge
          if (widget.speedLimit != null) ...[
            const SizedBox(height: 12),
            _SpeedLimitBadge(
              limit: widget.speedLimit!,
              isOver: widget.isOverLimit,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Speed Limit Badge ─────────────────────────────────────────────────────────

class _SpeedLimitBadge extends StatelessWidget {
  final int limit;
  final bool isOver;

  const _SpeedLimitBadge({required this.limit, required this.isOver});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isOver
            ? const Color(0xFFFF1744).withAlpha(30)
            : Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOver ? const Color(0xFFFF1744) : Colors.white38,
          width: isOver ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini road sign
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.red.shade700, width: 2),
            ),
            child: Center(
              child: Text(
                limit.toString(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOver ? '⚠ Over Limit' : 'Limit $limit km/h',
            style: TextStyle(
              color: isOver ? const Color(0xFFFF1744) : Colors.white70,
              fontSize: 13,
              fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Speedometer Painter ───────────────────────────────────────────────────────

class SpeedometerPainter extends CustomPainter {
  final double speed;
  final bool isOverLimit;
  final int? speedLimit;

  SpeedometerPainter({
    required this.speed,
    this.isOverLimit = false,
    this.speedLimit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // ── Background circles ──────────────────────────────────────────────────
    final outerPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.95, outerPaint);

    // Red glow when over limit
    if (isOverLimit) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFF1744).withAlpha(50)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(center, radius * 0.9, glowPaint);
    }

    final innerPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.85, innerPaint);

    // ── Speed limit zone arc (orange) ────────────────────────────────────────
    if (speedLimit != null) {
      final limitFraction = (speedLimit! / 100.0).clamp(0.0, 1.0);
      final limitAngle = limitFraction * pi; // 0 to π
      final arcPaint = Paint()
        ..color = const Color(0xFFFF6D00).withAlpha(100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.78),
        pi, // start at left
        limitAngle,
        false,
        arcPaint,
      );
    }

    // ── Tick marks and labels ────────────────────────────────────────────────
    for (int i = 0; i <= 100; i += 1) {
      final angle = (i / 100) * 180 - 180;
      final radians = angle * pi / 180;

      final tickLength = i % 17 == 0 ? 20.0 : (i % 5 == 0 ? 12.0 : 6.0);
      final tickWidth = i % 17 == 0 ? 2.0 : 1.0;

      final startX =
          center.dx + (radius * 0.75) * cos(radians);
      final startY =
          center.dy + (radius * 0.75) * sin(radians);
      final endX =
          center.dx + (radius * 0.75 - tickLength) * cos(radians);
      final endY =
          center.dy + (radius * 0.75 - tickLength) * sin(radians);

      Color tickColor = Colors.white38;
      if (speedLimit != null && i > speedLimit!) {
        tickColor = const Color(0xFFFF1744).withAlpha(140);
      }

      final tickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = tickWidth;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);

      if (i % 17 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: i.toString(),
            style: TextStyle(
              color: (speedLimit != null && i > speedLimit!)
                  ? const Color(0xFFFF6D00)
                  : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final labelX = center.dx +
            (radius * 0.6) * cos(radians) -
            textPainter.width / 2;
        final labelY = center.dy +
            (radius * 0.6) * sin(radians) -
            textPainter.height / 2;
        textPainter.paint(canvas, Offset(labelX, labelY));
      }
    }

    // ── Needle ───────────────────────────────────────────────────────────────
    final currentSpeed = speed.clamp(0.0, 100.0);
    final needleAngle = (currentSpeed / 100) * 180 - 180;
    final needleRadians = needleAngle * pi / 180;

    final needleColor =
        isOverLimit ? const Color(0xFFFF1744) : const Color(0xFF00FF00);

    // Needle shadow
    final needleShadowPaint = Paint()
      ..color = needleColor.withAlpha(80)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.65) * cos(needleRadians),
        center.dy + (radius * 0.65) * sin(needleRadians),
      ),
      needleShadowPaint,
    );

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.7) * cos(needleRadians),
        center.dy + (radius * 0.7) * sin(needleRadians),
      ),
      needlePaint,
    );

    // ── Center circle ────────────────────────────────────────────────────────
    canvas.drawCircle(
        center, 12, Paint()..color = needleColor);
    canvas.drawCircle(
        center, 6, Paint()..color = const Color(0xFF1A1A1A));

    // ── Speed text ───────────────────────────────────────────────────────────
    final speedText = TextPainter(
      text: TextSpan(
        text: speed.toInt().toString(),
        style: TextStyle(
          color: isOverLimit ? const Color(0xFFFF1744) : Colors.white,
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

    // ── km/h label ───────────────────────────────────────────────────────────
    final unitText = TextPainter(
      text: const TextSpan(
        text: 'km/h',
        style: TextStyle(color: Colors.white70, fontSize: 18),
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
  bool shouldRepaint(SpeedometerPainter old) =>
      old.speed != speed ||
      old.isOverLimit != isOverLimit ||
      old.speedLimit != speedLimit;
}
