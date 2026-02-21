import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../widgets/gauge_view.dart';
import '../widgets/digital_view.dart';
import '../widgets/map_view.dart';
import '../widgets/app_drawer.dart';
import '../models/speed_data.dart';
import '../services/location_service.dart';
import '../services/history_service.dart';
import '../services/theme_provider.dart';
import 'profile_screen.dart';

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

  // Location
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadTotalDistance();
  }

  Future<void> _requestPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services'),
              duration: Duration(seconds: 3),
            ),
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
              const SnackBar(
                content: Text('Location permission denied'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Enable in settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      await _initLocationTracking();
    } catch (e) {
      print('Error requesting permissions: $e');
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
      }
    });
  }

  Future<void> _loadTotalDistance() async {
    final distance = await _historyService.getTotalDistance();
    setState(() {
      _totalDistance = distance;
    });
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

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = _elapsed + const Duration(seconds: 1);
        _updateAvgSpeed();
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
        );
      default:
        return const SizedBox();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;

    // ── Semantic colour tokens ────────────────────────────────────────────────
    final bgColor       = theme.scaffoldBackgroundColor;
    final surfaceColor  = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardColor     = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEF3);
    final textPrimary   = isDark ? Colors.white         : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white70       : Colors.black54;
    final textTertiary  = isDark ? Colors.white38       : Colors.black26;
    final accent        = theme.primaryColor;
    final dividerColor  = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFDDDDDD);
    final navBgColor    = isDark ? const Color(0xFF0D0D0D) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Hamburger menu
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: textPrimary),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),

                  // Title
                  Text(
                    'Speedometer',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Right icons: History | Theme toggle | Profile
                  Row(
                    children: [
                      // History
                      IconButton(
                        icon: Icon(Icons.history, color: textPrimary),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        },
                      ),

                      // ── Theme toggle ───────────────────────────────────────
                      IconButton(
                        tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) =>
                              RotationTransition(
                                turns: anim,
                                child: FadeTransition(opacity: anim, child: child),
                              ),
                          child: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            key: ValueKey(isDark),
                            color: isDark ? const Color(0xFFFFD700) : const Color(0xFF5C5CF7),
                          ),
                        ),
                        onPressed: () => themeProvider.toggleTheme(),
                      ),

                      // Profile
                      IconButton(
                        icon: Icon(Icons.person, color: textPrimary),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── GPS Status ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gps_fixed,
                    color: _hasGPS ? accent : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GPS: ${_hasGPS ? "Yes" : "No"}',
                    style: TextStyle(color: textSecondary),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '($_satellites Satellites)',
                    style: TextStyle(color: textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Main Gauge / Digital / Map view ──────────────────────────────
            Expanded(child: _buildCurrentView()),

            // ── Bottom Stats & Controls ────────────────────────────────────────
            Container(
              color: bgColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Odometer + vehicle selector row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _totalDistance
                            .toStringAsFixed(3)
                            .replaceAll('.', '')
                            .padLeft(6, '0'),
                        style: TextStyle(
                          color: textTertiary,
                          fontSize: 24,
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                        ),
                      ),
                      Text(
                        'km',
                        style: TextStyle(color: textTertiary, fontSize: 16),
                      ),

                      // Vehicle Type Selector
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<VehicleType>(
                          value: _vehicleType,
                          dropdownColor: cardColor,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down, color: textPrimary),
                          items: [
                            DropdownMenuItem(
                              value: VehicleType.motorcycle,
                              child: Row(
                                children: [
                                  Icon(Icons.motorcycle,
                                      color: textPrimary, size: 20),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: VehicleType.car,
                              child: Row(
                                children: [
                                  Icon(Icons.directions_car,
                                      color: textPrimary, size: 20),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: VehicleType.bicycle,
                              child: Row(
                                children: [
                                  Icon(Icons.directions_bike,
                                      color: textPrimary, size: 20),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _vehicleType = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Timer bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map, color: textPrimary, size: 20),
                        const SizedBox(width: 16),
                        Text(
                          _formatDuration(_elapsed),
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.photo_library,
                            color: textPrimary, size: 20),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stat cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Distance',
                          '${_totalDistance.toStringAsFixed(0)} km',
                          cardColor,
                          textPrimary,
                          textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Avg speed',
                          '${_avgSpeed.toStringAsFixed(0)} km/h',
                          cardColor,
                          textPrimary,
                          textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Max speed',
                          '${_maxSpeed.toStringAsFixed(0)} km/h',
                          cardColor,
                          textPrimary,
                          textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // START / STOP button
                  GestureDetector(
                    onTap: _toggleTracking,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _isTracking ? Colors.redAccent : accent,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: (_isTracking ? Colors.redAccent : accent)
                                .withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isTracking ? Icons.stop : Icons.play_arrow,
                            color: Colors.black,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom Navigation ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: navBgColor,
                border: Border(
                  top: BorderSide(color: dividerColor, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.speed, 'Gauge', 0, textPrimary, textSecondary, accent),
                  _buildNavItem(Icons.filter_9_plus, 'Digital', 1, textPrimary, textSecondary, accent),
                  _buildNavItem(Icons.map, 'Map', 2, textPrimary, textSecondary, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? accent : textSecondary,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accent : textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Screen ──────────────────────────────────────────────────────────
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: Center(
        child: Text(
          'History will be displayed here',
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }
}
