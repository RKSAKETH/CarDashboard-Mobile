import 'package:flutter/material.dart';

class DigitalView extends StatefulWidget {
  final double speed;
  final int satellites;
  final bool hasGPS;
  final bool isOverLimit;
  final int? speedLimit;

  const DigitalView({
    super.key,
    required this.speed,
    required this.satellites,
    required this.hasGPS,
    this.isOverLimit = false,
    this.speedLimit,
  });

  @override
  State<DigitalView> createState() => _DigitalViewState();
}

class _DigitalViewState extends State<DigitalView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(DigitalView old) {
    super.didUpdateWidget(old);
    if (widget.isOverLimit && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isOverLimit && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final displaySize = (screenHeight * 0.25).clamp(120.0, 200.0);

    final digitColor = widget.isOverLimit
        ? const Color(0xFFFF1744)
        : const Color(0xFF00FF00);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Digital number (blinks when over limit)
          AnimatedBuilder(
            animation: _opacity,
            builder: (_, child) => Opacity(
              opacity: widget.isOverLimit ? _opacity.value : 1.0,
              child: child,
            ),
            child: _DigitalNumber(
              number: widget.speed.toInt(),
              size: displaySize,
              color: digitColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'km/h',
            style: TextStyle(
              color: digitColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Speed limit indicator
          if (widget.speedLimit != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isOverLimit
                    ? const Color(0xFFFF1744).withAlpha(30)
                    : Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isOverLimit
                      ? const Color(0xFFFF1744)
                      : Colors.white30,
                  width: widget.isOverLimit ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Road sign circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                          color: Colors.red.shade700, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        widget.speedLimit.toString(),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize:
                              widget.speedLimit! >= 100 ? 11 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.isOverLimit
                            ? '⚠️ SLOW DOWN!'
                            : 'Speed Limit',
                        style: TextStyle(
                          color: widget.isOverLimit
                              ? const Color(0xFFFF1744)
                              : Colors.white70,
                          fontWeight: widget.isOverLimit
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${widget.speedLimit} km/h',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Digital Number ─────────────────────────────────────────────────────────────

class _DigitalNumber extends StatelessWidget {
  final int number;
  final double size;
  final Color color;

  const _DigitalNumber({
    required this.number,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.67, size),
      painter: SevenSegmentPainter(number: number, color: color),
    );
  }
}

// ── Seven Segment Painter ──────────────────────────────────────────────────────

class SevenSegmentPainter extends CustomPainter {
  final int number;
  final Color color;

  SevenSegmentPainter({required this.number, this.color = const Color(0xFF00FF00)});

  @override
  void paint(Canvas canvas, Size size) {
    final segmentPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = const Color(0xFF1A3A1A)
      ..style = PaintingStyle.fill;

    final segments = _getSegmentsForDigit(number);

    final width = size.width;
    final height = size.height;
    final segmentWidth = width * 0.15;
    final segmentHeight = height * 0.08;

    _drawHorizontalSegment(canvas, Offset(segmentWidth, 0),
        width - 2 * segmentWidth, segmentHeight,
        segments[0] ? segmentPaint : inactivePaint);

    _drawVerticalSegment(canvas, Offset(width - segmentWidth, segmentHeight),
        segmentWidth, height / 2 - segmentHeight * 1.5,
        segments[1] ? segmentPaint : inactivePaint);

    _drawVerticalSegment(
        canvas,
        Offset(width - segmentWidth, height / 2 + segmentHeight * 0.5),
        segmentWidth, height / 2 - segmentHeight * 1.5,
        segments[2] ? segmentPaint : inactivePaint);

    _drawHorizontalSegment(canvas, Offset(segmentWidth, height - segmentHeight),
        width - 2 * segmentWidth, segmentHeight,
        segments[3] ? segmentPaint : inactivePaint);

    _drawVerticalSegment(
        canvas, Offset(0, height / 2 + segmentHeight * 0.5),
        segmentWidth, height / 2 - segmentHeight * 1.5,
        segments[4] ? segmentPaint : inactivePaint);

    _drawVerticalSegment(canvas, Offset(0, segmentHeight),
        segmentWidth, height / 2 - segmentHeight * 1.5,
        segments[5] ? segmentPaint : inactivePaint);

    _drawHorizontalSegment(
        canvas, Offset(segmentWidth, height / 2 - segmentHeight / 2),
        width - 2 * segmentWidth, segmentHeight,
        segments[6] ? segmentPaint : inactivePaint);
  }

  void _drawHorizontalSegment(Canvas canvas, Offset position, double width,
      double height, Paint paint) {
    final path = Path();
    path.moveTo(position.dx + height / 2, position.dy);
    path.lineTo(position.dx + width - height / 2, position.dy);
    path.lineTo(position.dx + width, position.dy + height / 2);
    path.lineTo(position.dx + width - height / 2, position.dy + height);
    path.lineTo(position.dx + height / 2, position.dy + height);
    path.lineTo(position.dx, position.dy + height / 2);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawVerticalSegment(Canvas canvas, Offset position, double width,
      double height, Paint paint) {
    final path = Path();
    path.moveTo(position.dx, position.dy + width / 2);
    path.lineTo(position.dx + width / 2, position.dy);
    path.lineTo(position.dx + width, position.dy + width / 2);
    path.lineTo(position.dx + width, position.dy + height - width / 2);
    path.lineTo(position.dx + width / 2, position.dy + height);
    path.lineTo(position.dx, position.dy + height - width / 2);
    path.close();
    canvas.drawPath(path, paint);
  }

  List<bool> _getSegmentsForDigit(int digit) {
    switch (digit % 10) {
      case 0:
        return [true, true, true, true, true, true, false];
      case 1:
        return [false, true, true, false, false, false, false];
      case 2:
        return [true, true, false, true, true, false, true];
      case 3:
        return [true, true, true, true, false, false, true];
      case 4:
        return [false, true, true, false, false, true, true];
      case 5:
        return [true, false, true, true, false, true, true];
      case 6:
        return [true, false, true, true, true, true, true];
      case 7:
        return [true, true, true, false, false, false, false];
      case 8:
        return [true, true, true, true, true, true, true];
      case 9:
        return [true, true, true, true, false, true, true];
      default:
        return [false, false, false, false, false, false, false];
    }
  }

  @override
  bool shouldRepaint(SevenSegmentPainter old) =>
      old.number != number || old.color != color;
}
