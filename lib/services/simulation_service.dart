import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Drives a virtual car along a list of [LatLng] waypoints.
///
/// Emits synthetic [Position] objects on [positionStream] that are
/// indistinguishable from real GPS positions – so the rest of the
/// app (SpeedLimitService, MapView, stats …) works unchanged.
class SimulationService {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _controller.stream;

  // ── State ──────────────────────────────────────────────────────────────────

  List<LatLng> _waypoints = [];
  int _waypointIndex = 0;

  /// Target speed the user selected via slider (km/h).
  double _targetSpeedKmh = 30.0;

  double get targetSpeedKmh => _targetSpeedKmh;
  set targetSpeedKmh(double v) => _targetSpeedKmh = v.clamp(0, 200);

  bool _running = false;
  bool get isRunning => _running;

  Timer? _ticker;

  // Current simulated position
  double _lat = 0;
  double _lng = 0;
  double _heading = 0; // degrees

  // Callbacks
  VoidCallback? onRouteCompleted;

  // ── API ────────────────────────────────────────────────────────────────────

  /// Start simulation along [waypoints].
  /// Call with route.polylinePoints (or any LatLng list).
  void startRoute(List<LatLng> waypoints, {double initialSpeedKmh = 30}) {
    if (waypoints.isEmpty) return;
    stop();

    _waypoints = List.from(waypoints);
    _waypointIndex = 0;
    _targetSpeedKmh = initialSpeedKmh;
    _lat = waypoints.first.latitude;
    _lng = waypoints.first.longitude;
    _running = true;

    // Tick every 100 ms for smooth movement
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
    debugPrint('[Sim] Route started with ${waypoints.length} waypoints');
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    debugPrint('[Sim] Stopped');
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _tick(Timer t) {
    if (!_running || _waypoints.isEmpty) return;
    if (_waypointIndex >= _waypoints.length - 1) {
      // End of route
      stop();
      onRouteCompleted?.call();
      return;
    }

    final target = _waypoints[_waypointIndex + 1];

    // Distance remaining to next waypoint (metres)
    final distRemaining = _haversine(_lat, _lng, target.latitude, target.longitude);

    // Speed in m/s, then distance covered in 100 ms
    final speedMs = (_targetSpeedKmh / 3.6);
    final stepDist = speedMs * 0.1; // 100 ms = 0.1 s

    if (stepDist >= distRemaining) {
      // Snap to waypoint and advance
      _lat = target.latitude;
      _lng = target.longitude;
      _waypointIndex++;
    } else {
      // Move towards target
      final ratio = stepDist / distRemaining;
      _lat += (target.latitude - _lat) * ratio;
      _lng += (target.longitude - _lng) * ratio;
    }

    // Heading (degrees)
    _heading = _bearing(_lat, _lng, target.latitude, target.longitude);

    // Emit a synthetic Position
    _controller.add(_makePosition(_lat, _lng, speedMs, _heading));
  }

  Position _makePosition(double lat, double lng, double speedMs, double heading) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 3.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
      speed: speedMs,
      speedAccuracy: 0.0,
      heading: heading,
    );
  }

  // ── Geometry ───────────────────────────────────────────────────────────────

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _toRad(lon2 - lon1);
    final y = sin(dLon) * cos(_toRad(lat2));
    final x = cos(_toRad(lat1)) * sin(_toRad(lat2)) -
        sin(_toRad(lat1)) * cos(_toRad(lat2)) * cos(dLon);
    return (_toDeg(atan2(y, x)) + 360) % 360;
  }

  double _toRad(double deg) => deg * pi / 180;
  double _toDeg(double rad) => rad * 180 / pi;
}
