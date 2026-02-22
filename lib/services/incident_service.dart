import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'accelerometer_service.dart';

/// Assign this to MaterialApp.navigatorKey — lets the service
/// show overlays from any route without a BuildContext.
final GlobalKey<NavigatorState> incidentNavigatorKey =
    GlobalKey<NavigatorState>();

// ─────────────────────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────────────────────

class IncidentRecord {
  final DateTime time;
  final double peakG;
  final bool cancelled;

  const IncidentRecord({
    required this.time,
    required this.peakG,
    required this.cancelled,
  });
}

// ─────────────────────────────────────────────────────────────
//  Singleton service
// ─────────────────────────────────────────────────────────────

class IncidentService {
  static final IncidentService instance = IncidentService._();
  IncidentService._();

  AccelerometerService? _accel;
  bool _running = false;
  bool _incidentActive = false;

  double _threshold = 2.5;
  double get threshold => _threshold;

  double currentGForce = 1.0;
  final List<IncidentRecord> log = [];

  // Broadcast streams ─ any widget can listen
  final _gForceCtrl = StreamController<double>.broadcast();
  Stream<double> get gForceStream => _gForceCtrl.stream;

  final _logCtrl = StreamController<void>.broadcast();
  Stream<void> get logUpdateStream => _logCtrl.stream;

  // ── Lifecycle ──────────────────────────────────────────────

  void start() {
    if (_running) return;
    _running = true;
    _buildAccel();
  }

  void stop() {
    _running = false;
    _accel?.stop();
    _accel = null;
  }

  void updateThreshold(double t) {
    _threshold = t;
    if (_running) {
      _accel?.stop();
      _buildAccel();
    }
  }

  void _buildAccel() {
    _accel = AccelerometerService(
      threshold: _threshold,
      onGForceUpdate: (g) {
        currentGForce = g;
        if (!_gForceCtrl.isClosed) _gForceCtrl.add(g);
      },
      onImpactDetected: (peakG) {
        if (_incidentActive) return;
        _incidentActive = true;
        _showGlobalOverlay(peakG);
      },
    );
    _accel!.start();
  }

  // ── Global overlay (works from any screen) ─────────────────

  void _showGlobalOverlay(double peakG) {
    final ctx = incidentNavigatorKey.currentContext;
    if (ctx == null) {
      _incidentActive = false;
      return;
    }
    showGeneralDialog(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, a1, a2) => IncidentAlertPage(
        peakG: peakG,
        onClose: (record) {
          _incidentActive = false;
          log.insert(0, record);
          if (!_logCtrl.isClosed) _logCtrl.add(null);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Full-screen alert page (shown above any route)
// ─────────────────────────────────────────────────────────────

class IncidentAlertPage extends StatefulWidget {
  final double peakG;
  final void Function(IncidentRecord) onClose;

  const IncidentAlertPage({
    super.key,
    required this.peakG,
    required this.onClose,
  });

  @override
  State<IncidentAlertPage> createState() => _IncidentAlertPageState();
}

class _IncidentAlertPageState extends State<IncidentAlertPage>
    with SingleTickerProviderStateMixin {
  int _countdown = 10;
  Timer? _timer;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _callEmergency();
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    widget.onClose(IncidentRecord(
      time: DateTime.now(),
      peakG: widget.peakG,
      cancelled: true,
    ));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _callEmergency() async {
    _timer?.cancel();
    final uri = Uri(scheme: 'tel', path: '911');
    bool launched = false;

    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error launching dialer: $e');
    }

    // Record the incident (whether or not the call actually opened)
    widget.onClose(IncidentRecord(
      time: DateTime.now(),
      peakG: widget.peakG,
      cancelled: false,
    ));

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      if (!launched) {
        // Fallback: show the number visibly so user can dial manually
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Could not open dialer. Please call 911 manually.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Color(0xFFFF1744),
            duration: Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _countdown / 10.0;
    final ringColor = Color.lerp(
      const Color(0xFFFF1744),
      const Color(0xFFFFD600),
      progress,
    )!;

    return Material(
      color: Colors.black.withAlpha(235),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing icon
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) => Transform.scale(
                  scale: 1.0 + _pulseCtrl.value * 0.12,
                  child: child,
                ),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF1744).withAlpha(25),
                    border:
                        Border.all(color: const Color(0xFFFF1744), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withAlpha(120),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.warning_rounded,
                      color: Color(0xFFFF1744), size: 58),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'INCIDENT DETECTED!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF1744),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: Color(0xFFFF1744), blurRadius: 20)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Peak impact: ${widget.peakG.toStringAsFixed(2)} G',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 36),
              // Countdown ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const Text('sec',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Calling emergency services automatically',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 36),
              // I AM SAFE button
              GestureDetector(
                onTap: _cancel,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF00C853), Color(0xFF00897B)]),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C853).withAlpha(120),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'I AM SAFE  /  CANCEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _callEmergency,
                child: const Text(
                  'Call 911 now →',
                  style: TextStyle(
                    color: Color(0xFFFF1744),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFFF1744),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
