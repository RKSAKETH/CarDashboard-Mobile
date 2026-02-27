import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gauge_view.dart';
import '../widgets/digital_view.dart';
import '../widgets/map_view.dart';
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
import '../services/incident_service.dart';

// ─── App Mode ───────────────────────────────────────────────────────────────

enum AppMode { dev, simulation }

// ─── HomeScreen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  VehicleType _vehicleType = VehicleType.motorcycle;
  bool _isTracking = false;

  // ── Mode ──────────────────────────────────────────────────────────────────
  AppMode _appMode = AppMode.dev;
  bool get _isSimMode => _appMode == AppMode.simulation;

  // ── Speed tracking data ───────────────────────────────────────────────────
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _totalDistance = 0.0;
  double _avgSpeed = 0.0;
  int _satellites = 0;
  bool _hasGPS = false;

  // ── Speed Limit ───────────────────────────────────────────────────────────
  int? _speedLimit;
  bool _isOverLimit = false;
  Timer? _warningRepeatTimer;     // repeating TTS loop while over limit
  DateTime? _lastLimitFetch;
  Timer? _speedLimitTimer;
  late AnimationController _pulseRedController;
  late Animation<double> _pulseRedAnim; // 0.0 → 1.0 (vignette opacity)

  // ── Timer ─────────────────────────────────────────────────────────────────
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // ── Services ──────────────────────────────────────────────────────────────
  final LocationService _locationService = LocationService();
  final HistoryService _historyService = HistoryService();
  final VoiceAssistantService _voice = VoiceAssistantService();
  final SpeedLimitService _speedLimitService = SpeedLimitService();
  final SimulationService _simService = SimulationService();

  // ── Location ──────────────────────────────────────────────────────────────
  Position? _currentPosition;

  // ── Voice state ───────────────────────────────────────────────────────────
  bool _voiceReady = false;
  String _voiceStatus = 'Initialising…';

  // ── Active route ──────────────────────────────────────────────────────────
  RouteInfo? _activeRoute;

  // ── Simulation speed slider ───────────────────────────────────────────────
  double _simSpeedKmh = 30.0;

  // ── Simulation ongoing flag ───────────────────────────────────────────────
  bool _simRunning = false;

  // ── Place Search ──────────────────────────────────────────────────────────
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _placeSuggestions = [];
  bool _searchLoading = false;
  Timer? _searchDebounce;

  // ── Mic pulse animation ───────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Lifecycle                                                               ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

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

    // Danger vignette animation for speed-limit warning (0=invisible → 1=full)
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
        setState(() => _simRunning = false);
        _voice.speak('You have arrived at your destination!');
      }
    };

    // Always subscribe to simulation stream – works even without real GPS
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
        setState(() => _voiceStatus = 'Mic permission denied');
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
      if (mounted) setState(() => _voiceStatus = status);
    };

    _voice.onRouteFound = (route) {
      if (mounted) {
        setState(() {
          _activeRoute = route;
          _currentIndex = 2; // switch to map
        });
        // In simulation mode, kick off the simulation automatically
        if (_isSimMode) {
          _startSimulation(route);
        }
      }
    };

    _voice.onNavigationStopped = () {
      if (mounted) {
        setState(() => _activeRoute = null);
        if (_isSimMode) _stopSimulation();
      }
    };

    _voice.onArrived = () {
      if (mounted) {
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
      if (mounted) setState(() => _currentIndex = index);
    };

    _voice.onOpenSettings = () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    };

    if (mounted) {
      setState(() {
        _voiceReady = true;
        _voiceStatus = 'Tap mic to speak';
      });
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
    _voice.dispose();
    _simService.dispose();
    IncidentService.instance.stop();
    super.dispose();
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Permissions & Location                                                  ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

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
          setState(() {
            _currentPosition = position;
            _hasGPS = true;
          });
        }
        _voice.updatePosition(position);
        return;
      }
      // Dev mode – use real GPS
      _onPositionUpdate(position);
    });

  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _currentSpeed = position.speed * 3.6;
      _satellites = position.accuracy.toInt();
      _hasGPS = true;

      if (_isTracking && _currentSpeed > _maxSpeed) {
        _maxSpeed = _currentSpeed;
      }
    });
    _voice.updatePosition(position);
    _checkSpeedLimit(position.latitude, position.longitude);
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Speed Limit                                                             ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

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
    setState(() => _speedLimit = limit);
    _evaluateSpeedExceedance();
  }

  void _evaluateSpeedExceedance() {
    // No limit known yet — don't disturb existing state
    if (_speedLimit == null) return;

    final over = _currentSpeed > _speedLimit!;

    if (over && !_isOverLimit) {
      // → Just crossed above the limit
      setState(() => _isOverLimit = true);
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
    setState(() => _isOverLimit = false);
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

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Mode Toggle                                                             ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  void _switchMode(AppMode mode) {
    if (mode == _appMode) return;

    // Stop simulation if switching away
    if (_appMode == AppMode.simulation) {
      _stopSimulation();
    }

    setState(() {
      _appMode = mode;
      _currentSpeed = 0;
      _isOverLimit = false;
      _speedLimit = null;
    });

    _warningRepeatTimer?.cancel();
    _warningRepeatTimer = null;
    _pulseRedController.stop();
    _pulseRedController.reset();
    _speedLimitService.clearCache();
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Simulation                                                              ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  void _startSimulation(RouteInfo route) {
    if (route.polylinePoints.isEmpty) return;

    // If no real GPS, seed position from route start so the map renders
    if (_currentPosition == null) {
      final start = route.polylinePoints.first;
      setState(() {
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
      });
    }

    _simService.targetSpeedKmh = _simSpeedKmh;
    _simService.startRoute(route.polylinePoints, initialSpeedKmh: _simSpeedKmh);
    setState(() => _simRunning = true);
  }

  void _stopSimulation() {
    _simService.stop();
    setState(() {
      _simRunning = false;
      _currentSpeed = 0;
    });
  }

  void _onSimSpeedChanged(double value) {
    setState(() {
      _simSpeedKmh = value;
      if (_simRunning) _currentSpeed = value;
    });
    _simService.targetSpeedKmh = value;

    if (_simRunning) {
      if (_speedLimit != null) {
        // We already have a limit — evaluate immediately
        _evaluateSpeedExceedance();
      } else if (_currentPosition != null) {
        // No limit cached yet — fetch it now (ignores the rate-limit timer)
        _lastLimitFetch = null;
        _checkSpeedLimit(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
    }
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Tracking                                                                ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Future<void> _loadTotalDistance() async {
    final distance = await _historyService.getTotalDistance();
    setState(() => _totalDistance = distance);
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
      if (_isTracking) {
        _startTimer();
        _resetCurrentSession();
      } else {
        _stopTimer();
        _saveSession();
      }
    });
  }

  /// Smart handler for the main START/STOP button.
  /// – Sim mode + active route: starts/stops the navigation journey.
  /// – Otherwise: toggles the session tracking timer as usual.
  void _onStartStopPressed() {
    if (_isSimMode && _activeRoute != null) {
      if (_simRunning) {
        // Stop the journey
        _stopSimulation();
        _stopTimer();
        setState(() => _isTracking = false);
        _saveSession();
      } else {
        // Start the journey
        _resetCurrentSession();
        _startTimer();
        setState(() => _isTracking = true);
        _startSimulation(_activeRoute!);
      }
    } else {
      _toggleTracking();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
        _updateAvgSpeed();
      });
    });
  }

  void _stopTimer() => _timer?.cancel();

  void _resetCurrentSession() {
    setState(() {
      _maxSpeed = 0.0;
      _avgSpeed = 0.0;
      _elapsed = Duration.zero;
    });
  }

  void _updateAvgSpeed() {
    if (_elapsed.inSeconds > 0) {
      setState(() {
        _avgSpeed = (_totalDistance / _elapsed.inSeconds) * 3600;
      });
    }
  }

  Future<void> _saveSession() async {
    if (_elapsed.inSeconds > 0) {
      await _historyService.saveSession(
        distance: _totalDistance,
        maxSpeed: _maxSpeed,
        avgSpeed: _avgSpeed,
        duration: _elapsed,
        vehicleType: _vehicleType,
      );
    }
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Voice                                                                   ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

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
    setState(() => _activeRoute = null);
    if (_isSimMode) _stopSimulation();
    _voice.speak('Navigation stopped.');
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Place Search                                                            ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _placeSuggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searchLoading = true);
      final results = await _voice.fetchPlaceSuggestions(
        query,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );
      if (mounted) setState(() { _placeSuggestions = results; _searchLoading = false; });
    });
  }

  void _selectSuggestion(String description) {
    _searchController.clear();
    setState(() {
      _showSearch = false;
      _placeSuggestions = [];
    });
    _voice.navigateTo(description);
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() { _showSearch = false; _placeSuggestions = []; });
  }

  Widget _buildSearchOverlay() {
    final lightMode = AmbientLightProvider.of(context);
    final accent  = LightThemePalette.accent(lightMode);
    final textPri = LightThemePalette.textPrimary(lightMode);
    final textSec = LightThemePalette.textSecondary(lightMode);

    return Stack(
      children: [
        // ── Search button (shown when search closed + no active route) ────────
        if (!_showSearch && _activeRoute == null)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => setState(() => _showSearch = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xEE1A1A2E),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: accent.withAlpha(120), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withAlpha(50),
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

        // ── Search panel (shown when _showSearch is true) ────────────────────
        if (_showSearch)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                decoration: BoxDecoration(
                  color: const Color(0xF51A1A2E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withAlpha(120), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withAlpha(60),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Text field row ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: _onSearchChanged,
                              style: TextStyle(color: textPri, fontSize: 15),
                              cursorColor: accent,
                              decoration: InputDecoration(
                                hintText: 'Where do you want to go?',
                                hintStyle: TextStyle(color: textSec, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchLoading)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accent,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: _closeSearch,
                            icon: Icon(Icons.close_rounded, color: textSec, size: 20),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // ── Suggestions list ────────────────────────────────────
                    if (_placeSuggestions.isNotEmpty) ...[
                      Divider(height: 1, color: accent.withAlpha(40)),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _placeSuggestions.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, indent: 46, color: accent.withAlpha(20)),
                          itemBuilder: (context, i) {
                            final s = _placeSuggestions[i];
                            final desc = s['description'] ?? '';
                            // Split into main / secondary parts
                            final parts = desc.split(',');
                            final main = parts.first.trim();
                            final secondary = parts.length > 1
                                ? parts.sublist(1).join(',').trim()
                                : '';
                            return InkWell(
                              onTap: () => _selectSuggestion(desc),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: accent.withAlpha(25),
                                        shape: BoxShape.circle,
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
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            main,
                                            style: TextStyle(
                                              color: textPri,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (secondary.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              secondary,
                                              style: TextStyle(
                                                  color: textSec, fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                    ] else if (!_searchLoading &&
                        _searchController.text.trim().isNotEmpty) ...[
                      Divider(height: 1, color: accent.withAlpha(40)),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'No results found. Try a different query.',
                          style: TextStyle(color: textSec, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Build                                                                   ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

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
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────────────
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
                      IconButton(
                        icon: Icon(Icons.history, color: textPri),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HistoryScreen()),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.person, color: textPri),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Mode Toggle Bar ───────────────────────────────────────────────
            _buildModeToggle(bg, surface, accent, textPri, textSec),

            // ── Speed Limit Banner ────────────────────────────────────────────
            if (_speedLimit != null || _isOverLimit)
              _buildSpeedLimitBanner(accent, textPri),

            // ── GPS + Voice Status Row ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.gps_fixed,
                    color: _hasGPS ? accent : Colors.grey,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isSimMode
                        ? 'SIM MODE  •  ${_simRunning ? "Moving" : "Idle"}'
                        : 'GPS: ${_hasGPS ? "Yes" : "No"}  ($_satellites sat)',
                    style: TextStyle(color: textSec, fontSize: 12),
                  ),
                  const Spacer(),
                  // Voice status chip
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isListening
                          ? accent.withAlpha(40)
                          : surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isListening
                            ? accent
                            : accent.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isListening
                              ? Icons.mic
                              : Icons.mic_none,
                          size: 12,
                          color: isListening ? accent : textSec,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 160),
                          child: Text(
                            _voiceStatus,
                            style: TextStyle(
                              color:
                                  isListening ? accent : textSec,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Main View ────────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  // Speed-limit red pulse wrapper
                  _buildSpeedWarningWrapper(_buildCurrentView()),

                  // ── Simulation Speed Slider ────────────────────────────────
                  if (_isSimMode)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 90,
                      child: _buildSimSpeedSlider(accent, textPri, textSec),
                    ),
                ],
              ),
            ),

            // ── Bottom Stats and Controls ────────────────────────────────────
            _buildBottomPanel(accent, bg, surface, textPri, textSec),

            // ── Bottom Navigation ────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                    top: BorderSide(color: accent.withAlpha(60), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.speed, l10n.gauge, 0, accent, textSec),
                  _buildNavItem(
                      Icons.filter_9_plus, l10n.digital, 1, accent, textSec),
                  _buildNavItem(Icons.map, l10n.map, 2, accent, textSec),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Mode Toggle                                                             ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildModeToggle(
    Color bg,
    Color surface,
    Color accent,
    Color textPri,
    Color textSec,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                _modeChip(
                  l10n.dev, Icons.developer_mode,
                  AppMode.dev, accent, textSec,
                ),
                _modeChip(
                  l10n.simulation, Icons.play_circle_fill,
                  AppMode.simulation, accent, textSec,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Live speed indicator (shown only while simulation is running)
          if (_isSimMode && _simRunning)
            Row(children: [
              const Icon(Icons.directions_car,
                  size: 14, color: Color(0xFF00FF88)),
              const SizedBox(width: 4),
              Text(
                '${_simSpeedKmh.toInt()} km/h',
                style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _modeChip(
    String label,
    IconData icon,
    AppMode mode,
    Color accent,
    Color textSec,
  ) {
    final selected = _appMode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? Colors.black : textSec),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : textSec,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Speed Limit Banner                                                      ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildSpeedLimitBanner(Color accent, Color textPri) {
    final over = _isOverLimit;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: over
            ? const Color(0xFFFF1744).withAlpha(30)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: over ? const Color(0xFFFF1744) : accent.withAlpha(80),
          width: over ? 2 : 1,
        ),
        boxShadow: over
            ? [
                BoxShadow(
                  color: const Color(0xFFFF1744).withAlpha(80),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          // Speed limit sign
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: over ? const Color(0xFFFF1744) : Colors.red.shade700,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                _speedLimit?.toString() ?? '?',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: _speedLimit != null && _speedLimit! >= 100 ? 13 : 16,
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
                  over
                      ? '⚠️  Speed Limit Exceeded!'
                      : 'Speed Limit: $_speedLimit km/h',
                  style: TextStyle(
                    color: over
                        ? const Color(0xFFFF1744)
                        : textPri,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (over)
                  Text(
                    'Current: ${_currentSpeed.toInt()} km/h  ·  Limit: $_speedLimit km/h',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
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
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Speed Warning Wrapper (pulsing red overlay when over limit)             ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildSpeedWarningWrapper(Widget child) {
    return Stack(
      children: [
        child,
        // ── Danger Vignette overlay (shown only when over limit) ────────────
        if (_isOverLimit)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulseRedAnim,
                builder: (_, child) {
                  return CustomPaint(
                    painter: _VignettePainter(
                      opacity: _pulseRedAnim.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Simulation Speed Slider                                                 ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildSimSpeedSlider(
      Color accent, Color textPri, Color textSec) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xDD1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(40),
            blurRadius: 12,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                '${l10n.simulation} ${l10n.gauge}',
                style: TextStyle(color: textSec, fontSize: 12),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _isOverLimit
                      ? const Color(0xFFFF1744).withAlpha(40)
                      : accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isOverLimit
                        ? const Color(0xFFFF1744)
                        : accent,
                  ),
                ),
                child: Text(
                  '${_simSpeedKmh.toInt()} km/h',
                  style: TextStyle(
                    color: _isOverLimit
                        ? const Color(0xFFFF1744)
                        : accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbColor: _isOverLimit
                  ? const Color(0xFFFF1744)
                  : accent,
              activeTrackColor: _isOverLimit
                  ? const Color(0xFFFF1744)
                  : accent,
              inactiveTrackColor: Colors.white12,
              overlayColor: (_isOverLimit
                      ? const Color(0xFFFF1744)
                      : accent)
                  .withAlpha(30),
            ),
            child: Slider(
              value: _simSpeedKmh,
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
              if (_speedLimit != null)
                Text(
                  'Limit: $_speedLimit km/h',
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 10),
                ),
              Text('150', style: TextStyle(color: textSec, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Current View (Gauge / Digital / Map)                                    ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildCurrentView() {
    switch (_currentIndex) {
      case 0:
        return GaugeView(
          speed: _currentSpeed,
          satellites: _satellites,
          hasGPS: _hasGPS,
          isOverLimit: _isOverLimit,
          speedLimit: _speedLimit,
        );
      case 1:
        return DigitalView(
          speed: _currentSpeed,
          satellites: _satellites,
          hasGPS: _hasGPS,
          isOverLimit: _isOverLimit,
          speedLimit: _speedLimit,
        );
      case 2:
        return Stack(
          children: [
            MapView(
              currentPosition: _currentPosition,
              speed: _currentSpeed,
              activeRoute: _activeRoute,
              onStopNavigation: _stopNavigation,
              speedLimit: _speedLimit,
              isOverLimit: _isOverLimit,
              isSimulation: _isSimMode,
            ),
            _buildSearchOverlay(),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  String _formatDuration(Duration duration) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(duration.inHours)}:${pad(duration.inMinutes.remainder(60))}:${pad(duration.inSeconds.remainder(60))}';
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Bottom Panel                                                            ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildBottomPanel(
    Color accent,
    Color bg,
    Color surface,
    Color textPri,
    Color textSec,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // Consolidated Timer & Stats Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withAlpha(40)),
            ),
            child: _activeRoute != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(flex: 3, child: _buildCompactStat(Icons.timer, _formatDuration(_elapsed), '', accent, textPri, textSec)),
                      Container(width: 1, height: 24, color: accent.withAlpha(40)),
                      Expanded(flex: 2, child: _buildCompactStat(Icons.access_time_filled, _activeRoute!.durationText, 'ETA', const Color(0xFF00E5FF), textPri, textSec)),
                      Container(width: 1, height: 24, color: accent.withAlpha(40)),
                      Expanded(flex: 2, child: _buildCompactStat(Icons.route, _activeRoute!.distanceText, l10n.distance, const Color(0xFF00E5FF), textPri, textSec)),
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
                                  Text(
                                    _activeRoute!.destination,
                                    style: TextStyle(color: textPri, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
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
                      Expanded(flex: 3, child: _buildCompactStat(Icons.timer, _formatDuration(_elapsed), '', accent, textPri, textSec)),
                      Container(width: 1, height: 24, color: accent.withAlpha(40)),
                      Expanded(flex: 2, child: _buildCompactStat(Icons.route, '${_totalDistance.toStringAsFixed(0)}', l10n.distance, accent, textPri, textSec)),
                      Container(width: 1, height: 24, color: accent.withAlpha(40)),
                      Expanded(flex: 2, child: _buildCompactStat(Icons.speed, '${_avgSpeed.toStringAsFixed(0)}', l10n.avg, accent, textPri, textSec)),
                      Container(width: 1, height: 24, color: accent.withAlpha(40)),
                      Expanded(flex: 2, child: _buildCompactStat(Icons.bolt, '${_maxSpeed.toStringAsFixed(0)}', l10n.max, accent, textPri, textSec)),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          // START/STOP Button and Mic Button
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _onStartStopPressed,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      // Red when journey is running, green when route ready to go, yellow otherwise
                      color: (_isSimMode && _activeRoute != null)
                          ? (_simRunning
                              ? const Color(0xFFFF1744)
                              : const Color(0xFF00C853))
                          : (_isTracking ? const Color(0xFFFF1744) : accent),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: ((_isSimMode && _activeRoute != null)
                                  ? (_simRunning
                                      ? const Color(0xFFFF1744)
                                      : const Color(0xFF00C853))
                                  : (_isTracking
                                      ? const Color(0xFFFF1744)
                                      : accent))
                              .withAlpha(80),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          // Contextual label
                          (_isSimMode && _activeRoute != null)
                              ? (_simRunning ? l10n.stop : 'START JOURNEY')
                              : (_isTracking ? l10n.stop : l10n.start),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          (_isSimMode && _activeRoute != null)
                              ? (_simRunning
                                  ? Icons.stop_rounded
                                  : Icons.navigation_rounded)
                              : (_isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                          color: Colors.white,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildMicButton(),
            ],
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Mic Button                                                              ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildMicButton() {
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
                  ? [const Color(0xFF00C853), const Color(0xFF00897B)]
                  : [const Color(0xFF2979FF), const Color(0xFF651FFF)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isListening
                    ? const Color(0xFF00C853).withAlpha(120)
                    : const Color(0xFF2979FF).withAlpha(100),
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

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  Helpers                                                                 ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

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

  Widget _buildNavItem(
      IconData icon, String label, int index, Color accent, Color textSec) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? accent : textSec, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accent : textSec,
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History Screen ──────────────────────────────────────────────────────────

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: const Center(child: Text('History will be displayed here')),
    );
  }
}

// SettingsScreen is provided by app_drawer.dart

// ─── Vignette Painter ─────────────────────────────────────────────────────────
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

