import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:light_sensor/light_sensor.dart';

// ─── Light Mode Enum ────────────────────────────────────────────────────────

/// Three perceptual lighting states used to adapt the cockpit UI.
///
/// | Mode    | Typical Lux  | UI Behaviour                               |
/// |---------|--------------|--------------------------------------------|
/// | day     | > 200 lux    | Bright high-contrast whites & greens       |
/// | twilight| 10 – 200 lux | Dimmed, softer yellows, reduced brightness |
/// | night   | < 10 lux     | Red-shifted cockpit mode (rhodopsin safe)  |
enum LightMode { day, twilight, night }

// ─── Lux Thresholds ─────────────────────────────────────────────────────────
// Chosen to match real-world automotive scenarios:
//   • Bright sunlight or open road     → >500 lux (day)
//   • Garage / dusk / overcast         → 10–200 lux (twilight)
//   • Dark car interior at night       → <10 lux  (night / red mode)
const double _kDayThreshold      = 200.0; // lux above which → day
const double _kTwilightThreshold = 10.0;  // lux below which → night

/// Hysteresis buffer: how far lux must move past a boundary before switching.
/// This prevents flicker when, e.g., a hand briefly covers the sensor.
const double _kHysteresis = 15.0;

/// Minimum time (ms) that must elapse before accepting a new mode transition.
/// Think of it as a "debounce" timer — a shadow passing in <600ms won't flip
/// the theme. Professional automotive HMI guidelines suggest 500–1500 ms.
const int _kSwitchDelayMs = 600;

// ─── Service ─────────────────────────────────────────────────────────────────

/// Singleton service that listens to the raw light sensor, smooths the signal,
/// applies hysteresis + time-delay logic, and exposes the derived [LightMode].
///
/// Usage:
/// ```dart
/// final svc = AmbientLightService.instance;
/// svc.start();
/// svc.onModeChanged = (mode) => setState(() => _mode = mode);
/// // later…
/// svc.stop();
/// ```
class AmbientLightService {
  AmbientLightService._();
  static final AmbientLightService instance = AmbientLightService._();

  // ── Public state ──
  LightMode _mode = LightMode.day;
  LightMode get currentMode => _mode;

  double _currentLux = 500.0; // Assume daylight on start-up
  double get currentLux => _currentLux;

  /// Called whenever the [LightMode] changes (with hysteresis applied).
  ValueChanged<LightMode>? onModeChanged;

  // ── Private state ──
  StreamSubscription<int>? _sub;
  Timer? _debounceTimer;
  LightMode? _pendingMode;
  bool _running = false;

  // Exponential moving-average factor for lux smoothing (0 < α ≤ 1).
  // Lower α = smoother but slower; 0.25 gives a good balance.
  static const double _kAlpha = 0.25;

  // ── Lifecycle ──

  /// Start listening to the ambient light sensor.
  Future<void> start() async {
    if (_running) return;

    try {
      final hasSensor = await LightSensor.hasSensor();
      if (!hasSensor) {
        debugPrint('[AmbientLight] No light sensor on this device — keeping default mode.');
        return;
      }

      _running = true;
      _sub = LightSensor.luxStream().listen(
        (lux) => _onRawLux(lux.toDouble()),
        onError: (dynamic e) => debugPrint('[AmbientLight] Stream error: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[AmbientLight] Could not start light sensor: $e');
    }
  }

  /// Stop listening and cancel pending timers.
  void stop() {
    _running = false;
    _sub?.cancel();
    _debounceTimer?.cancel();
    _sub = null;
    _debounceTimer = null;
  }

  // ── Core Logic ──

  /// Called on every new raw lux reading from the hardware sensor.
  void _onRawLux(double rawLux) {
    // 1. Exponential moving average to smooth out spikes.
    _currentLux = _kAlpha * rawLux + (1 - _kAlpha) * _currentLux;

    // 2. Determine the "candidate" mode using hysteresis offsets.
    final candidate = _classify(_currentLux);

    // 3. If candidate differs from current mode, start (or reset) the debounce
    //    timer. Only commit after _kSwitchDelayMs milliseconds of stability.
    if (candidate != _mode) {
      if (_pendingMode != candidate) {
        _pendingMode = candidate;
        _debounceTimer?.cancel();
        _debounceTimer = Timer(
          Duration(milliseconds: _kSwitchDelayMs),
          () => _commitMode(candidate),
        );
      }
    } else {
      // Lux returned to the current mode zone — cancel any pending switch.
      if (_pendingMode != null) {
        _pendingMode = null;
        _debounceTimer?.cancel();
      }
    }
  }

  /// Map smoothed lux to a [LightMode] with hysteresis.
  ///
  /// The hysteresis offsets make transitions "sticky":
  ///   • To move from night→day, lux must reach DayThreshold + Hysteresis.
  ///   • To move from day→night, lux must drop below DayThreshold - Hysteresis.
  LightMode _classify(double lux) {
    switch (_mode) {
      case LightMode.day:
        if (lux < _kDayThreshold - _kHysteresis) {
          return lux < _kTwilightThreshold - _kHysteresis
              ? LightMode.night
              : LightMode.twilight;
        }
        return LightMode.day;

      case LightMode.twilight:
        if (lux >= _kDayThreshold + _kHysteresis) return LightMode.day;
        if (lux < _kTwilightThreshold - _kHysteresis) return LightMode.night;
        return LightMode.twilight;

      case LightMode.night:
        if (lux >= _kTwilightThreshold + _kHysteresis) {
          return lux >= _kDayThreshold + _kHysteresis
              ? LightMode.day
              : LightMode.twilight;
        }
        return LightMode.night;
    }
  }

  void _commitMode(LightMode newMode) {
    if (!_running) return;
    _mode = newMode;
    _pendingMode = null;
    debugPrint('[AmbientLight] Mode → ${newMode.name}  (${_currentLux.toStringAsFixed(1)} lux)');
    onModeChanged?.call(newMode);
  }

  // ── Manual override (for testing / settings) ──

  /// Manually force a [LightMode], bypassing the sensor.
  /// Useful for the settings screen "simulate mode" UI.
  void forceMode(LightMode mode) {
    _debounceTimer?.cancel();
    _pendingMode = null;
    _mode = mode;
    debugPrint('[AmbientLight] Forced mode → ${mode.name}');
    onModeChanged?.call(mode);
  }
}
