import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapView extends StatefulWidget {
  final Position? currentPosition;
  final double speed;

  const MapView({
    super.key,
    required this.currentPosition,
    required this.speed,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  
  @override
  Widget build(BuildContext context) {
    final position = widget.currentPosition;
    
    if (position == null) {
      final textSecondary = Theme.of(context).brightness == Brightness.dark
          ? Colors.white70
          : Colors.black54;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: textSecondary),
            const SizedBox(height: 16),
            Text(
              'Waiting for GPS signal...',
              style: TextStyle(color: textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final currentLatLng = LatLng(position.latitude, position.longitude);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: currentLatLng,
            zoom: 17,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          compassEnabled: true,
          mapType: MapType.normal,
          onMapCreated: (controller) {
            _mapController = controller;
          },
        ),
        
        // Coordinates display
        Positioned(
          left: 20,
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  position.latitude.toStringAsFixed(3),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  'Lat',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  position.longitude.toStringAsFixed(3),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  'Long',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        
        // Speed indicator overlay
        Positioned(
          right: 20,
          bottom: 20,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.speed.toInt().toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
