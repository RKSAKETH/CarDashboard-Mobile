import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/incident_service.dart';

// ─────────────────────────────────────────────────────────────
//  Screen — reads from IncidentService, no own accelerometer
// ─────────────────────────────────────────────────────────────

class IncidentLoggerScreen extends StatefulWidget {
  const IncidentLoggerScreen({super.key});

  @override
  State<IncidentLoggerScreen> createState() => _IncidentLoggerScreenState();
}

class _IncidentLoggerScreenState extends State<IncidentLoggerScreen>
    with TickerProviderStateMixin {
  // Live G-force from service stream
  double _gForce = 1.0;
  StreamSubscription<double>? _gSub;
  StreamSubscription<void>? _logSub;

  // Smooth needle animation
  late AnimationController _needleController;
  late Animation<double> _needleAnim;

  // ── Lifecycle ──────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _needleAnim = const AlwaysStoppedAnimation(0.0);

    // Subscribe to live G-force
    _gSub = IncidentService.instance.gForceStream.listen((g) {
      if (!mounted) return;
      final clamped = g.clamp(0.0, 5.0);
      setState(() => _gForce = clamped);
      _needleAnim = Tween<double>(
        begin: _needleAnim.value,
        end: clamped / 5.0,
      ).animate(
          CurvedAnimation(parent: _needleController, curve: Curves.easeOut));
      _needleController
        ..reset()
        ..forward();
    });

    // Rebuild when log changes
    _logSub = IncidentService.instance.logUpdateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _gSub?.cancel();
    _logSub?.cancel();
    _needleController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────

  Color _gForceColor(double g) {
    if (g < 1.5) return const Color(0xFF00E676);
    if (g < 2.5) return const Color(0xFFFFD600);
    if (g < 3.5) return const Color(0xFFFF6D00);
    return const Color(0xFFFF1744);
  }

  String _gLabel(double g) {
    if (g < 1.5) return 'NORMAL';
    if (g < 2.5) return 'ELEVATED';
    if (g < 3.5) return 'HIGH';
    return 'CRITICAL';
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final threshold = IncidentService.instance.threshold;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744).withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFFFF1744).withAlpha(90)),
              ),
              child: const Icon(Icons.shield,
                  color: Color(0xFFFF1744), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Black Box Logger',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Threshold chip
          GestureDetector(
            onTap: _showThresholdSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text('${threshold.toStringAsFixed(1)} G',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(),
            Expanded(flex: 5, child: Center(child: _buildGForceMeter())),
            _buildGReadout(),
            const SizedBox(height: 12),
            _buildIdleHint(threshold),
            const SizedBox(height: 8),
            Expanded(flex: 3, child: _buildIncidentLog()),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────

  Widget _buildStatusBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF00FF00),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF00FF00).withAlpha(140),
                    blurRadius: 8)
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text('MONITORING ACTIVE',
              style: TextStyle(
                  color: Color(0xFF00FF00),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1)),
          const Spacer(),
          const Icon(Icons.sensors, color: Colors.white38, size: 18),
          const SizedBox(width: 4),
          const Text('LIVE',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildGForceMeter() {
    return AnimatedBuilder(
      animation: _needleAnim,
      builder: (context, _) => CustomPaint(
        size: const Size(280, 280),
        painter: _GForceMeterPainter(
          gNormalized: _needleAnim.value,
          gForce: _gForce,
          threshold: IncidentService.instance.threshold / 5.0,
          accentColor: _gForceColor(_gForce),
        ),
      ),
    );
  }

  Widget _buildGReadout() {
    final color = _gForceColor(_gForce);
    return Column(
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: color,
            fontSize: 52,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            shadows: [Shadow(color: color.withAlpha(120), blurRadius: 20)],
          ),
          child: Text(_gForce.toStringAsFixed(2)),
        ),
        const Text('G-FORCE',
            style: TextStyle(
                color: Colors.white38, fontSize: 11, letterSpacing: 3)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Text(_gLabel(_gForce),
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
        ),
      ],
    );
  }

  Widget _buildIdleHint(double threshold) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Alert fires at ≥ ${threshold.toStringAsFixed(1)} G — works on all screens',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentLog() {
    final log = IncidentService.instance.log;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white38, size: 16),
                const SizedBox(width: 8),
                const Text('INCIDENT LOG',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 2)),
                const Spacer(),
                if (log.isNotEmpty)
                  Text('${log.length} event${log.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: log.isEmpty
                ? const Center(
                    child: Text('No incidents recorded',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 13)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: log.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, i) =>
                        _buildLogTile(log[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(IncidentRecord record) {
    final color = record.cancelled
        ? const Color(0xFF00E676)
        : const Color(0xFFFF1744);
    final icon =
        record.cancelled ? Icons.check_circle : Icons.phone_in_talk;
    final label =
        record.cancelled ? 'Cancelled by user' : 'Called 911';

    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: color.withAlpha(25), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 16),
      ),
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      subtitle: Text(
        '${record.peakG.toStringAsFixed(2)} G  •  ${_fmt(record.time)}',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('${record.peakG.toStringAsFixed(1)} G',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Threshold sheet ────────────────────────────────────────

  void _showThresholdSheet() {
    double temp = IncidentService.instance.threshold;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Impact Sensitivity',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                  'G-force threshold that triggers the emergency protocol.',
                  style:
                      TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Low  ',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: temp,
                      min: 1.5,
                      max: 5.0,
                      divisions: 14,
                      activeColor: const Color(0xFFFF1744),
                      inactiveColor: Colors.white12,
                      onChanged: (v) => set(() => temp = v),
                    ),
                  ),
                  const Text('  High',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
              Center(
                child: Text('${temp.toStringAsFixed(1)} G',
                    style: const TextStyle(
                        color: Color(0xFFFF1744),
                        fontSize: 32,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40)),
                  ),
                  onPressed: () {
                    IncidentService.instance.updateThreshold(temp);
                    setState(() {}); // refresh threshold chip
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime t) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
  }
}

// ─────────────────────────────────────────────────────────────
//  Custom painter – arc G-force meter (unchanged)
// ─────────────────────────────────────────────────────────────

class _GForceMeterPainter extends CustomPainter {
  final double gNormalized;
  final double gForce;
  final double threshold;
  final Color accentColor;

  _GForceMeterPainter({
    required this.gNormalized,
    required this.gForce,
    required this.threshold,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6);
    final radius = size.width * 0.42;
    const startAngle = pi * 0.75;
    const sweepTotal = pi * 1.5;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepTotal, false,
      Paint()
        ..color = Colors.white10
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );

    // Zone tints
    final zones = [
      (0.00, 0.30, const Color(0xFF00E676)),
      (0.30, 0.50, const Color(0xFFFFD600)),
      (0.50, 0.70, const Color(0xFFFF6D00)),
      (0.70, 1.00, const Color(0xFFFF1744)),
    ];
    for (final z in zones) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + sweepTotal * z.$1,
        sweepTotal * (z.$2 - z.$1), false,
        Paint()
          ..color = z.$3.withAlpha(50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Active sweep
    if (gNormalized > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepTotal * gNormalized, false,
        Paint()
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: startAngle,
            endAngle: startAngle + sweepTotal * gNormalized,
            colors: [const Color(0xFF00E676), accentColor],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round,
      );
    }

    // Threshold marker
    final ta = startAngle + sweepTotal * threshold;
    canvas.drawLine(
      center + Offset(cos(ta), sin(ta)) * (radius - 12),
      center + Offset(cos(ta), sin(ta)) * (radius + 12),
      Paint()
        ..color = const Color(0xFFFF1744)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Needle glow
    final na = startAngle + sweepTotal * gNormalized;
    final tip = center + Offset(cos(na), sin(na)) * (radius - 4);
    canvas.drawLine(center, tip,
        Paint()
          ..color = accentColor.withAlpha(60)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawLine(center, tip,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);

    // Pivot
    canvas.drawCircle(center, 10, Paint()..color = accentColor);
    canvas.drawCircle(center, 6, Paint()..color = Colors.white);

    // Labels
    for (int i = 0; i <= 5; i++) {
      final frac = i / 5.0;
      final a = startAngle + sweepTotal * frac;
      final pos = center + Offset(cos(a), sin(a)) * (radius + 28);
      final tp = TextPainter(
        text: TextSpan(
          text: '$i',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_GForceMeterPainter old) =>
      old.gNormalized != gNormalized || old.accentColor != accentColor;
}
