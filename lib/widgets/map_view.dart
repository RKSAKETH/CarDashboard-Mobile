import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/voice_assistant_service.dart';

const _kDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]}
]
''';

class MapView extends StatefulWidget {
  final Position? currentPosition;
  final double speed;
  final RouteInfo? activeRoute;
  final VoidCallback? onStopNavigation;
  final int? speedLimit;
  final bool isOverLimit;

  /// True when the app is in Simulation mode – changes map behaviour:
  /// • Replaces the OS blue-dot with a custom car marker
  /// • Camera continuously follows the simulated position
  final bool isSimulation;

  const MapView({
    super.key,
    required this.currentPosition,
    required this.speed,
    this.activeRoute,
    this.onStopNavigation,
    this.speedLimit,
    this.isOverLimit = false,
    this.isSimulation = false,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Whether the user is panning the map manually (pause auto-follow)
  bool _userPanning = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final posChanged = widget.currentPosition != oldWidget.currentPosition;
    final routeChanged = widget.activeRoute != oldWidget.activeRoute;
    final simChanged = widget.isSimulation != oldWidget.isSimulation;

    // Rebuild overlays when route or sim-mode changes
    if (routeChanged || simChanged) {
      _rebuildOverlays();
    }

    // Update car marker + follow camera on every position tick in sim mode
    if (posChanged && widget.currentPosition != null) {
      if (widget.isSimulation) {
        // Always update car marker and camera during simulation
        _updateSimMarker();
        if (!_userPanning) {
          _followSimPosition();
        }
      } else if (widget.activeRoute == null) {
        // Dev mode, no active route → just pan to user
        _animateToUser();
      }
    }
  }

  // ── Overlays ───────────────────────────────────────────────────────────────

  void _rebuildOverlays() {
    final route = widget.activeRoute;
    if (route == null) {
      // Keep sim marker if still in sim mode
      setState(() {
        _polylines = {};
        _markers = widget.isSimulation ? _simMarkerSet() : {};
      });
      return;
    }

    final routePolyline = Polyline(
      polylineId: const PolylineId('route'),
      points: route.polylinePoints,
      color: const Color(0xFF00E5FF),
      width: 5,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
      jointType: JointType.round,
    );

    final destMarker = Marker(
      markerId: const MarkerId('destination'),
      position: route.destinationLatLng,
      infoWindow: InfoWindow(
        title: route.destination,
        snippet: '${route.distanceText} · ${route.durationText}',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    final baseMarkers = <Marker>{destMarker};
    if (widget.isSimulation) baseMarkers.addAll(_simMarkerSet());

    setState(() {
      _polylines = {routePolyline};
      _markers = baseMarkers;
    });

    // In simulation mode start following immediately; otherwise fit bounds
    if (widget.isSimulation) {
      _followSimPosition();
    } else {
      _fitBounds(route);
    }
  }

  /// Updates only the simulated-car marker without touching polylines/dest
  void _updateSimMarker() {
    final pos = widget.currentPosition;
    if (pos == null) return;

    // Replace the 'sim_car' marker in the current set
    final updated = _markers.where((m) => m.markerId.value != 'sim_car').toSet();
    updated.addAll(_simMarkerSet());
    setState(() => _markers = updated);
  }

  /// Builds the custom car marker at the current simulated position
  Set<Marker> _simMarkerSet() {
    final pos = widget.currentPosition;
    if (pos == null) return {};

    return {
      Marker(
        markerId: const MarkerId('sim_car'),
        position: LatLng(pos.latitude, pos.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.isOverLimit
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueAzure,
        ),
        flat: true, // lies flat on the map so rotation looks natural
        rotation: pos.heading, // points in direction of travel
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
        infoWindow: InfoWindow(
          title: '🚗 ${widget.speed.toInt()} km/h',
          snippet: widget.speedLimit != null
              ? 'Limit: ${widget.speedLimit} km/h'
              : null,
        ),
      ),
    };
  }

  // ── Camera ─────────────────────────────────────────────────────────────────

  /// Smoothly follows the simulated car, including bearing (heading)
  void _followSimPosition() {
    final pos = widget.currentPosition;
    if (_mapController == null || pos == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 17.5,
          // Rotate map so car always faces "up"
          bearing: pos.heading,
          tilt: 40, // slight 3-D tilt for driving feel
        ),
      ),
    );
  }

  void _fitBounds(RouteInfo route) async {
    if (_mapController == null || route.polylinePoints.isEmpty) return;

    double minLat = route.polylinePoints.first.latitude;
    double maxLat = route.polylinePoints.first.latitude;
    double minLng = route.polylinePoints.first.longitude;
    double maxLng = route.polylinePoints.first.longitude;

    for (final p in route.polylinePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if (widget.currentPosition != null) {
      if (widget.currentPosition!.latitude < minLat) minLat = widget.currentPosition!.latitude;
      if (widget.currentPosition!.latitude > maxLat) maxLat = widget.currentPosition!.latitude;
      if (widget.currentPosition!.longitude < minLng) minLng = widget.currentPosition!.longitude;
      if (widget.currentPosition!.longitude > maxLng) maxLng = widget.currentPosition!.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void _animateToUser() {
    if (_mapController == null || widget.currentPosition == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(widget.currentPosition!.latitude,
            widget.currentPosition!.longitude),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final position = widget.currentPosition;

    if (position == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isSimulation ? Icons.route : Icons.location_off,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              widget.isSimulation
                  ? 'Give a voice destination to start simulation…'
                  : 'Waiting for GPS signal…',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.isSimulation
                  ? 'Tap the mic and say "Navigate to [place]"'
                  : 'Make sure location is enabled',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final currentLatLng = LatLng(position.latitude, position.longitude);

    return Stack(
      children: [
        // ── Map ─────────────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: currentLatLng,
            zoom: 17,
          ),
          // Dev mode: use OS blue dot. Sim mode: use custom car marker instead.
          myLocationEnabled: !widget.isSimulation,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          mapType: MapType.normal,
          style: _kDarkMapStyle,
          polylines: _polylines,
          markers: _markers,
          onMapCreated: (controller) {
            _mapController = controller;
            _rebuildOverlays();
            if (widget.isSimulation) {
              _followSimPosition();
            }
          },
          // Detect when user starts panning (pause auto-follow)
          onCameraMoveStarted: () => _userPanning = true,
          onCameraIdle: () {
            // Re-enable auto-follow after 3 seconds of idle
            Future.delayed(const Duration(seconds: 3), () {
              _userPanning = false;
            });
          },
        ),


        // ── Coordinates Card (dev mode only) ─────────────────────────────
        if (!widget.isSimulation && widget.activeRoute == null)
          Positioned(
            left: 12,
            bottom: 12,
            child: _buildCoordsCard(position),
          ),
      ],
    );
  }


  // ── Coords Card ─────────────────────────────────────────────────────────────

  Widget _buildCoordsCard(Position position) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            position.latitude.toStringAsFixed(5),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text('Lat',
              style: TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 4),
          Text(
            position.longitude.toStringAsFixed(5),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text('Lng',
              style: TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }

  // ── Dispose ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
