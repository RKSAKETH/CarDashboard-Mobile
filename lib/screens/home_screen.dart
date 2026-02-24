import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gauge_view.dart';
import '../widgets/digital_view.dart';
import '../widgets/map_view.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ambient_light_overlay.dart';
import '../models/speed_data.dart';
import '../services/location_service.dart';
import '../services/history_service.dart';
import '../services/voice_assistant_service.dart';

import 'profile_screen.dart';
import '../services/incident_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  VehicleType _vehicleType = VehicleType.motorcycle;
  bool _isTracking = false;

  // Speed tracking data
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _totalDistance = 0.0;
  double _avgSpeed = 0.0;
  int _satellites = 0;
  bool _hasGPS = false;

  // Timer
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // Services
  final LocationService _locationService = LocationService();
  final HistoryService _historyService = HistoryService();
  final VoiceAssistantService _voice = VoiceAssistantService();

  // Location
  Position? _currentPosition;

  // Voice state
  bool _voiceReady = false;
  String _voiceStatus = 'Initialising…';

  // Active route
  RouteInfo? _activeRoute;

  // Mic pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ─── Lifecycle ───

  @override
  void initState() {
    super.initState();

    // Pulse animation for mic button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _requestPermissions();
    _loadTotalDistance();
    _initVoice();
    IncidentService.instance.start(); // start global monitoring
  }

  Future<void> _initVoice() async {
    // Request microphone permission explicitly before STT init
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
      }
    };

    _voice.onNavigationStopped = () {
      if (mounted) setState(() => _activeRoute = null);
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
    _pulseController.dispose();
    _voice.dispose();
    IncidentService.instance.stop();
    super.dispose();
  }

  // ─── Permissions ───

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
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentSpeed = position.speed * 3.6;
          _satellites = position.accuracy.toInt();
          _hasGPS = true;

          if (_isTracking && _currentSpeed > _maxSpeed) {
            _maxSpeed = _currentSpeed;
          }
        });
        // Feed position to voice service for navigation
        _voice.updatePosition(position);
      }
    });
  }

  Future<void> _loadTotalDistance() async {
    final distance = await _historyService.getTotalDistance();
    setState(() => _totalDistance = distance);
  }

  // ─── Tracking ───

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

  // ─── Voice Trigger ───

  Future<void> _onMicPressed() async {
    if (!_voiceReady) return;

    if (_voice.isListening) {
      _voice.stopListening();
      _pulseController.stop();
      _pulseController.reset();
    } else {
      _pulseController.repeat(reverse: true);
      await _voice.startListening();
      // Stop pulse when done listening
      if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _stopNavigation() {
    _voice.onNavigationStopped?.call();
    setState(() => _activeRoute = null);
    _voice.speak('Navigation stopped.');
  }

  // ─── Views ───

  Widget _buildCurrentView() {
    switch (_currentIndex) {
      case 0:
        return GaugeView(
          speed: _currentSpeed,
          satellites: _satellites,
          hasGPS: _hasGPS,
        );
      case 1:
        return DigitalView(
          speed: _currentSpeed,
          satellites: _satellites,
          hasGPS: _hasGPS,
        );
      case 2:
        return MapView(
          currentPosition: _currentPosition,
          speed: _currentSpeed,
          activeRoute: _activeRoute,
          onStopNavigation: _stopNavigation,
        );
      default:
        return const SizedBox();
    }
  }

  String _formatDuration(Duration duration) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(duration.inHours)}:${pad(duration.inMinutes.remainder(60))}:${pad(duration.inSeconds.remainder(60))}';
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final isListening = _voice.isListening;
    // ── Ambient light state ──
    final lightMode = AmbientLightProvider.of(context);
    final accent    = LightThemePalette.accent(lightMode);
    final bg        = LightThemePalette.background(lightMode);
    final surface   = LightThemePalette.surface(lightMode);
    final textPri   = LightThemePalette.textPrimary(lightMode);
    final textSec   = LightThemePalette.textSecondary(lightMode);

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              color: bg,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    'Speedometer',
                    style: TextStyle(
                      color: textPri,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      // ── Live lux indicator ──
                      const LuxIndicator(),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.history, color: textPri),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HistoryScreen()),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.person, color: textPri),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── GPS + Voice Status Row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // GPS status
                  Icon(
                    Icons.gps_fixed,
                    color: _hasGPS ? accent : Colors.grey,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'GPS: ${_hasGPS ? "Yes" : "No"}  ($_satellites sat)',
                    style: TextStyle(color: textSec, fontSize: 12),
                  ),
                  const Spacer(),
                  // Voice status chip
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isListening ? accent.withAlpha(40) : surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isListening ? accent : accent.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          size: 12,
                          color: isListening ? accent : textSec,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            _voiceStatus,
                            style: TextStyle(
                              color: isListening ? accent : textSec,
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

            // ── Main View ──
            Expanded(
              child: _buildCurrentView(),
            ),

            // ── Bottom Stats and Controls ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              color: bg,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  // Odometer + Vehicle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _totalDistance.toStringAsFixed(3).replaceAll('.', '').padLeft(6, '0'),
                        style: TextStyle(
                          color: textSec,
                          fontSize: 24,
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                        ),
                      ),
                      Text('km', style: TextStyle(color: textSec, fontSize: 16)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withAlpha(60)),
                        ),
                        child: DropdownButton<VehicleType>(
                          value: _vehicleType,
                          dropdownColor: surface,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down, color: textPri),
                          items: [
                            DropdownMenuItem(
                              value: VehicleType.motorcycle,
                              child: Row(children: [
                                Icon(Icons.motorcycle, color: textPri, size: 20),
                                const SizedBox(width: 8),
                              ]),
                            ),
                            DropdownMenuItem(
                              value: VehicleType.car,
                              child: Row(children: [
                                Icon(Icons.directions_car, color: textPri, size: 20),
                                const SizedBox(width: 8),
                              ]),
                            ),
                            DropdownMenuItem(
                              value: VehicleType.bicycle,
                              child: Row(children: [
                                Icon(Icons.directions_bike, color: textPri, size: 20),
                                const SizedBox(width: 8),
                              ]),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _vehicleType = v);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Timer
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: accent.withAlpha(40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map, color: accent, size: 20),
                        const SizedBox(width: 16),
                        Text(
                          _formatDuration(_elapsed),
                          style: TextStyle(
                            color: textPri,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.photo_library, color: accent, size: 20),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Stats Cards
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(
                        'Distance',
                        '${_totalDistance.toStringAsFixed(0)} km',
                        accent, surface, textPri, textSec,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatCard(
                        'Avg',
                        '${_avgSpeed.toStringAsFixed(0)} km/h',
                        accent, surface, textPri, textSec,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatCard(
                        'Max',
                        '${_maxSpeed.toStringAsFixed(0)} km/h',
                        accent, surface, textPri, textSec,
                      )),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // START/STOP Button and Mic Button
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleTracking,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withAlpha(80),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isTracking ? 'STOP' : 'START',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _isTracking ? Icons.stop : Icons.play_arrow,
                                  color: Colors.black,
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildMicButton(),
                    ],
                  ),
                ],
              ),
            ),

            // ── Bottom Navigation ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                color: bg,
                border: Border(top: BorderSide(color: accent.withAlpha(60), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.speed, 'Gauge', 0, accent, textSec),
                  _buildNavItem(Icons.filter_9_plus, 'Digital', 1, accent, textSec),
                  _buildNavItem(Icons.map, 'Map', 2, accent, textSec),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Mic Button ───

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

  // ─── Widgets ───

  Widget _buildStatCard(
    String label,
    String value,
    Color accent,
    Color surface,
    Color textPri,
    Color textSec,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(40)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: textPri,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: textSec, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, Color accent, Color textSec) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? accent : textSec, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accent : textSec,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History Screen ───

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(child: Text('History will be displayed here')),
    );
  }
}
