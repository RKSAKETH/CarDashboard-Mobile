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
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;

  late AnimationController _speedController;
  late Animation<double> _speedAnim;
  double _currentSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.speed;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Calm breathing glow animation when idle
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    
    // Always pulse when idle, but we can change frequency if over limit
    _pulseController.repeat(reverse: true);

    _speedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _speedAnim = Tween<double>(begin: _currentSpeed, end: _currentSpeed).animate(
      CurvedAnimation(parent: _speedController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(GaugeView old) {
    super.didUpdateWidget(old);
    
    // Smooth speed transition
    if (old.speed != widget.speed) {
      _speedAnim = Tween<double>(
        begin: _speedAnim.value, 
        end: widget.speed
      ).animate(CurvedAnimation(
        parent: _speedController, 
        curve: Curves.easeOutCubic,
      ));
      _speedController.forward(from: 0.0);
    }
    
    if (widget.isOverLimit && !old.isOverLimit) {
      _pulseController.duration = const Duration(milliseconds: 400);
      _pulseController.repeat(reverse: true);
    } else if (!widget.isOverLimit && old.isOverLimit) {
      _pulseController.duration = const Duration(milliseconds: 1500);
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _speedController]),
          builder: (_, child) {
            final s = _speedAnim.value;
            return Transform.scale(
              scale: widget.isOverLimit ? (_scaleAnim.value + 0.01) : _scaleAnim.value,
              child: CustomPaint(
                size: const Size(320, 320),
                painter: _SpeedometerPainter(
                  speed: s,
                  isOverLimit: widget.isOverLimit,
                  speedLimit: widget.speedLimit,
                  pulseValue: _scaleAnim.value - 1.0,
                ),
              ),
            );
          },
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
  final double pulseValue;

  static const double _maxSpeed = 160.0;
  static const double _startDeg = 135.0;
  static const double _sweepDeg = 270.0;

  // Reusable paint objects to avoid allocation in paint()
  final _outerRingPaint = Paint()..style = PaintingStyle.fill;
  final _outerBorderPaint = Paint()
    ..color = const Color(0xFF3A3A3C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _trackPaint = Paint()
    ..color = const Color(0xFF2C2C2E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 18
    ..strokeCap = StrokeCap.butt;
  final _sweepPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 18
    ..strokeCap = StrokeCap.butt;
  final _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  final _tickPaint = Paint()..strokeCap = StrokeCap.round;
  final _needlePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final _bubbleRimPaint = Paint()
    ..color = Colors.white.withAlpha(20)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  _SpeedometerPainter({
    required this.speed,
    this.isOverLimit = false,
    this.speedLimit,
    this.pulseValue = 0.0,
  });

  double _deg(double deg) => deg * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final r = min(cx, cy);

    final rect = Rect.fromCircle(center: center, radius: r);

    // ── 1. Outer ring ──
    _outerRingPaint.shader = const RadialGradient(
      colors: [Color(0xFF1A1B22), Color(0xFF101014)],
    ).createShader(rect);
    canvas.drawCircle(center, r, _outerRingPaint);
    canvas.drawCircle(center, r - 1, _outerBorderPaint);

    // ── 3. Track arc ──
    final trackR = r * 0.82;
    final trackRect = Rect.fromCircle(center: center, radius: trackR);
    canvas.drawArc(trackRect, _deg(_startDeg), _deg(_sweepDeg), false, _trackPaint);

    // ── 4. Speed sweep ──
    final fraction = (speed / _maxSpeed).clamp(0.0, 1.0);
    final speedGlowIntensity = fraction * 0.5 + pulseValue * 15;
    
    if (fraction > 0) {
      final sweepColor = isOverLimit ? const Color(0xFFFF3B3B) : const Color(0xFF00FF88);
      
      _glowPaint.color = sweepColor.withValues(alpha: (0.4 + speedGlowIntensity * 0.2).clamp(0.0, 1.0));
      _glowPaint.strokeWidth = 28 + (speedGlowIntensity * 5);
      canvas.drawArc(trackRect, _deg(_startDeg), _deg(_sweepDeg * fraction), false, _glowPaint);

      _sweepPaint.color = sweepColor;
      canvas.drawArc(trackRect, _deg(_startDeg), _deg(_sweepDeg * fraction), false, _sweepPaint);
    }

    // ── 5. Ticks ──
    const minorCount = 160;
    for (int i = 0; i <= minorCount; i++) {
      final v = (i / minorCount) * _maxSpeed;
      final angleRad = _deg(_startDeg + (i / minorCount) * _sweepDeg);

      final isMajor = i % 20 == 0;
      final isMid   = i % 10 == 0;

      final tickOuter = r * 0.82;
      final tickLen   = isMajor ? 16.0 : (isMid ? 10.0 : 5.0);
      
      _tickPaint.color = v <= speed 
          ? (isOverLimit ? const Color(0xFFFF3B3B) : const Color(0xFF00FF88))
          : Colors.white24;
      _tickPaint.strokeWidth = isMajor ? 2.5 : (isMid ? 1.5 : 1.0);

      final cosA = cos(angleRad);
      final sinA = sin(angleRad);
      
      canvas.drawLine(
        Offset(cx + tickOuter * cosA, cy + tickOuter * sinA),
        Offset(cx + (tickOuter - tickLen) * cosA, cy + (tickOuter - tickLen) * sinA),
        _tickPaint,
      );

      if (isMajor) {
        _drawMajorLabel(canvas, cx, cy, r, angleRad, v.toInt());
      }
    }

    // ── 6. Needle ──
    if (fraction > 0) {
      final tipRad = _deg(_startDeg + _sweepDeg * fraction);
      canvas.drawLine(
        Offset(cx + r * 0.74 * cos(tipRad), cy + r * 0.74 * sin(tipRad)),
        Offset(cx + r * 0.90 * cos(tipRad), cy + r * 0.90 * sin(tipRad)),
        _needlePaint,
      );
    }

    // ── 7. Inner bubble ──
    final bubbleR = r * 0.56;
    final bubblePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [Color(0xFF1E1F26), Color(0xFF14151A)],
      ).createShader(Rect.fromCircle(center: center, radius: bubbleR));
    canvas.drawCircle(center, bubbleR, bubblePaint);
    canvas.drawCircle(center, bubbleR, _bubbleRimPaint);

    // ── 8. Text ──
    _drawSpeedText(canvas, cx, cy, isOverLimit, speedGlowIntensity);
    
    if (speedLimit != null) {
      _drawSpeedLimitBadge(canvas, center, r, speedLimit!, isOverLimit);
    }
  }

  void _drawMajorLabel(Canvas canvas, double cx, double cy, double r, double rad, int val) {
    final labelR = r * 0.63;
    final tp = TextPainter(
      text: TextSpan(
        text: val.toString(),
        style: TextStyle(
          color: Colors.white.withAlpha(200),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(cx + labelR * cos(rad) - tp.width / 2, cy + labelR * sin(rad) - tp.height / 2));
  }

  void _drawSpeedText(Canvas canvas, double cx, double cy, bool over, double intensity) {
    final speedStr = speed.toInt().toString();
    final speedTp = TextPainter(
      text: TextSpan(
        text: speedStr,
        style: TextStyle(
          color: over ? const Color(0xFFFF3B3B) : Colors.white,
          fontSize: 76,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          letterSpacing: -1.5,
          height: 1,
          shadows: [
            Shadow(
              color: over ? const Color(0xFFFF3B3B).withAlpha(150) : const Color(0xFF00FF88).withAlpha(100),
              blurRadius: 18 + intensity * 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    speedTp.paint(canvas, Offset(cx - speedTp.width / 2, cy - speedTp.height / 2 - 8));

    final unitTp = TextPainter(
      text: const TextSpan(
        text: 'km/h',
        style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unitTp.paint(canvas, Offset(cx - unitTp.width / 2, cy + 38));
  }

  void _drawSpeedLimitBadge(Canvas canvas, Offset center, double r, int limit, bool over) {
    final badgeCx = center.dx;
    final badgeCy = center.dy + r * 0.78;
    const badgeW = 52.0;
    const badgeH = 58.0;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(badgeCx, badgeCy), width: badgeW, height: badgeH),
      const Radius.circular(6.0),
    );

    canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFF1E1F26).withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
    canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFF14151A).withValues(alpha: 0.8));
    canvas.drawRRect(badgeRect, Paint()..color = Colors.white.withAlpha(30)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final limitLabelTp = TextPainter(
      text: const TextSpan(text: 'LIMIT', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    limitLabelTp.paint(canvas, Offset(badgeCx - limitLabelTp.width / 2, badgeCy - badgeH / 2 + 6));

    canvas.drawLine(Offset(badgeCx - badgeW / 2 + 4, badgeCy - 4), Offset(badgeCx + badgeW / 2 - 4, badgeCy - 4), Paint()..color = const Color(0xFF444444)..strokeWidth = 1.5);

    final numTp = TextPainter(
      text: TextSpan(text: limit.toString(), style: TextStyle(color: over ? const Color(0xFFFF7A00) : Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter', height: 1, shadows: [if (over) Shadow(color: const Color(0xFFFF7A00).withAlpha(180), blurRadius: 8)])),
      textDirection: TextDirection.ltr,
    )..layout();
    numTp.paint(canvas, Offset(badgeCx - numTp.width / 2, badgeCy + 2));
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) =>
      old.speed != speed || old.isOverLimit != isOverLimit || old.speedLimit != speedLimit || old.pulseValue != pulseValue;
}
