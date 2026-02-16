import 'package:flutter/material.dart';

class DigitalView extends StatelessWidget {
  final double speed;
  final int satellites;
  final bool hasGPS;

  const DigitalView({
    super.key,
    required this.speed,
    required this.satellites,
    required this.hasGPS,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Make it more compact to avoid overflow
    final displaySize = (screenHeight * 0.25).clamp(120.0, 200.0);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Digital speed display
          _DigitalNumber(
            number: speed.toInt(),
            size: displaySize,
          ),
          const SizedBox(height: 12),
          const Text(
            'km/h',
            style: TextStyle(
              color: Color(0xFF00FF00),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DigitalNumber extends StatelessWidget {
  final int number;
  final double size;

  const _DigitalNumber({
    required this.number,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.67, size),
      painter: SevenSegmentPainter(number: number),
    );
  }
}

class SevenSegmentPainter extends CustomPainter {
  final int number;

  SevenSegmentPainter({required this.number});

  @override
  void paint(Canvas canvas, Size size) {
    final segmentPaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = const Color(0xFF1A3A1A)
      ..style = PaintingStyle.fill;

    // Define which segments are active for each digit
    final segments = _getSegmentsForDigit(number);

    final width = size.width;
    final height = size.height;
    final segmentWidth = width * 0.15;
    final segmentHeight = height * 0.08;

    // Draw the 7-segment display
    // Top segment (a)
    _drawHorizontalSegment(
      canvas,
      Offset(segmentWidth, 0),
      width - 2 * segmentWidth,
      segmentHeight,
      segments[0] ? segmentPaint : inactivePaint,
    );

    // Top right segment (b)
    _drawVerticalSegment(
      canvas,
      Offset(width - segmentWidth, segmentHeight),
      segmentWidth,
      height / 2 - segmentHeight * 1.5,
      segments[1] ? segmentPaint : inactivePaint,
    );

    // Bottom right segment (c)
    _drawVerticalSegment(
      canvas,
      Offset(width - segmentWidth, height / 2 + segmentHeight * 0.5),
      segmentWidth,
      height / 2 - segmentHeight * 1.5,
      segments[2] ? segmentPaint : inactivePaint,
    );

    // Bottom segment (d)
    _drawHorizontalSegment(
      canvas,
      Offset(segmentWidth, height - segmentHeight),
      width - 2 * segmentWidth,
      segmentHeight,
      segments[3] ? segmentPaint : inactivePaint,
    );

    // Bottom left segment (e)
    _drawVerticalSegment(
      canvas,
      Offset(0, height / 2 + segmentHeight * 0.5),
      segmentWidth,
      height / 2 - segmentHeight * 1.5,
      segments[4] ? segmentPaint : inactivePaint,
    );

    // Top left segment (f)
    _drawVerticalSegment(
      canvas,
      Offset(0, segmentHeight),
      segmentWidth,
      height / 2 - segmentHeight * 1.5,
      segments[5] ? segmentPaint : inactivePaint,
    );

    // Middle segment (g)
    _drawHorizontalSegment(
      canvas,
      Offset(segmentWidth, height / 2 - segmentHeight / 2),
      width - 2 * segmentWidth,
      segmentHeight,
      segments[6] ? segmentPaint : inactivePaint,
    );
  }

  void _drawHorizontalSegment(Canvas canvas, Offset position, double width, double height, Paint paint) {
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

  void _drawVerticalSegment(Canvas canvas, Offset position, double width, double height, Paint paint) {
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
    // Returns [a, b, c, d, e, f, g] segment states
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
  bool shouldRepaint(SevenSegmentPainter oldDelegate) {
    return oldDelegate.number != number;
  }
}
