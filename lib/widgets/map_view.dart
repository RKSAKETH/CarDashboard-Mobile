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

  const MapView({
    super.key,
    required this.currentPosition,
    required this.speed,
    this.activeRoute,
    this.onStopNavigation,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // ─── Lifecycle ───

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Route changed
    if (widget.activeRoute != oldWidget.activeRoute) {
      _rebuildOverlays();
    }

    // Camera follows user when navigating
    if (widget.currentPosition != null &&
        widget.currentPosition != oldWidget.currentPosition &&
        widget.activeRoute == null) {
      _animateToUser();
    }
  }

  void _rebuildOverlays() {
    final route = widget.activeRoute;
    if (route == null) {
      setState(() {
        _polylines = {};
        _markers = {};
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

    setState(() {
      _polylines = {routePolyline};
      _markers = {destMarker};
    });

    // Fit camera to route
    _fitBounds(route);
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

    // Include current position in bounds if available
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
        LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude),
      ),
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final position = widget.currentPosition;

    if (position == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'Waiting for GPS signal…',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Make sure location is enabled',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final currentLatLng = LatLng(position.latitude, position.longitude);

    return Stack(
      children: [
        // ─── Map ───
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: currentLatLng,
            zoom: 17,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          mapType: MapType.normal,
          style: _kDarkMapStyle,
          polylines: _polylines,
          markers: _markers,
          onMapCreated: (controller) {
            _mapController = controller;
            if (widget.activeRoute != null) {
              _rebuildOverlays();
            }
          },
        ),

        // ─── Route Info Banner ───
        if (widget.activeRoute != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildRouteBanner(widget.activeRoute!),
          ),

        // ─── Coordinates Card ───
        if (widget.activeRoute == null)
          Positioned(
            left: 12,
            bottom: 12,
            child: _buildCoordsCard(position),
          ),

        // ─── Speed Circle ───
        Positioned(
          right: 12,
          bottom: 12,
          child: _buildSpeedCircle(),
        ),

        // ─── My Location Button ───
        Positioned(
          right: 12,
          bottom: widget.activeRoute != null ? 110 : 100,
          child: _buildMyLocationButton(),
        ),
      ],
    );
  }

  // ─── Route Banner ───

  Widget _buildRouteBanner(RouteInfo route) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withAlpha(60),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: Color(0xFF00E5FF), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  route.destination,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${route.distanceText}  ·  ${route.durationText}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onStopNavigation,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Coords Card ───

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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text('Lat', style: TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 4),
          Text(
            position.longitude.toStringAsFixed(5),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text('Lng', style: TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }

  // ─── Speed Circle ───

  Widget _buildSpeedCircle() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xDD1A1A2E),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00FF88), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withAlpha(80),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.speed.toInt().toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'km/h',
              style: TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // ─── My Location Button ───

  Widget _buildMyLocationButton() {
    return GestureDetector(
      onTap: () {
        if (widget.activeRoute != null) {
          _fitBounds(widget.activeRoute!);
        } else {
          _animateToUser();
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xDD1A1A2E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(
          Icons.my_location,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  // ─── Dispose ───

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
