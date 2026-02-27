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
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
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
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: widget.isOverLimit ? _scaleAnim.value : 1.0,
          child: child,
        ),
        child: CustomPaint(
          size: const Size(320, 320),
          painter: _SpeedometerPainter(
            speed: widget.speed,
            isOverLimit: widget.isOverLimit,
            speedLimit: widget.speedLimit,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _SpeedometerPainter extends CustomPainter {
  final double speed;
  final bool isOverLimit;
  final int? speedLimit;

  static const double _maxSpeed = 160.0;

  // Arc spans 270° — from 135° (bottom-left) clockwise to 45° (bottom-right)
  static const double _startDeg = 135.0;
  static const double _sweepDeg = 270.0;

  _SpeedometerPainter({
    required this.speed,
    this.isOverLimit = false,
    this.speedLimit,
  });

  double _deg(double deg) => deg * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final r = min(cx, cy);

    // ── 1. Outer ring (dark grey) ──────────────────────────────────────────
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFF1C1C1E),
    );

    // ── 2. Outer border ring ───────────────────────────────────────────────
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..color = const Color(0xFF3A3A3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // ── 3. Track arc (background) ──────────────────────────────────────────
    final trackRect = Rect.fromCircle(center: center, radius: r * 0.82);
    canvas.drawArc(
      trackRect,
      _deg(_startDeg),
      _deg(_sweepDeg),
      false,
      Paint()
        ..color = const Color(0xFF2C2C2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt,
    );

    // ── 4. Speed sweep arc (red) ───────────────────────────────────────────
    final fraction = (speed / _maxSpeed).clamp(0.0, 1.0);
    if (fraction > 0) {
      final sweepColor = isOverLimit
          ? const Color(0xFFFF453A)  // bright red when over limit
          : const Color(0xFFFF3B30); // standard red sweep

      // Glow
      canvas.drawArc(
        trackRect,
        _deg(_startDeg),
        _deg(_sweepDeg * fraction),
        false,
        Paint()
          ..color = sweepColor.withAlpha(60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28
          ..strokeCap = StrokeCap.butt
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Main arc
      canvas.drawArc(
        trackRect,
        _deg(_startDeg),
        _deg(_sweepDeg * fraction),
        false,
        Paint()
          ..color = sweepColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.butt,
      );
    }

    // ── 5. Tick marks & labels ─────────────────────────────────────────────
    const majorStep = 20;           // label every 20 km/h
    const minorCount = 160;         // one tick per km/h step

    for (int i = 0; i <= minorCount; i++) {
      final v = (i / minorCount) * _maxSpeed;
      final angleDeg = _startDeg + (i / minorCount) * _sweepDeg;
      final rad = _deg(angleDeg);

      final isMajor = (v % majorStep < 0.01);
      final isMid   = (v % (majorStep / 2) < 0.01);

      final tickOuter = r * 0.82;
      final tickLen   = isMajor ? 16.0 : (isMid ? 10.0 : 5.0);
      final tickW     = isMajor ? 2.5 : (isMid ? 1.5 : 1.0);

      // Color: red for ticks beyond speed limit
      Color tickColor = Colors.white38;
      if (isOverLimit) {
        tickColor = v <= speed
            ? const Color(0xFFFF3B30)
            : Colors.white24;
      }

      final ox = cx + tickOuter * cos(rad);
      final oy = cy + tickOuter * sin(rad);
      final ix = cx + (tickOuter - tickLen) * cos(rad);
      final iy = cy + (tickOuter - tickLen) * sin(rad);

      canvas.drawLine(
        Offset(ox, oy),
        Offset(ix, iy),
        Paint()
          ..color = tickColor
          ..strokeWidth = tickW
          ..strokeCap = StrokeCap.round,
      );

      // Major labels
      if (isMajor) {
        final labelR = r * 0.63;
        final lx = cx + labelR * cos(rad);
        final ly = cy + labelR * sin(rad);

        final tp = TextPainter(
          text: TextSpan(
            text: v.toInt().toString(),
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(
          canvas,
          Offset(lx - tp.width / 2, ly - tp.height / 2),
        );
      }
    }

    // ── 6. White needle marker at current speed tip ────────────────────────
    if (fraction > 0) {
      final tipRad = _deg(_startDeg + _sweepDeg * fraction);
      canvas.drawLine(
        Offset(cx + r * 0.74 * cos(tipRad), cy + r * 0.74 * sin(tipRad)),
        Offset(cx + r * 0.90 * cos(tipRad), cy + r * 0.90 * sin(tipRad)),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── 7. Inner bubble ────────────────────────────────────────────────────
    // Gradient fill for depth
    final bubbleR = r * 0.56;
    final bubblePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [
          const Color(0xFF2C2C2E),
          const Color(0xFF1C1C1E),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: bubbleR),
      );
    canvas.drawCircle(center, bubbleR, bubblePaint);

    // Subtle rim on inner bubble
    canvas.drawCircle(
      center,
      bubbleR,
      Paint()
        ..color = Colors.white.withAlpha(20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── 8. Speed number ────────────────────────────────────────────────────
    final speedStr = speed.toInt().toString();
    final speedTp = TextPainter(
      text: TextSpan(
        text: speedStr,
        style: TextStyle(
          color: isOverLimit ? const Color(0xFFFF453A) : Colors.white,
          fontSize: 72,
          fontWeight: FontWeight.w700,
          letterSpacing: -2,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    speedTp.paint(
      canvas,
      Offset(cx - speedTp.width / 2, cy - speedTp.height / 2 - 8),
    );

    // ── 9. km/h label ─────────────────────────────────────────────────────
    final unitTp = TextPainter(
      text: const TextSpan(
        text: 'km/h',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    unitTp.paint(
      canvas,
      Offset(cx - unitTp.width / 2, cy + 38),
    );

    // ── 10. Speed limit badge (road-sign style) ────────────────────────────
    if (speedLimit != null) {
      _drawSpeedLimitBadge(canvas, center, r, speedLimit!, isOverLimit);
    }
  }

  void _drawSpeedLimitBadge(
    Canvas canvas,
    Offset center,
    double r,
    int limit,
    bool over,
  ) {
    // Position: bottom center of the gauge
    final badgeCx = center.dx;
    final badgeCy = center.dy + r * 0.78;

    const badgeW = 52.0;
    const badgeH = 58.0;
    const rx = 6.0;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(badgeCx, badgeCy),
          width: badgeW,
          height: badgeH),
      const Radius.circular(rx),
    );

    // White background
    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xFFD8D8D8),
    );

    // Dark border
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = const Color(0xFF444444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // "LIMIT" text
    final limitLabelTp = TextPainter(
      text: const TextSpan(
        text: 'LIMIT',
        style: TextStyle(
          color: Color(0xFF222222),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    limitLabelTp.paint(
      canvas,
      Offset(
        badgeCx - limitLabelTp.width / 2,
        badgeCy - badgeH / 2 + 6,
      ),
    );

    // Divider line
    canvas.drawLine(
      Offset(badgeCx - badgeW / 2 + 4, badgeCy - 4),
      Offset(badgeCx + badgeW / 2 - 4, badgeCy - 4),
      Paint()
        ..color = const Color(0xFF444444)
        ..strokeWidth = 1.5,
    );

    // Limit number
    final numTp = TextPainter(
      text: TextSpan(
        text: limit.toString(),
        style: TextStyle(
          color: over ? const Color(0xFFCC0000) : const Color(0xFF111111),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    numTp.paint(
      canvas,
      Offset(
        badgeCx - numTp.width / 2,
        badgeCy + 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) =>
      old.speed != speed ||
      old.isOverLimit != isOverLimit ||
      old.speedLimit != speedLimit;
}
