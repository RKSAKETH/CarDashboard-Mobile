import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  
  Stream<Position> get positionStream => _positionController.stream;
  
  Future<void> startTracking() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return;
      }

      // Configure location settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // Get all updates for speedometer
      );

      print('Starting location tracking...');
      
      // Start listening to position stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          print('GPS Update: Speed=${position.speed}, Lat=${position.latitude}, Lng=${position.longitude}');
          _positionController.add(position);
        },
        onError: (error) {
          print('Location stream error: $error');
        },
      );
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }
  
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
  
  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
