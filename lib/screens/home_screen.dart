import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/gauge_view.dart';
import '../widgets/digital_view.dart';
import '../widgets/map_view.dart';
import '../widgets/app_drawer.dart';
import '../models/speed_data.dart';
import '../services/location_service.dart';
import '../services/history_service.dart';
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
      print('Checking location permission...');
      
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
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

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      print('Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');
        
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

      // Permission granted, start tracking
      print('Permission granted! Starting location tracking...');
      await _initLocationTracking();
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }
  
  Future<void> _initLocationTracking() async {
    print('Initializing location tracking...');
    
    // Start the location service
    await _locationService.startTracking();
    
    // Listen to position updates
    _locationService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
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
        _avgSpeed = (_totalDistance / _elapsed.inSeconds) * 3600; // km/h
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
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
                  const Text(
                    'Speedometer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person, color: Colors.white),
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
            
            // GPS Status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gps_fixed,
                    color: _hasGPS ? const Color(0xFF00FF00) : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GPS: ${_hasGPS ? "Yes" : "No"}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '($_satellites Satellites)',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Main View
            Expanded(
              child: _buildCurrentView(),
            ),
            
            // Bottom Stats and Controls
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Odometer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _totalDistance.toStringAsFixed(3).replaceAll('.', '').padLeft(6, '0'),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 24,
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                        ),
                      ),
                      const Text(
                        'km',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                      // Vehicle Type Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<VehicleType>(
                          value: _vehicleType,
                          dropdownColor: const Color(0xFF2A2A2A),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          items: [
                            DropdownMenuItem(
                              value: VehicleType.motorcycle,
                              child: Row(
                                children: const [
                                  Icon(Icons.motorcycle, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: VehicleType.car,
                              child: Row(
                                children: const [
                                  Icon(Icons.directions_car, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: VehicleType.bicycle,
                              child: Row(
                                children: const [
                                  Icon(Icons.directions_bike, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
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
                  
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map, color: Colors.white, size: 20),
                        const SizedBox(width: 16),
                        Text(
                          _formatDuration(_elapsed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.photo_library, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Distance', '${_totalDistance.toStringAsFixed(0)} km'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard('Avg speed', '${_avgSpeed.toStringAsFixed(0)} km/h'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard('Max speed', '${_maxSpeed.toStringAsFixed(0)} km/h'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // START/STOP Button
                  GestureDetector(
                    onTap: _toggleTracking,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF00),
                        borderRadius: BorderRadius.circular(50),
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
            
            // Bottom Navigation
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.speed, 'Gauge', 0),
                  _buildNavItem(Icons.filter_9_plus, 'Digital', 1),
                  _buildNavItem(Icons.map, 'Map', 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white38,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: const Center(
        child: Text('History will be displayed here'),
      ),
    );
  }
}
