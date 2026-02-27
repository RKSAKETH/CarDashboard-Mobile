import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─────────────────── Data Classes ───────────────────

class RouteInfo {
  final String destination;
  final LatLng destinationLatLng;
  final List<LatLng> polylinePoints;
  final String distanceText;
  final String durationText;
  final int durationSeconds;

  RouteInfo({
    required this.destination,
    required this.destinationLatLng,
    required this.polylinePoints,
    required this.distanceText,
    required this.durationText,
    required this.durationSeconds,
  });
}

// ─────────────────── Callbacks ───────────────────

typedef OnRouteFound = void Function(RouteInfo route);
typedef OnNavigationStopped = void Function();
typedef OnPageChange = void Function(int index); // 0=Gauge,1=Digital,2=Map
typedef OnOpenSettings = void Function();
typedef OnVoiceStatus = void Function(String status);
typedef OnArrived = void Function();

// ─────────────────── Service ───────────────────

class VoiceAssistantService {
  static const String _apiKey = 'AIzaSyBkqsRwb7_CgiOw2H0auTBIfyKWQQjPEBw';

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  // Active navigation state
  RouteInfo? _activeRoute;
  Timer? _arrivalTimer;
  Position? _lastKnownPosition;

  // Callbacks
  OnRouteFound? onRouteFound;
  OnNavigationStopped? onNavigationStopped;
  OnPageChange? onPageChange;
  OnOpenSettings? onOpenSettings;
  OnVoiceStatus? onVoiceStatus;
  OnArrived? onArrived;

  bool get isListening => _isListening;
  bool get hasActiveRoute => _activeRoute != null;

  // ─── Initialise ───

  Future<void> init() async {
    // TTS setup
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);

    // STT setup
    _sttAvailable = await _stt.initialize(
      onStatus: (status) {
        debugPrint('[STT] status: $status');
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          onVoiceStatus?.call('Tap mic to speak');
        }
      },
      onError: (error) {
        debugPrint('[STT] error: $error');
        _isListening = false;
        onVoiceStatus?.call('Tap mic to speak');
      },
    );

    debugPrint('[Voice] STT available: $_sttAvailable');
  }

  // ─── Speak ───

  Future<void> speak(String text) async {
    debugPrint('[TTS] Speaking: $text');
    onVoiceStatus?.call(text);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  // ─── Listen ───

  Future<void> startListening() async {
    if (!_sttAvailable) {
      await speak('Microphone is not available on this device.');
      return;
    }
    if (_isListening) return;

    await stopSpeaking();
    _isListening = true;
    onVoiceStatus?.call('Listening…');

    _stt.listen(
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
      onResult: (result) {
        if (result.finalResult) {
          _isListening = false;
          final words = result.recognizedWords.trim();
          debugPrint('[STT] Heard: $words');
          if (words.isNotEmpty) {
            onVoiceStatus?.call('"$words"');
            _handleCommand(words.toLowerCase());
          } else {
            onVoiceStatus?.call('Tap mic to speak');
          }
        }
      },
    );
  }

  void stopListening() {
    _stt.stop();
    _isListening = false;
    onVoiceStatus?.call('Tap mic to speak');
  }

  // ─── Intent Parsing ───

  void _handleCommand(String cmd) {
    // Navigation intent
    final navPatterns = [
      RegExp(r'navigate to (.+)'),
      RegExp(r'take me to (.+)'),
      RegExp(r'go to (.+)'),
      RegExp(r'directions? to (.+)'),
      RegExp(r'find (.+) on the map'),
      RegExp(r'route to (.+)'),
      RegExp(r'show me (.+) on map'),
    ];

    for (final pattern in navPatterns) {
      final match = pattern.firstMatch(cmd);
      if (match != null) {
        final place = _cleanPlace(match.group(1)!);
        _startNavigation(place);
        return;
      }
    }

    // Stop navigation
    if (cmd.contains('stop navigation') ||
        cmd.contains('cancel route') ||
        cmd.contains('cancel navigation') ||
        cmd.contains('end navigation') ||
        cmd.contains('stop route')) {
      _cancelNavigation();
      return;
    }

    // Page switches
    if (cmd.contains('gauge') || cmd.contains('speedometer view') || cmd.contains('open gauge')) {
      onPageChange?.call(0);
      speak('Switching to gauge view.');
      return;
    }
    if (cmd.contains('digital') || cmd.contains('digital view') || cmd.contains('open digital')) {
      onPageChange?.call(1);
      speak('Switching to digital view.');
      return;
    }
    if (cmd.contains('map') || cmd.contains('open map') || cmd.contains('show map')) {
      onPageChange?.call(2);
      speak('Switching to map view.');
      return;
    }

    // Settings
    if (cmd.contains('settings') || cmd.contains('open settings') || cmd.contains('preferences')) {
      onOpenSettings?.call();
      speak('Opening settings.');
      return;
    }

    // Fallback
    speak('Sorry, I didn\'t understand that. Try saying: navigate to a place, open gauge, open digital, open map, or open settings.');
  }

  String _cleanPlace(String raw) {
    // Remove filler words at end
    for (final filler in ['please', 'now', 'for me']) {
      raw = raw.replaceAll(' $filler', '');
    }
    return raw.trim();
  }

  // ─── Navigation ───

  /// Public entry-point so the search UI can trigger navigation directly.
  Future<void> navigateTo(String place) => _startNavigation(place);

  /// Fetches autocomplete place suggestions from the Google Places API.
  /// Returns a list of maps with 'description' and 'placeId' keys.
  Future<List<Map<String, String>>> fetchPlaceSuggestions(
      String input, {
      double? latitude,
      double? longitude,
  }) async {
    if (input.trim().isEmpty) return [];
    try {
      final params = <String, String>{
        'input': input,
        'key': _apiKey,
        'types': 'geocode|establishment',
      };
      if (latitude != null && longitude != null) {
        params['location'] = '$latitude,$longitude';
        params['radius'] = '50000'; // 50 km bias
      }
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        params,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        debugPrint('[Places] Autocomplete error: ${data['status']}');
        return [];
      }
      final predictions = data['predictions'] as List<dynamic>? ?? [];
      return predictions.map((p) {
        final map = p as Map<String, dynamic>;
        return {
          'description': map['description'] as String? ?? '',
          'placeId': map['place_id'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('[Places] Autocomplete exception: $e');
      return [];
    }
  }

  Future<void> _startNavigation(String place) async {
    onPageChange?.call(2); // Switch to map
    await speak('Searching for $place. Please wait…');

    try {
      final route = await _fetchRoute(place);
      if (route == null) {
        await speak('Sorry, I could not find a route to $place. Please check the location name and try again.');
        return;
      }

      _activeRoute = route;
      onRouteFound?.call(route);

      final msg = 'Route found to ${route.destination}. '
          'It is ${route.distanceText} away, approximately ${route.durationText}.';
      await speak(msg);

      _startArrivalMonitoring();
    } catch (e) {
      debugPrint('[Voice] Navigation error: $e');
      await speak('There was an error finding the route. Please try again.');
    }
  }

  void _cancelNavigation() {
    _activeRoute = null;
    _arrivalTimer?.cancel();
    _arrivalTimer = null;
    onNavigationStopped?.call();
    speak('Navigation cancelled.');
  }

  // ─── Directions API ───

  Future<RouteInfo?> _fetchRoute(String destination) async {
    if (_lastKnownPosition == null) {
      debugPrint('[Voice] No GPS position available');
      await speak('Waiting for GPS signal. Please make sure location is enabled.');
      return null;
    }

    final origin = '${_lastKnownPosition!.latitude},${_lastKnownPosition!.longitude}';
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': origin,
      'destination': destination,
      'key': _apiKey,
      'mode': 'driving',
    });

    debugPrint('[Voice] Directions request: $uri');

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final data = json.decode(response.body) as Map<String, dynamic>;

    debugPrint('[Voice] Directions status: ${data['status']}');

    if (data['status'] != 'OK') {
      debugPrint('[Voice] Directions error: ${data['status']} - ${data['error_message'] ?? ''}');
      return null;
    }

    final route = data['routes'][0] as Map<String, dynamic>;
    final leg = route['legs'][0] as Map<String, dynamic>;

    // Decode polyline
    final encoded = route['overview_polyline']['points'] as String;
    final points = _decodePolyline(encoded);

    // Destination coords
    final endLoc = leg['end_location'] as Map<String, dynamic>;
    final destLatLng = LatLng(endLoc['lat'] as double, endLoc['lng'] as double);

    // End address
    final endAddress = (leg['end_address'] as String?)?.split(',').first ?? destination;

    return RouteInfo(
      destination: endAddress,
      destinationLatLng: destLatLng,
      polylinePoints: points,
      distanceText: leg['distance']['text'] as String,
      durationText: leg['duration']['text'] as String,
      durationSeconds: leg['duration']['value'] as int,
    );
  }

  // ─── Polyline Decoder ───

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ─── Arrival Monitoring ───

  void _startArrivalMonitoring() {
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkArrival();
    });
  }

  void _checkArrival() {
    if (_activeRoute == null || _lastKnownPosition == null) return;

    final distMeters = _haversine(
      _lastKnownPosition!.latitude,
      _lastKnownPosition!.longitude,
      _activeRoute!.destinationLatLng.latitude,
      _activeRoute!.destinationLatLng.longitude,
    );

    debugPrint('[Voice] Distance to dest: ${distMeters.toStringAsFixed(0)}m');

    if (distMeters <= 50) {
      _arrivalTimer?.cancel();
      _arrivalTimer = null;
      _activeRoute = null;
      onArrived?.call();
      onNavigationStopped?.call();
      speak('You have arrived at your destination!');
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  // ─── Update position from HomeScreen ───

  void updatePosition(Position position) {
    _lastKnownPosition = position;
  }

  // ─── Dispose ───

  void dispose() {
    _arrivalTimer?.cancel();
    _stt.cancel();
    _tts.stop();
  }
}
