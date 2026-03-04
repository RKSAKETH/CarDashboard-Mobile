import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gauge_view.dart';
import '../widgets/map_view.dart';
import '../widgets/music_player_view.dart';
import '../widgets/app_drawer.dart' show AppDrawer, SettingsScreen;
import '../widgets/ambient_light_overlay.dart';
import '../l10n/app_localizations.dart';
import '../models/speed_data.dart';
import '../services/location_service.dart';
import '../services/history_service.dart';
import '../services/voice_assistant_service.dart';
import '../services/speed_limit_service.dart';
import '../services/simulation_service.dart';

import 'profile_screen.dart';
import 'car_pairing_screen.dart';
import 'fatigue_detection_screen.dart';
import 'tpms_screen.dart';
import '../services/incident_service.dart';
import '../services/firestore_service.dart';

// â”€â”€â”€ App Mode â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum AppMode { dev, simulation, live }

// â”€â”€â”€ HomeScreen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  int get _currentIndex => _currentIndexNotifier.value;
  set _currentIndex(int val) => _currentIndexNotifier.value = val;

  VehicleType _vehicleType = VehicleType.motorcycle;

  final ValueNotifier<bool> _isTrackingNotifier = ValueNotifier<bool>(false);
  bool get _isTracking => _isTrackingNotifier.value;
  set _isTracking(bool val) => _isTrackingNotifier.value = val;

  // â”€â”€ Mode â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final ValueNotifier<AppMode> _appModeNotifier = ValueNotifier<AppMode>(AppMode.dev);
  AppMode get _appMode => _appModeNotifier.value;
  set _appMode(AppMode val) => _appModeNotifier.value = val;
  bool get _isSimMode => _appMode == AppMode.simulation;

  // ── Speed tracking data ───────────────────────────────────────────────────
  final ValueNotifier<double> _currentSpeedNotifier = ValueNotifier<double>(0.0);
  double get _currentSpeed => _currentSpeedNotifier.value;
  set _currentSpeed(double val) => _currentSpeedNotifier.value = val;

  final ValueNotifier<double> _maxSpeedNotifier = ValueNotifier<double>(0.0);
  double get _maxSpeed => _maxSpeedNotifier.value;
  set _maxSpeed(double val) => _maxSpeedNotifier.value = val;

  final ValueNotifier<double> _totalDistanceNotifier = ValueNotifier<double>(0.0);
  double get _totalDistance => _totalDistanceNotifier.value;
  set _totalDistance(double val) => _totalDistanceNotifier.value = val;

  final ValueNotifier<double> _avgSpeedNotifier = ValueNotifier<double>(0.0);
  double get _avgSpeed => _avgSpeedNotifier.value;
  set _avgSpeed(double val) => _avgSpeedNotifier.value = val;

  final ValueNotifier<int> _satellitesNotifier = ValueNotifier<int>(0);
  int get _satellites => _satellitesNotifier.value;
  set _satellites(int val) => _satellitesNotifier.value = val;

  final ValueNotifier<bool> _hasGPSNotifier = ValueNotifier<bool>(false);
  bool get _hasGPS => _hasGPSNotifier.value;
  set _hasGPS(bool val) => _hasGPSNotifier.value = val;

  // ── Speed Limit ────────────────────────────────────────────────────────────
  final ValueNotifier<int?> _speedLimitNotifier = ValueNotifier<int?>(null);
  int? get _speedLimit => _speedLimitNotifier.value;
  set _speedLimit(int? val) => _speedLimitNotifier.value = val;

  final ValueNotifier<bool> _isOverLimitNotifier = ValueNotifier<bool>(false);
  bool get _isOverLimit => _isOverLimitNotifier.value;
  set _isOverLimit(bool val) => _isOverLimitNotifier.value = val;

  Timer? _warningRepeatTimer;     // repeating TTS loop while over limit
  DateTime? _lastLimitFetch;
  Timer? _speedLimitTimer;
  late AnimationController _pulseRedController;
  late Animation<double> _pulseRedAnim; // 0.0 → 1.0 (vignette opacity)

  // ── Timer ──────────────────────────────────────────────────────────────────
  final ValueNotifier<Duration> _elapsedNotifier = ValueNotifier<Duration>(Duration.zero);
  Duration get _elapsed => _elapsedNotifier.value;
  set _elapsed(Duration val) => _elapsedNotifier.value = val;

  Timer? _timer;

  // ── Services ───────────────────────────────────────────────────────────────
  final LocationService _locationService = LocationService();
  final HistoryService _historyService = HistoryService();
  final VoiceAssistantService _voice = VoiceAssistantService();
  final SpeedLimitService _speedLimitService = SpeedLimitService();
  final SimulationService _simService = SimulationService();

  // ── Location ───────────────────────────────────────────────────────────────
  final ValueNotifier<Position?> _currentPositionNotifier = ValueNotifier<Position?>(null);
  Position? get _currentPosition => _currentPositionNotifier.value;
  set _currentPosition(Position? val) => _currentPositionNotifier.value = val;

  // â”€â”€ Voice state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final ValueNotifier<bool> _voiceReadyNotifier = ValueNotifier<bool>(false);
  bool get _voiceReady => _voiceReadyNotifier.value;
  set _voiceReady(bool val) => _voiceReadyNotifier.value = val;

  final ValueNotifier<String> _voiceStatusNotifier = ValueNotifier<String>('Initialisingâ€¦');
  String get _voiceStatus => _voiceStatusNotifier.value;
  set _voiceStatus(String val) => _voiceStatusNotifier.value = val;

  // â”€â”€ Active route â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final ValueNotifier<RouteInfo?> _activeRouteNotifier = ValueNotifier<RouteInfo?>(null);
  RouteInfo? get _activeRoute => _activeRouteNotifier.value;
  set _activeRoute(RouteInfo? val) => _activeRouteNotifier.value = val;

  // â”€â”€ Simulation speed slider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final ValueNotifier<double> _simSpeedKmhNotifier = ValueNotifier<double>(30.0);
  double get _simSpeedKmh => _simSpeedKmhNotifier.value;
  set _simSpeedKmh(double val) => _simSpeedKmhNotifier.value = val;

  // â”€â”€ Simulation ongoing flag â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final ValueNotifier<bool> _simRunningNotifier = ValueNotifier<bool>(false);
  bool get _simRunning => _simRunningNotifier.value;
  set _simRunning(bool val) => _simRunningNotifier.value = val;

  // ── Active Vehicle (from QR) ────────────────────────────────────────────────
  final ValueNotifier<Map<String, String>?> _activeVehicleNotifier = ValueNotifier<Map<String, String>?>(null);
  Map<String, String>? get _activeVehicle => _activeVehicleNotifier.value;
  set _activeVehicle(Map<String, String>? val) => _activeVehicleNotifier.value = val;

  // ── Draggable bottom panel ──────────────────────────────────────────
  static const double _panelFull = 160.0;
  static const double _panelMid  =  76.0;
  static const double _panelMin  =  28.0;
  final ValueNotifier<double> _bottomPanelHeightNotifier = ValueNotifier<double>(160.0);
  double get _bottomPanelHeight => _bottomPanelHeightNotifier.value;
  set _bottomPanelHeight(double val) => _bottomPanelHeightNotifier.value = val;

  // ── Draggable sim-speed slider ──────────────────────────────────────────
  final ValueNotifier<Offset> _simSliderOffsetNotifier = ValueNotifier<Offset>(const Offset(16, 140));
  Offset get _simSliderOffset => _simSliderOffsetNotifier.value;
  set _simSliderOffset(Offset val) => _simSliderOffsetNotifier.value = val;
  final ValueNotifier<bool> _simSliderMinimizedNotifier = ValueNotifier<bool>(false);
  bool get _simSliderMinimized => _simSliderMinimizedNotifier.value;
  set _simSliderMinimized(bool val) => _simSliderMinimizedNotifier.value = val;

  // â”€â”€ Place Search â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final ValueNotifier<bool> _showSearchNotifier = ValueNotifier<bool>(false);
  bool get _showSearch => _showSearchNotifier.value;
  set _showSearch(bool val) => _showSearchNotifier.value = val;

  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<Map<String, String>>> _placeSuggestionsNotifier = ValueNotifier<List<Map<String, String>>>([]);
  List<Map<String, String>> get _placeSuggestions => _placeSuggestionsNotifier.value;
  set _placeSuggestions(List<Map<String, String>> val) => _placeSuggestionsNotifier.value = val;

  final ValueNotifier<bool> _searchLoadingNotifier = ValueNotifier<bool>(false);
  bool get _searchLoading => _searchLoadingNotifier.value;
  set _searchLoading(bool val) => _searchLoadingNotifier.value = val;
  Timer? _searchDebounce;

  // â”€â”€ Mic pulse animation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Lifecycle                                                               â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  void initState() {
    super.initState();

    // Mic pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Danger vignette animation for speed-limit warning (0=invisible â†’ 1=full)
    _pulseRedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseRedAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseRedController, curve: Curves.easeInOut),
    );

    _requestPermissions();
    _loadTotalDistance();
    _initVoice();
    IncidentService.instance.start();

    // Simulation service callback
    _simService.onRouteCompleted = () {
      if (mounted) {
        _stopSimulation();
        _stopTimer();
        _isTracking = false;
        _saveSession(); // Save trip upon completion
        _activeRoute = null;
        _voice.speak('You have arrived at your destination!');
      }
    };

    // Always subscribe to simulation stream â€“ works even without real GPS
    _simService.positionStream.listen((position) {
      if (_isSimMode && mounted) {
        _onPositionUpdate(position);
      }
    });
  }

  Future<void> _initVoice() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        _voiceStatus = 'Mic permission denied';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required for voice commands.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    await _voice.init();

    _voice.onVoiceStatus = (status) {
      if (mounted) _voiceStatus = status;
    };

    _voice.onRouteFound = (route) {
      if (mounted) {
        _activeRoute = route;
        _currentIndex = 1; // switch to map
        // In simulation mode, kick off the simulation automatically
        if (_isSimMode) {
          _startSimulation(route);
        }
      }
    };

    _voice.onNavigationStopped = () {
      if (mounted) {
        if (_isSimMode) _stopSimulation();
        _stopTimer();
        _isTracking = false;
        _saveSession();
        _activeRoute = null;
      }
    };

    _voice.onArrived = () {
      if (mounted) {
        if (_isSimMode) _stopSimulation();
        _stopTimer();
        _isTracking = false;
        _saveSession();
        _activeRoute = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎯 You have arrived at your destination!'),
            backgroundColor: Color(0xFF00C853),
            duration: Duration(seconds: 4),
          ),
        );
      }
    };

    _voice.onPageChange = (index) {
      if (mounted) _currentIndex = index;
    };

    _voice.onOpenSettings = () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    };

    if (mounted) {
      _voiceReady = true;
      _voiceStatus = 'Tap mic to speak';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speedLimitTimer?.cancel();
    _warningRepeatTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _pulseController.dispose();
    _pulseRedController.dispose();
    _currentSpeedNotifier.dispose();
    _currentPositionNotifier.dispose();
    _satellitesNotifier.dispose();
    _hasGPSNotifier.dispose();
    _isOverLimitNotifier.dispose();
    _simSliderOffsetNotifier.dispose();
    _voice.dispose();
    _simService.dispose();
    IncidentService.instance.stop();
    super.dispose();
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Permissions & Location                                                  â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<void> _requestPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location in app settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      await _initLocationTracking();
    } catch (e) {
      debugPrint('Permission error: $e');
    }
  }

  Future<void> _initLocationTracking() async {
    await _locationService.startTracking();

    _locationService.positionStream.listen((position) {
      // In simulation mode, ignore real GPS for speed display but keep
      // position available for initial map centering
      if (_isSimMode) {
        if (mounted && !_simRunning) {
          _currentPosition = position;
          _hasGPS = true;
        }
        _voice.updatePosition(position);
        return;
      }
      // Dev mode â€“ use real GPS
      _onPositionUpdate(position);
    });

  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    _currentPosition = position;
    _currentSpeed = position.speed * 3.6;
    _satellites = position.accuracy.toInt();
    _hasGPS = true;

    if (_isTracking && _currentSpeed > _maxSpeed) {
      _maxSpeed = _currentSpeed;
    }
    _voice.updatePosition(position);
    _checkSpeedLimit(position.latitude, position.longitude);
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Speed Limit                                                             â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<void> _checkSpeedLimit(double lat, double lng) async {
    // Rate-limit: fetch at most every 10 seconds
    final now = DateTime.now();
    if (_lastLimitFetch != null &&
        now.difference(_lastLimitFetch!) < const Duration(seconds: 10)) {
      // Still re-evaluate with the cached limit and current speed
      _evaluateSpeedExceedance();
      return;
    }
    _lastLimitFetch = now;

    // SpeedLimitService.getSpeedLimit now always returns a value
    final limit = await _speedLimitService.getSpeedLimit(lat, lng);
    if (!mounted) return;
    _speedLimit = limit;
    _evaluateSpeedExceedance();
  }

  void _evaluateSpeedExceedance() {
    // No limit known yet — don't disturb existing state
    if (_speedLimit == null) return;

    final over = _currentSpeed > _speedLimit!;

    if (over && !_isOverLimit) {
      // → Just crossed above the limit
      _isOverLimit = true;
      _pulseRedController.repeat(reverse: true);
      _startWarningLoop();
    } else if (!over && _isOverLimit) {
      // → Back under the limit — stop all warnings
      _clearOverLimitState();
    }
    // Already in the correct state — nothing to do
  }

  /// Cancels all over-limit feedback and resets state.
  void _clearOverLimitState() {
    if (!mounted) return;
    _isOverLimit = false;
    _pulseRedController.stop();
    _pulseRedController.reset();
    _warningRepeatTimer?.cancel();
    _warningRepeatTimer = null;
  }

  /// Fires an immediate TTS warning then repeats every 8 s while still over.
  void _startWarningLoop() {
    _warningRepeatTimer?.cancel();
    // Speak immediately
    _voice.speak('Slow down, speed limit exceeded.');
    // Keep repeating until speed drops
    _warningRepeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_isOverLimit) {
        _warningRepeatTimer?.cancel();
        _warningRepeatTimer = null;
        return;
      }
      _voice.speak('Slow down, speed limit exceeded.');
    });
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Mode Toggle                                                             â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _switchMode(AppMode mode) {
    if (mode == _appMode) return;

    // Stop simulation if switching away
    if (_appMode == AppMode.simulation) {
      _stopSimulation();
    }

    _appMode = mode;
    _currentSpeed = 0;
    _isOverLimit = false;
    _speedLimit = null;

    _warningRepeatTimer?.cancel();
    _warningRepeatTimer = null;
    _pulseRedController.stop();
    _pulseRedController.reset();
    _speedLimitService.clearCache();
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Simulation                                                              â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _startSimulation(RouteInfo route) {
    if (route.polylinePoints.isEmpty) return;

    // If no real GPS, seed position from route start so the map renders
    if (_currentPosition == null) {
      final start = route.polylinePoints.first;
      _currentPosition = Position(
        latitude: start.latitude,
        longitude: start.longitude,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        heading: 0.0,
      );
      _hasGPS = true;
    }

    _simService.targetSpeedKmh = _simSpeedKmh;
    _simService.startRoute(route.polylinePoints, initialSpeedKmh: _simSpeedKmh);
    _simRunning = true;
  }

  void _stopSimulation() {
    _simService.stop();
    _simRunning = false;
    _currentSpeed = 0;
  }

  void _onSimSpeedChanged(double value) {
    _simSpeedKmh = value;
    if (_simRunning) _currentSpeed = value;
    _simService.targetSpeedKmh = value;

    if (_simRunning) {
      if (_speedLimit != null) {
        // We already have a limit â€” evaluate immediately
        _evaluateSpeedExceedance();
      } else if (_currentPosition != null) {
        // No limit cached yet â€” fetch it now (ignores the rate-limit timer)
        _lastLimitFetch = null;
        _checkSpeedLimit(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
    }
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Panel Drag                                                              â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _onPanelDrag(DragUpdateDetails d) {
    _bottomPanelHeight =
        (_bottomPanelHeight - d.delta.dy).clamp(_panelMin, _panelFull);
  }

  void _onPanelDragEnd(DragEndDetails _) {
    const snaps = [_panelMin, _panelMid, _panelFull];
    final closest = snaps.reduce((a, b) =>
        (a - _bottomPanelHeight).abs() < (b - _bottomPanelHeight).abs() ? a : b);
    _bottomPanelHeight = closest;
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Tracking                                                                â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<void> _loadTotalDistance() async {
    final distance = await _historyService.getTotalDistance();
    _totalDistance = distance;
  }

  void _toggleTracking() {
    _isTracking = !_isTracking;
    if (_isTracking) {
      _startTimer();
      _resetCurrentSession();
    } else {
      _stopTimer();
      _saveSession();
    }
  }

  /// Smart handler for the main START/STOP button.
  /// â€“ Sim mode + active route: starts/stops the navigation journey.
  /// â€“ Otherwise: toggles the session tracking timer as usual.
  void _onStartStopPressed() {
    if (_isSimMode && _activeRoute != null) {
      if (_simRunning) {
        // Stop the journey â€” fully replaces the old map-banner stop button:
        // stops simulation, clears route, saves session, announces via TTS.
        _stopSimulation();
        _stopTimer();
        _isTracking = false;
        _activeRoute = null;
        _saveSession();
        _voice.speak('Navigation stopped.');
      } else {
        // Start the journey
        _resetCurrentSession();
        _startTimer();
        _isTracking = true;
        _startSimulation(_activeRoute!);
      }
    } else {
      _toggleTracking();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      _updateAvgSpeed();
    });
  }

  void _stopTimer() => _timer?.cancel();

  void _resetCurrentSession() {
    _maxSpeed = 0.0;
    _avgSpeed = 0.0;
    _elapsed = Duration.zero;
  }

  void _updateAvgSpeed() {
    if (_elapsed.inSeconds > 0) {
      _avgSpeed = (_totalDistance / _elapsed.inSeconds) * 3600;
    }
  }

  Future<void> _saveSession() async {
    if (_elapsed.inSeconds > 0) {
      // 1. Save locally
      await _historyService.saveSession(
        distance: _totalDistance,
        maxSpeed: _maxSpeed,
        avgSpeed: _avgSpeed,
        duration: _elapsed,
        vehicleType: VehicleType.car, // Forced car for UI consistency
      );

      // 2. Save to Firebase
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirestoreService().saveTrip(
            userId: uid,
            distance: _totalDistance,
            maxSpeed: _maxSpeed,
            avgSpeed: _avgSpeed,
            durationSeconds: _elapsed.inSeconds,
            vehicleType: 'car',
            destinationName: _activeRoute?.destination,
          );
        } catch (e) {
          debugPrint('Failed to save trip to Firebase: $e');
        }
      }
    }
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Voice                                                                   â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<void> _onMicPressed() async {
    if (!_voiceReady) return;
    if (_voice.isListening) {
      _voice.stopListening();
      _pulseController.stop();
      _pulseController.reset();
    } else {
      _pulseController.repeat(reverse: true);
      await _voice.startListening();
      if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _stopNavigation() {
    _voice.onNavigationStopped?.call();
    _activeRoute = null;
    if (_isSimMode) _stopSimulation();
    _voice.speak('Navigation stopped.');
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Place Search                                                            â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _placeSuggestions = [];
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      _searchLoading = true;
      final results = await _voice.fetchPlaceSuggestions(
        query,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );
      if (mounted) {
        _placeSuggestions = results;
        _searchLoading = false;
      }
    });
  }

  void _selectSuggestion(String description) {
    _searchController.clear();
    _showSearch = false;
    _placeSuggestions = [];
    _voice.navigateTo(description);
  }

  void _closeSearch() {
    _searchController.clear();
    _showSearch = false;
    _placeSuggestions = [];
  }

  Widget _buildSearchOverlay() {
    final lightMode = AmbientLightProvider.of(context);
    final accent = LightThemePalette.accent(lightMode);
    final textPri = LightThemePalette.textPrimary(lightMode);
    final textSec = LightThemePalette.textSecondary(lightMode);

    return ValueListenableBuilder2<bool, RouteInfo?>(
      _showSearchNotifier,
      _activeRouteNotifier,
      (context, showSearch, route) => Stack(
        children: [
          // ── Search button (shown when search closed + no active route) ──
          if (!showSearch && route == null)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => _showSearch = true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, color: accent, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Search destination',
                            style: TextStyle(color: textSec, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Search panel (shown when showSearch is true) ──────────────────
          if (showSearch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1E1F26).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.2),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Text field row ──────────────────────────────
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 10, 8, 6),
                              child: Row(
                                children: [
                                  Icon(Icons.search_rounded,
                                      color: accent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      onChanged: _onSearchChanged,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 15),
                                      cursorColor: accent,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Where do you want to go?',
                                        hintStyle: TextStyle(
                                            color: textSec, fontSize: 14),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _searchLoadingNotifier,
                                    builder: (_, loading, __) => loading
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                                right: 6),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: accent,
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  IconButton(
                                    onPressed: _closeSearch,
                                    icon: Icon(Icons.close_rounded,
                                        color: textSec, size: 20),
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),

                            // ── Suggestions list ──────────────────────────
                            ValueListenableBuilder<List<Map<String, String>>>(
                              valueListenable: _placeSuggestionsNotifier,
                              builder: (_, suggestions, __) {
                                if (suggestions.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Divider(
                                        height: 1,
                                        color: accent.withAlpha(40)),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxHeight: 240),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 4),
                                        itemCount: suggestions.length,
                                        separatorBuilder: (_, __) =>
                                            Divider(
                                                height: 1,
                                                indent: 46,
                                                color:
                                                    accent.withAlpha(20)),
                                        itemBuilder: (context, i) {
                                          final s = suggestions[i];
                                          final desc =
                                              s['description'] ?? '';
                                          final parts = desc.split(',');
                                          final main =
                                              parts.first.trim();
                                          final secondary =
                                              parts.length > 1
                                                  ? parts
                                                      .sublist(1)
                                                      .join(',')
                                                      .trim()
                                                  : '';
                                          return InkWell(
                                            onTap: () =>
                                                _selectSuggestion(desc),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration:
                                                        BoxDecoration(
                                                      color:
                                                          accent.withAlpha(
                                                              25),
                                                      shape:
                                                          BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.place_rounded,
                                                      color: accent,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          main,
                                                          style: TextStyle(
                                                            color: textPri,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                        if (secondary
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            secondary,
                                                            style: TextStyle(
                                                                color:
                                                                    textSec,
                                                                fontSize:
                                                                    11),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.north_west_rounded,
                                                    color: textSec,
                                                    size: 14,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Build                                                                   â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isListening = _voice.isListening;
    final lightMode = AmbientLightProvider.of(context);
    final accent = LightThemePalette.accent(lightMode);
    final bg = LightThemePalette.background(lightMode);
    final surface = LightThemePalette.surface(lightMode);
    final textPri = LightThemePalette.textPrimary(lightMode);
    final textSec = LightThemePalette.textSecondary(lightMode);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // â”€â”€ Top Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              color: bg,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: Icon(Icons.menu, color: textPri),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  Text(
                    l10n.appTitle,
                    style: TextStyle(
                      color: textPri,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const LuxIndicator(),
                      const SizedBox(width: 4),
                      // ── Eyes-On-Road (Fatigue) button ─────────────────────
                      Tooltip(
                        message: 'Eyes-On-Road Monitor',
                        child: IconButton(
                          icon: Icon(Icons.remove_red_eye_rounded, color: textPri),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FatigueDetectionScreen()),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Link Vehicle',
                        child: IconButton(
                          icon: Icon(Icons.qr_code_scanner_rounded, color: textPri),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CarPairingScreen()),
                            );
                            if (result != null && result is Map<String, String>) {
                              _activeVehicle = result;
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.history, color: textPri),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HistoryScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // â”€â”€ Mode Toggle Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildModeToggle(bg, surface, accent, textPri, textSec),

            // ── Speed Limit Banner ────────────────────────────────
            _buildSpeedLimitBanner(accent, textPri),

            // ── Active Vehicle Badge ──────────────────────────────
            _buildActiveVehicleBadge(accent, textPri, textSec),

            // ── GPS + Voice Status Row ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _hasGPSNotifier,
                    builder: (_, hasGPS, __) => Icon(Icons.gps_fixed, color: hasGPS ? accent : Colors.grey, size: 14),
                  ),
                  const SizedBox(width: 4),
                  ValueListenableBuilder2<bool, int>(
                    _hasGPSNotifier,
                    _satellitesNotifier,
                    (context, hasGPS, sats) => ValueListenableBuilder2<AppMode, bool>(
                      _appModeNotifier,
                      _simRunningNotifier,
                      (context, mode, simRunning) => Text(
                        mode == AppMode.simulation
                            ? 'SIM MODE  •  ${simRunning ? "Moving" : "Idle"}'
                            : 'GPS: ${hasGPS ? "Yes" : "No"}  ($sats sat)',
                        style: TextStyle(color: textSec, fontSize: 12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Voice status chip
                  ValueListenableBuilder<String>(
                    valueListenable: _voiceStatusNotifier,
                    builder: (context, status, _) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'Listening…' ? accent.withAlpha(40) : surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: status == 'Listening…' ? accent : accent.withAlpha(60)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == 'Listening…' ? Icons.mic : Icons.mic_none,
                            size: 12,
                            color: status == 'Listening…' ? accent : textSec,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              status,
                              style: TextStyle(color: status == 'Listening…' ? accent : textSec, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Main View & Overlays ────────────────────────────
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _currentIndexNotifier,
                builder: (context, idx, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final maxLeft = (constraints.maxWidth - 290.0).clamp(0.0, double.infinity);
                    
                    return Stack(
                      children: [
                        // The Primary content (Map / Gauge / Music)
                        ValueListenableBuilder2<double, bool>(
                          _currentSpeedNotifier,
                          _isOverLimitNotifier,
                          (context, _, __) => _buildSpeedWarningWrapper(_buildCurrentView()),
                        ),

                        // Simulation speed slider overlay
                        ValueListenableBuilder<AppMode>(
                          valueListenable: _appModeNotifier,
                          builder: (context, mode, _) {
                            if (mode != AppMode.simulation) return const SizedBox.shrink();
                            return ValueListenableBuilder<Offset>(
                              valueListenable: _simSliderOffsetNotifier,
                              builder: (context, offset, _) {
                                final h = _simSliderMinimized ? 48.0 : 120.0;
                                final maxTop = (constraints.maxHeight - h).clamp(0.0, double.infinity);
                                
                                return Positioned(
                                  left: offset.dx.clamp(0.0, maxLeft),
                                  top: offset.dy.clamp(0.0, maxTop),
                                  child: GestureDetector(
                                    onPanUpdate: (d) => _simSliderOffset = Offset(
                                      (_simSliderOffset.dx + d.delta.dx).clamp(0.0, maxLeft),
                                      (_simSliderOffset.dy + d.delta.dy).clamp(0.0, maxTop),
                                    ),
                                    child: _buildSimSpeedSlider(accent, textPri, textSec),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        // --- NEW: Bottom Overlays (Speed Circle, Stats & Draggable Panel) ---
                        // These are now overlays to prevent pushing the Map expanded out of view
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: ValueListenableBuilder<AppMode>(
                            valueListenable: _appModeNotifier,
                            builder: (context, mode, _) => ValueListenableBuilder2<bool, bool>(
                              _simRunningNotifier,
                              _isTrackingNotifier,
                              (context, simRunning, isTracking) => Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Bottom Stats / Speed Circle group
                                  Builder(builder: (context) {
                                    final active = (mode == AppMode.simulation && _activeRoute != null && simRunning) ||
                                                 (mode != AppMode.simulation && isTracking);
                                    if (!active) return const SizedBox.shrink();

                                    return Padding(
                                      padding: const EdgeInsets.only(left: 16, bottom: 16),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          // Speed Circle
                                          ValueListenableBuilder2<double, bool>(
                                            _currentSpeedNotifier,
                                            _isOverLimitNotifier,
                                            (context, speed, over) => Container(
                                              width: 80, height: 80,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF1C1C1E),
                                                border: Border.all(color: over ? const Color(0xFFFF453A) : accent, width: 3),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: over ? const Color(0xFFFF453A).withAlpha(120) : accent.withAlpha(100),
                                                    blurRadius: 16, spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      speed.toStringAsFixed(0),
                                                      style: TextStyle(
                                                        color: over ? const Color(0xFFFF453A) : Colors.white,
                                                        fontSize: 32, fontWeight: FontWeight.w800, height: 1.0,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text('km/h', style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          
                                          // Navigation Stats Pill
                                          ValueListenableBuilder<RouteInfo?>(
                                            valueListenable: _activeRouteNotifier,
                                            builder: (context, route, _) {
                                              if (route == null) return const SizedBox.shrink();
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 12),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xEE1C1C1E),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: accent.withAlpha(80)),
                                                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
                                                  ),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.timer_outlined, color: accent, size: 14),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            route.durationText,
                                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Icon(Icons.route_outlined, color: accent, size: 14),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            route.distanceText,
                                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.access_time_rounded, color: Colors.white54, size: 13),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'Reach at ${_getArrivalTime(route.durationSeconds)}',
                                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  // Draggable Bottom Panel (as an overlay at the very bottom of the Stack)
                                  if (idx == 0 || idx == 1)
                                    ValueListenableBuilder<double>(
                                      valueListenable: _bottomPanelHeightNotifier,
                                      builder: (context, height, _) => GestureDetector(
                                        onVerticalDragUpdate: _onPanelDrag,
                                        onVerticalDragEnd: _onPanelDragEnd,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeOut,
                                          clipBehavior: Clip.hardEdge,
                                          height: height,
                                          color: bg,
                                          child: _buildBottomPanel(accent, bg, surface, textPri, textSec),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _currentIndexNotifier,
              builder: (context, idx, _) => _buildCustomNavBar(bg, accent, textSec),
            ),
          ],
        ),
      ),
    );
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Mode Toggle                                                             â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildModeToggle(Color bg, Color surface, Color accent, Color textPri, Color textSec) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<AppMode>(
      valueListenable: _appModeNotifier,
      builder: (context, currentMode, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Label
              Icon(Icons.settings_suggest, size: 16, color: textSec),
              const SizedBox(width: 6),
              Text('${l10n.mode}:', style: TextStyle(color: textSec, fontSize: 12)),
              const SizedBox(width: 8),
        
              // Toggle pill
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accent.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _modeChip(l10n.dev, Icons.developer_mode, AppMode.dev, currentMode == AppMode.dev, accent, textSec),
                    _modeChip(l10n.simulation, Icons.play_circle_fill, AppMode.simulation, currentMode == AppMode.simulation, accent, textSec),
                    _modeChip('Live', Icons.navigation, AppMode.live, currentMode == AppMode.live, accent, textSec),
                  ],
                ),
              ),
        
              const SizedBox(width: 16), // Replaced Spacer for horizontal scrolling
        
              // Live speed indicator (shown only while simulation is running)
              if (currentMode == AppMode.simulation)
                ValueListenableBuilder<bool>(
                  valueListenable: _simRunningNotifier,
                  builder: (context, simRunning, _) {
                    if (!simRunning) return const SizedBox.shrink();
                    return ValueListenableBuilder<double>(
                      valueListenable: _simSpeedKmhNotifier,
                      builder: (context, simSpeed, _) => Row(
                        children: [
                          const Icon(Icons.directions_car, size: 14, color: Color(0xFF00FF88)),
                          const SizedBox(width: 4),
                          Text(
                            '${simSpeed.toInt()} km/h',
                            style: const TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, IconData icon, AppMode mode, bool selected, Color accent, Color textSec) {
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? accent : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? Colors.black : textSec),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: selected ? Colors.black : textSec, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Speed Limit Banner                                                      â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSpeedLimitBanner(Color accent, Color textPri) {
    return ValueListenableBuilder2<int?, bool>(
      _speedLimitNotifier,
      _isOverLimitNotifier,
      (context, limit, over) {
        if (limit == null && !over) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: over ? const Color(0xFFFF1744).withAlpha(30) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: over ? const Color(0xFFFF1744) : accent.withAlpha(80),
              width: over ? 2 : 1,
            ),
            boxShadow: over ? [BoxShadow(color: const Color(0xFFFF1744).withAlpha(80), blurRadius: 12, spreadRadius: 2)] : [],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white,
                  border: Border.all(color: over ? const Color(0xFFFF1744) : Colors.red.shade700, width: 3),
                ),
                child: Center(
                  child: Text(
                    limit?.toString() ?? '?',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: limit != null && limit >= 100 ? 13 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      over ? 'âš ï¸   Speed Limit Exceeded!' : 'Speed Limit: $limit km/h',
                      style: TextStyle(
                        color: over ? const Color(0xFFFF1744) : textPri,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (over)
                      ValueListenableBuilder<double>(
                        valueListenable: _currentSpeedNotifier,
                        builder: (context, speed, _) => Text(
                          'Current: ${speed.toInt()} km/h  Â·  Limit: $limit km/h',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                over ? Icons.warning_amber_rounded : Icons.speed,
                color: over ? const Color(0xFFFF1744) : accent,
                size: 22,
              ),
            ],
          ),
        );
      },
    );
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Speed Warning Wrapper (pulsing red overlay when over limit)             â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSpeedWarningWrapper(Widget child) {
    return Stack(
      children: [
        RepaintBoundary(child: child),
        ValueListenableBuilder<bool>(
          valueListenable: _isOverLimitNotifier,
          builder: (context, over, _) {
            if (!over) return const SizedBox.shrink();
            return Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseRedAnim,
                  builder: (_, __) => CustomPaint(
                    painter: _VignettePainter(opacity: _pulseRedAnim.value),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActiveVehicleBadge(Color accent, Color textPri, Color textSec) {
    return ValueListenableBuilder<Map<String, String>?>(
      valueListenable: _activeVehicleNotifier,
      builder: (context, vehicle, _) {
        if (vehicle == null) return const SizedBox.shrink();
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withAlpha(38), // 0.15 * 255 = 38.25
                const Color(0xFF1E1F26).withAlpha(204), // 0.8 * 255 = 204
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withAlpha(76), width: 1.5), // 0.3 * 255 = 76.5
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(25), // 0.1 * 255 = 25.5
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withAlpha(25), // 0.1 * 255 = 25.5
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_car_filled_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CONNECTED VEHICLE',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${vehicle['vehicleId']} â€¢ ${vehicle['ownerName']}',
                      style: TextStyle(
                        color: textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Disconnect Button
              GestureDetector(
                onTap: () {
                  _activeVehicle = null;
                  _voice.speak('Vehicle disconnected. Returning to standalone mode.');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(25), // 0.1 * 255 = 25.5
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withAlpha(76)), // 0.3 * 255 = 76.5
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'UNLINK',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Simulation Speed Slider                                                 â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSimSpeedSlider(Color accent, Color textPri, Color textSec) {
    final l10n = AppLocalizations.of(context)!;
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: _simSliderMinimizedNotifier,
        builder: (context, minimized, _) => Container(
          width: 290,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xEE1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withAlpha(80)),
            boxShadow: [BoxShadow(color: accent.withAlpha(40), blurRadius: 14)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                children: [
                  const Icon(Icons.speed, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${l10n.simulation} ${l10n.gauge}',
                    style: TextStyle(color: textSec, fontSize: 12),
                  ),
                  const Spacer(),
                  // Speed chip
                  ValueListenableBuilder2<double, bool>(
                    _simSpeedKmhNotifier,
                    _isOverLimitNotifier,
                    (context, simSpeed, over) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: over ? const Color(0xFFFF1744).withAlpha(40) : accent.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: over ? const Color(0xFFFF1744) : accent),
                      ),
                      child: Text(
                        '${simSpeed.toInt()} km/h',
                        style: TextStyle(
                          color: over ? const Color(0xFFFF1744) : accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Minimize toggle
                  GestureDetector(
                    onTap: () => _simSliderMinimized = !_simSliderMinimized,
                    child: Icon(
                      minimized ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                      color: textSec,
                      size: 22,
                    ),
                  ),
                ],
              ),
              // Slider + labels
              if (!minimized) ...[
                ValueListenableBuilder2<double, bool>(
                  _simSpeedKmhNotifier,
                  _isOverLimitNotifier,
                  (context, simSpeed, over) => Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbColor: over ? const Color(0xFFFF1744) : accent,
                          activeTrackColor: over ? const Color(0xFFFF1744) : accent,
                          inactiveTrackColor: Colors.white12,
                          overlayColor: (over ? const Color(0xFFFF1744) : accent).withAlpha(30),
                        ),
                        child: Slider(
                          value: simSpeed,
                          min: 0,
                          max: 150,
                          divisions: 150,
                          onChanged: _onSimSpeedChanged,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0', style: TextStyle(color: textSec, fontSize: 10)),
                          ValueListenableBuilder<int?>(
                            valueListenable: _speedLimitNotifier,
                            builder: (context, limit, _) => limit != null
                                ? Text('Limit: $limit km/h', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10))
                                : const SizedBox.shrink(),
                          ),
                          Text('150', style: TextStyle(color: textSec, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Current View (Gauge / Digital / Map)                                    â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildCurrentView() {
    Widget child;
    switch (_currentIndex) {
      case 0:
        child = ValueListenableBuilder2<double, bool>(
          _currentSpeedNotifier,
          _isOverLimitNotifier,
          (context, speed, over) => ValueListenableBuilder2<int, bool>(
            _satellitesNotifier,
            _hasGPSNotifier,
            (context, sats, hasGPS) => ValueListenableBuilder<int?>(
              valueListenable: _speedLimitNotifier,
              builder: (context, limit, _) => GaugeView(
                key: const ValueKey(0),
                speed: speed,
                satellites: sats,
                hasGPS: hasGPS,
                isOverLimit: over,
                speedLimit: limit,
              ),
            ),
          ),
        );
        break;
      case 1:
        child = ValueListenableBuilder2<Position?, double>(
          _currentPositionNotifier,
          _currentSpeedNotifier,
          (context, pos, speed) => ValueListenableBuilder2<bool, int?>(
            _isOverLimitNotifier,
            _speedLimitNotifier,
            (context, over, limit) => ValueListenableBuilder<RouteInfo?>(
              valueListenable: _activeRouteNotifier,
              builder: (context, route, _) => Stack(
                key: const ValueKey(1),
                children: [
                  MapView(
                    currentPosition: pos,
                    speed: speed,
                    activeRoute: route,
                    onStopNavigation: _stopNavigation,
                    speedLimit: limit,
                    isOverLimit: over,
                    isSimulation: _isSimMode,
                  ),
                  _buildSearchOverlay(),
                ],
              ),
            ),
          ),
        );
        break;
      case 2:
        child = ValueListenableBuilder2<double, bool>(
          _currentSpeedNotifier,
          _isOverLimitNotifier,
          (context, speed, over) => MusicPlayerView(
            key: const ValueKey(2),
            accent: const Color(0xFF00C2FF),
            bg: const Color(0xFF14151A),
            textPri: Colors.white,
            textSec: Colors.white54,
            speed: speed,
            isOverLimit: over,
          ),
        );
        break;
      default:
        child = const SizedBox(key: ValueKey(-1));
    }
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  String _formatDuration(Duration duration) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(duration.inHours)}:${pad(duration.inMinutes.remainder(60))}:${pad(duration.inSeconds.remainder(60))}';
  }

  String _getArrivalTime(int durationSeconds) {
    final now = DateTime.now();
    final arrival = now.add(Duration(seconds: durationSeconds));
    final period = arrival.hour >= 12 ? 'PM' : 'AM';
    final hour = arrival.hour == 0 ? 12 : (arrival.hour > 12 ? arrival.hour - 12 : arrival.hour);
    final minute = arrival.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Bottom Panel                                                            â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildBottomPanel(
    Color accent,
    Color bg,
    Color surface,
    Color textPri,
    Color textSec,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final showStats = _bottomPanelHeight > _panelMid - 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: bg,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // â”€â”€ Drag Handle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: textSec.withAlpha(90),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // â”€â”€ Stats (hidden when panel is at button-only or min height) â”€â”€â”€â”€â”€â”€
          if (showStats) ...[
          const SizedBox(height: 8),
          // Consolidated Timer & Stats Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withAlpha(40)),
            ),
            child: ValueListenableBuilder<RouteInfo?>(
              valueListenable: _activeRouteNotifier,
              builder: (context, route, _) => ValueListenableBuilder2<Duration, double>(
                _elapsedNotifier,
                _totalDistanceNotifier,
                (context, elapsed, distance) => ValueListenableBuilder2<double, double>(
                  _avgSpeedNotifier,
                  _maxSpeedNotifier,
                  (context, avgSpeed, maxSpeed) => route != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(flex: 3, child: _buildCompactStat(Icons.timer, _formatDuration(elapsed), '', accent, textPri, textSec)),
                            Container(width: 1, height: 24, color: accent.withAlpha(40)),
                            Expanded(flex: 2, child: _buildCompactStat(Icons.access_time_filled, route.durationText, 'ETA', const Color(0xFF00E5FF), textPri, textSec)),
                            Container(width: 1, height: 24, color: accent.withAlpha(40)),
                            Expanded(flex: 2, child: _buildCompactStat(Icons.route, route.distanceText, l10n.distance, const Color(0xFF00E5FF), textPri, textSec)),
                            Container(width: 1, height: 24, color: accent.withAlpha(40)),
                            Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.flag_rounded, color: Color(0xFF00E5FF), size: 14),
                                        const SizedBox(width: 4),
                                        Text(route.destination, style: TextStyle(color: textPri, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Dest', style: TextStyle(color: textSec, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(flex: 3, child: _buildCompactStat(Icons.timer, _formatDuration(elapsed), '', accent, textPri, textSec)),
                            Container(width: 1, height: 24, color: accent.withAlpha(40)),
                            Expanded(flex: 2, child: _buildCompactStat(Icons.route, distance.toStringAsFixed(0), l10n.distance, accent, textPri, textSec)),
                            Container(width: 1, height: 24, color: accent.withAlpha(40)),
                            Expanded(flex: 2, child: _buildCompactStat(Icons.speed, avgSpeed.toStringAsFixed(0), l10n.avg, accent, textPri, textSec)),
                            Container(width: 1, height: 24, color: accent.withAlpha(40)),
                            Expanded(flex: 2, child: _buildCompactStat(Icons.bolt, maxSpeed.toStringAsFixed(0), l10n.max, accent, textPri, textSec)),
                          ],
                        ),
                ),
              ),
            ),
          ),
          ], // end if (showStats)

          const SizedBox(height: 8),

          // START/STOP Button and Mic Button
          ValueListenableBuilder<AppMode>(
            valueListenable: _appModeNotifier,
            builder: (context, mode, _) => ValueListenableBuilder<RouteInfo?>(
              valueListenable: _activeRouteNotifier,
              builder: (context, route, _) => ValueListenableBuilder2<bool, bool>(
                _simRunningNotifier,
                _isTrackingNotifier,
                (context, simRunning, isTracking) => Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _onStartStopPressed,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: (mode == AppMode.simulation && route != null)
                                ? (simRunning ? const Color(0xFFFF3B3B) : const Color(0xFF00FF88))
                                : (isTracking ? const Color(0xFFFF3B3B) : accent),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: ((mode == AppMode.simulation && route != null)
                                        ? (simRunning ? const Color(0xFFFF3B3B) : const Color(0xFF00FF88))
                                        : (isTracking ? const Color(0xFFFF3B3B) : accent))
                                    .withAlpha(80),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: _onStartStopPressed,
                              borderRadius: BorderRadius.circular(50),
                              splashColor: Colors.white24,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    (mode == AppMode.simulation && route != null)
                                        ? (simRunning ? l10n.stop : 'START JOURNEY')
                                        : (isTracking ? l10n.stop : l10n.start),
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    (mode == AppMode.simulation && route != null)
                                        ? (simRunning ? Icons.stop_rounded : Icons.navigation_rounded)
                                        : (isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildMicButton(accent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Mic Button                                                              â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildMicButton(Color accent) {
    final isListening = _voice.isListening;
    return GestureDetector(
      onTap: _onMicPressed,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: isListening ? _pulseAnim.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isListening
                  ? [const Color(0xFF00FF88), const Color(0xFF00C2FF)]
                  : [const Color(0xFF1E1F26), const Color(0xFF18191E)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isListening
                    ? const Color(0xFF00FF88).withAlpha(120)
                    : accent.withAlpha(40),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Helpers                                                                 â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildCompactStat(
    IconData icon,
    String value,
    String label,
    Color accent,
    Color textPri,
    Color textSec,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: textSec, fontSize: 10)),
        ]
      ],
    );
  }


  // â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  // â•‘  Custom Bottom Navigation                                                  â•‘
  // â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _onNavTap(int idx) {
    if (idx == 3) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TpmsScreen()));
    } else if (idx == 4) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()));
    } else {
      _currentIndex = idx;
    }
  }

  Widget _buildCustomNavBar(Color bg, Color accent, Color textSec) {
    const items = [
      (Icons.speed_rounded,          'Gauge',   0),
      (Icons.map_rounded,            'Map',     1),
      (Icons.music_note_rounded,     'Music',   2),
      (Icons.tire_repair_rounded,    'TPMS',    3),
      (Icons.person_rounded,         'Profile', 4),
    ];
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: SizedBox(
        height: 66,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Dark pill
            Positioned(
              bottom: 0, left: 0, right: 0, top: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF14151A).withAlpha(180),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(140),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Sliding Indicator
            Positioned(
              left: 0, right: 0, bottom: 0, top: 0,
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment(-1.0 + (_currentIndex * 2.0 / 4), 0.0), // Maps index 0..4 to -1.0 .. 1.0
                child: FractionallySizedBox(
                  widthFactor: 1 / 5,
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.only(top: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F26),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.map((item) {
                final (icon, label, idx) = item;
                final selected = _currentIndex == idx;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onNavTap(idx),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 66,
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        transform: Matrix4.translationValues(0, selected ? -10 : -4, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              color: selected ? accent : Colors.white54,
                              size: selected ? 26 : 22,
                              shadows: selected ? [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 10)] : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }


}


// â”€â”€â”€ History Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '—';
    try {
      final ts = timestamp as Timestamp;
      final d = ts.toDate();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final timeStr = '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
      return '${d.day} ${months[d.month - 1]} ${d.year}  •  $timeStr';
    } catch (_) { return '—'; }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final lightMode = AmbientLightProvider.of(context);
    final bg      = LightThemePalette.background(lightMode);
    final textPri = LightThemePalette.textPrimary(lightMode);
    final textSec = LightThemePalette.textSecondary(lightMode);
    final accent  = LightThemePalette.accent(lightMode);

    if (uid == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg, foregroundColor: textPri, elevation: 0,
          title: Text('Journey History', style: TextStyle(color: textPri, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_rounded, color: textSec, size: 56),
            const SizedBox(height: 16),
            Text('Please log in to view history', style: TextStyle(color: textSec, fontSize: 16)),
          ]),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textPri,
        elevation: 0,
        centerTitle: true,
        title: Text('Journey History',
            style: TextStyle(color: textPri, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: accent));
          }
          if (snapshot.hasError) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_rounded, color: textSec, size: 56),
              const SizedBox(height: 12),
              Text('Failed to load trips', style: TextStyle(color: textSec)),
            ]));
          }

          final filtered = snapshot.data?.docs ?? [];

          // Aggregate stats
          double totalDist = 0, maxSpd = 0, totalAvg = 0;
          int totalSecs = 0;
          for (final d in filtered) {
            final data = d.data() as Map<String, dynamic>;
            totalDist += (data['distance'] as num? ?? 0).toDouble();
            totalSecs += (data['durationSeconds'] as num? ?? 0).toInt();
            final spd = (data['maxSpeed'] as num? ?? 0).toDouble();
            if (spd > maxSpd) maxSpd = spd;
            totalAvg += (data['avgSpeed'] as num? ?? 0).toDouble();
          }
          final avgSpd = filtered.isNotEmpty ? totalAvg / filtered.length : 0.0;

          return CustomScrollView(
            slivers: [
              // ── Stats Banner ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F26).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: accent.withValues(alpha: 0.2)),
                          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 24)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statCell(Icons.route_rounded,        '${filtered.length}',                'Trips',      accent, textPri, textSec),
                            _statCell(Icons.straighten_rounded,   '${totalDist.toStringAsFixed(1)} km','Distance',   accent, textPri, textSec),
                            _statCell(Icons.timer_rounded,        _formatDuration(totalSecs),          'Drive Time', accent, textPri, textSec),
                            _statCell(Icons.speed_rounded,        '${maxSpd.toStringAsFixed(0)} km/h', 'Top Speed',  accent, textPri, textSec),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Count + avg header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      Text('${filtered.length} ${filtered.length == 1 ? 'trip' : 'trips'}',
                          style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w500)),
                      if (filtered.isNotEmpty) ...[
                        const Spacer(),
                        Text('Avg ${avgSpd.toStringAsFixed(0)} km/h',
                            style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Empty state ──
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.directions_car_outlined,
                        color: textSec.withValues(alpha: 0.35), size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'No journeys yet',
                      style: TextStyle(color: textSec, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text('Start a journey to see it here',
                        style: TextStyle(color: textSec.withValues(alpha: 0.55), fontSize: 14)),
                  ]),
                ),

              // ── Trip Cards ──
              if (filtered.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final doc   = filtered[i];
                        final data  = doc.data() as Map<String, dynamic>;
                        
                        // Extract destination name (optional)
                        final destName = data['destinationName'] as String?;
                        final tripTitle = destName != null && destName.isNotEmpty
                            ? 'Trip to $destName'
                            : 'Free Drive';

                        final vColor = const Color(0xFF00CFFF); // App accent color for cars
                        final dist  = (data['distance'] as num?)?.toStringAsFixed(2) ?? '0.00';
                        final maxS  = (data['maxSpeed'] as num?)?.toStringAsFixed(0) ?? '0';
                        final avgS  = (data['avgSpeed'] as num?)?.toStringAsFixed(0) ?? '0';
                        final dur   = _formatDuration((data['durationSeconds'] as num?)?.toInt() ?? 0);
                        final date  = _formatDate(data['timestamp']);

                        return Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4444).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xFF2A2A2A),
                                title: const Text('Delete trip?', style: TextStyle(color: Colors.white)),
                                content: const Text('This action cannot be undone.',
                                    style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text('Cancel', style: TextStyle(color: textSec)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) async {
                            await FirebaseFirestore.instance
                                .collection('trips').doc(doc.id).delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Trip deleted'),
                                backgroundColor: Color(0xFF2A2A2A),
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1B22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: vColor.withValues(alpha: 0.2)),
                              boxShadow: [BoxShadow(
                                color: vColor.withValues(alpha: 0.07),
                                blurRadius: 16, offset: const Offset(0, 4),
                              )],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: vColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: vColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Icon(Icons.directions_car_rounded, color: vColor, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(tripTitle,
                                              style: TextStyle(color: textPri, fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(date,
                                              style: TextStyle(color: textSec, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: vColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(dur,
                                          style: TextStyle(color: vColor, fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ]),
                                  const SizedBox(height: 12),
                                  // Stats row
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _miniStat(Icons.speed_rounded,       '$maxS km/h', 'Max Speed', textPri, textSec, accent),
                                        Container(width: 1, height: 30, color: textSec.withValues(alpha: 0.15)),
                                        _miniStat(Icons.trending_up_rounded, '$avgS km/h', 'Avg Speed', textPri, textSec, accent),
                                        Container(width: 1, height: 30, color: textSec.withValues(alpha: 0.15)),
                                        _miniStat(Icons.route_rounded,       '$dist km',   'Distance',  textPri, textSec, accent),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCell(IconData icon, String value, String label,
      Color accent, Color textPri, Color textSec) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: accent, size: 20),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: textPri, fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: textSec, fontSize: 10)),
    ]);
  }

  Widget _miniStat(IconData icon, String value, String label,
      Color textPri, Color textSec, Color accent) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: accent, size: 14),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: textPri, fontSize: 12, fontWeight: FontWeight.w700)),
      Text(label, style: TextStyle(color: textSec, fontSize: 10)),
    ]);
  }
}

// SettingsScreen is provided by app_drawer.dart

// â”€â”€â”€ Vignette Painter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// Draws a danger vignette (red glow at screen edges) that pulses with [opacity].
/// Uses 4 linear-gradient rects (top / bottom / left / right) so every corner
/// is covered equally regardless of screen aspect ratio.
class _VignettePainter extends CustomPainter {
  final double opacity; // 0.0 = invisible, 1.0 = full danger

  const _VignettePainter({required this.opacity});

  static const _color = Color(0xFFFF1744);

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final vignetteDepth = size.shortestSide * 0.55;

    void drawEdge(Rect rect, Alignment start, Alignment end) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: start,
          end: end,
          colors: [
            _color.withValues(alpha: opacity * 0.78),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    // Top edge
    drawEdge(
      Rect.fromLTWH(0, 0, size.width, vignetteDepth),
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    // Bottom edge
    drawEdge(
      Rect.fromLTWH(0, size.height - vignetteDepth, size.width, vignetteDepth),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );
    // Left edge
    drawEdge(
      Rect.fromLTWH(0, 0, vignetteDepth, size.height),
      Alignment.centerLeft,
      Alignment.centerRight,
    );
    // Right edge
    drawEdge(
      Rect.fromLTWH(size.width - vignetteDepth, 0, vignetteDepth, size.height),
      Alignment.centerRight,
      Alignment.centerLeft,
    );
  }

  @override
  bool shouldRepaint(_VignettePainter old) => old.opacity != opacity;
}

/// A utility to listen to two [ValueListenable]s simultaneously.
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b) builder;

  const ValueListenableBuilder2(this.first, this.second, this.builder, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, _) => builder(context, a, b),
        );
      },
    );
  }
}

/// A utility to listen to three [ValueListenable]s simultaneously.
class ValueListenableBuilder3<A, B, C> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final ValueListenable<C> third;
  final Widget Function(BuildContext context, A a, B b, C c) builder;

  const ValueListenableBuilder3(this.first, this.second, this.third, this.builder, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder2<B, C>(
          second,
          third,
          (context, b, c) => builder(context, a, b, c),
        );
      },
    );
  }
}
