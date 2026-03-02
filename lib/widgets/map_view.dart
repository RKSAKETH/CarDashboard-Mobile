import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart' hide Marker;
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

  // Cached car icons – rebuilt only when over-limit status changes
  BitmapDescriptor? _carIconNormal;
  BitmapDescriptor? _carIconRed;
  bool _iconsReady = false;

  // Whether the user is panning the map manually (pause auto-follow)
  bool _userPanning = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _buildCarIcons();
  }

  Future<void> _buildCarIcons() async {
    _carIconNormal = await _makeCarIcon(tintRed: false);
    _carIconRed    = await _makeCarIcon(tintRed: true);
    if (mounted) setState(() => _iconsReady = true);
  }

  // ── Asset-based car icon ────────────────────────────────────────────────

  /// Load the car PNG from assets, optionally tint it red when over the speed
  /// limit, resize to [targetSize] canvas pixels, and return as BitmapDescriptor.
  static Future<BitmapDescriptor> _makeCarIcon({bool tintRed = false}) async {
    const int targetSize = 120;

    // Load PNG bytes from assets
    final ByteData data =
        await rootBundle.load('assets/images/car_marker.png');
    final Uint8List rawBytes = data.buffer.asUint8List();

    // Decode to ui.Image
    final ui.Codec codec =
        await ui.instantiateImageCodec(rawBytes, targetWidth: targetSize);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image srcImage = frame.image;

    if (!tintRed) {
      // Use directly
      final ByteData? pngBytes =
          await srcImage.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(
        pngBytes!.buffer.asUint8List(),
        width: 64,  // larger icon — clear on map
      );
    }

    // Tint red using a Canvas ColorFilter for over-speed state
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, targetSize.toDouble(), targetSize.toDouble()),
    );
    canvas.drawImage(
      srcImage,
      Offset.zero,
      Paint()
        ..colorFilter = const ColorFilter.matrix([
          // R    G    B    A    +
          1.2,  0.0, 0.0, 0.0, 30,  // red boost
          0.0,  0.0, 0.0, 0.0,  0,  // kill green
          0.0,  0.0, 0.0, 0.0,  0,  // kill blue
          0.0,  0.0, 0.0, 1.0,  0,  // keep alpha
        ]),
    );
    final pic   = recorder.endRecording();
    final image = await pic.toImage(targetSize, targetSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 64,
    );
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final posChanged = widget.currentPosition != oldWidget.currentPosition;
    final routeChanged = widget.activeRoute != oldWidget.activeRoute;
    final simChanged = widget.isSimulation != oldWidget.isSimulation;
    final overLimitChanged = widget.isOverLimit != oldWidget.isOverLimit;

    // Rebuild overlays when route, sim-mode, or over-limit status changes
    if (routeChanged || simChanged || overLimitChanged) {
      _rebuildOverlays();
    }

    // Update car marker + follow camera on every position tick
    if (posChanged && widget.currentPosition != null) {
      if (widget.isSimulation) {
        _updateSimMarker();
        if (!_userPanning) _followSimPosition();
      } else {
        // Dev mode: keep car marker updated too
        _updateDevMarker();
        if (widget.activeRoute == null) _animateToUser();
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
    if (pos == null || !_iconsReady) return;
    final updated = _markers.where((m) => m.markerId.value != 'sim_car').toSet();
    updated.addAll(_simMarkerSet());
    setState(() => _markers = updated);
  }

  /// Updates the dev-mode car marker
  void _updateDevMarker() {
    final pos = widget.currentPosition;
    if (pos == null || !_iconsReady) return;
    final updated = _markers.where((m) => m.markerId.value != 'dev_car').toSet();
    updated.add(_devCarMarker(pos));
    setState(() => _markers = updated);
  }

  /// Builds a dev-mode car marker
  Marker _devCarMarker(Position pos) {
    return Marker(
      markerId: const MarkerId('dev_car'),
      position: LatLng(pos.latitude, pos.longitude),
      icon: _carIconNormal!,
      flat: true,
      rotation: pos.heading,
      // (0.5, 0.6): car sits on road, front slightly above center-point
      anchor: const Offset(0.5, 0.6),
      zIndexInt: 2,
    );
  }

  /// Builds the custom car marker at the current simulated position
  Set<Marker> _simMarkerSet() {
    final pos = widget.currentPosition;
    if (pos == null || !_iconsReady) return {};

    final icon = widget.isOverLimit ? _carIconRed! : _carIconNormal!;

    return {
      Marker(
        markerId: const MarkerId('sim_car'),
        position: LatLng(pos.latitude, pos.longitude),
        icon: icon,
        flat: true,
        // rotation = heading: image-top (front of car) faces direction of travel.
        // Camera bearing is also set to heading, so on-screen the car always
        // faces "up" = forward.
        rotation: pos.heading,
        // Anchor at (0.5, 0.6) so the car sits on the road naturally
        anchor: const Offset(0.5, 0.6),
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
          zoom: 18.0,
          // Map rotates so direction-of-travel is always "up" on screen
          bearing: pos.heading,
          // 52° tilt: similar to Google Maps / Waze navigation perspective
          tilt: 52,
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
      return _MapLoadingPlaceholder(isSimulation: widget.isSimulation);
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
          // Always use custom car marker — disable OS blue dot
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          mapType: MapType.normal,
          style: _kDarkMapStyle,
          polylines: _polylines,
          markers: _markers,
          onMapCreated: (controller) {
            _mapController = controller;
            _rebuildOverlays();
            // Add dev-mode marker on initial load
            if (!widget.isSimulation && widget.currentPosition != null) {
              _updateDevMarker();
            }
            if (widget.isSimulation) _followSimPosition();
          },
          onCameraMoveStarted: () => _userPanning = true,
          onCameraIdle: () {
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

// ─── Map Loading Placeholder (Lottie) ────────────────────────────────────────
//
//  Shown while position == null (i.e. GPS not yet acquired or map still loading).
//

class _MapLoadingPlaceholder extends StatelessWidget {
  final bool isSimulation;
  const _MapLoadingPlaceholder({required this.isSimulation});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Lottie animation ──────────────────────────────────────────────
            SizedBox(
              width: 180,
              height: 180,
              child: Lottie.asset(
                'assets/lottie/map_loading.json',
                repeat: true,
                animate: true,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 24),

            // ── Headline ──────────────────────────────────────────────────────
            Text(
              isSimulation ? 'Simulation Ready' : 'Acquiring GPS…',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 8),

            // ── Sub text ──────────────────────────────────────────────────────
            Text(
              isSimulation
                  ? 'Tap the mic and say "Navigate to [place]"'
                  : 'Make sure location services are enabled',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // ── Animated dots indicator ───────────────────────────────────────
            const _PulseDotsRow(),
          ],
        ),
      ),
    );
  }
}

// Three pulsing dots loading indicator
class _PulseDotsRow extends StatefulWidget {
  const _PulseDotsRow();

  @override
  State<_PulseDotsRow> createState() => _PulseDotsRowState();
}

class _PulseDotsRowState extends State<_PulseDotsRow>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>>   _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0.3, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Opacity(
              opacity: _anims[i].value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF)
                          .withAlpha((_anims[i].value * 120).toInt()),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
