import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Listens to the device accelerometer, calculates total G-force magnitude,
/// and fires [onImpactDetected] when a sudden high-G event occurs.
class AccelerometerService {
  static const double _gravityMs2 = 9.81;

  // Threshold in Gs that triggers an incident (default: 2.5 G)
  final double threshold;

  // Cooldown so repeated shakes don't fire the callback multiple times
  final Duration cooldown;

  final void Function(double gForce) onGForceUpdate;
  final void Function(double peakG) onImpactDetected;

  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastTrigger;

  AccelerometerService({
    this.threshold = 2.5,
    this.cooldown = const Duration(seconds: 5),
    required this.onGForceUpdate,
    required this.onImpactDetected,
  });

  void start() {
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_handleEvent);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handleEvent(AccelerometerEvent event) {
    // Magnitude of acceleration vector in m/s²
    final magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Convert to G-force (1 G ≈ 9.81 m/s²)
    final gForce = magnitude / _gravityMs2;

    onGForceUpdate(gForce);

    final now = DateTime.now();
    final inCooldown =
        _lastTrigger != null && now.difference(_lastTrigger!) < cooldown;

    if (gForce >= threshold && !inCooldown) {
      _lastTrigger = now;
      onImpactDetected(gForce);
    }
  }

  void dispose() => stop();
}
