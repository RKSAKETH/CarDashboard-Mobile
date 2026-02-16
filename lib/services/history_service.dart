import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/speed_data.dart';

class HistoryService {
  static const String _totalDistanceKey = 'total_distance';
  static const String _sessionsKey = 'sessions';
  
  Future<double> getTotalDistance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_totalDistanceKey) ?? 0.0;
  }
  
  Future<void> updateTotalDistance(double distance) async {
    final prefs = await SharedPreferences.getInstance();
    final currentDistance = prefs.getDouble(_totalDistanceKey) ?? 0.0;
    await prefs.setDouble(_totalDistanceKey, currentDistance + distance);
  }
  
  Future<void> saveSession({
    required double distance,
    required double maxSpeed,
    required double avgSpeed,
    required Duration duration,
    required VehicleType vehicleType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    
    final session = SessionData(
      startTime: DateTime.now().subtract(duration),
      endTime: DateTime.now(),
      distance: distance,
      maxSpeed: maxSpeed,
      avgSpeed: avgSpeed,
      duration: duration,
      vehicleType: vehicleType,
    );
    
    sessions.add(session);
    
    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_sessionsKey, jsonEncode(sessionsJson));
    await updateTotalDistance(distance);
  }
  
  Future<List<SessionData>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsString = prefs.getString(_sessionsKey);
    
    if (sessionsString == null) {
      return [];
    }
    
    final sessionsList = jsonDecode(sessionsString) as List;
    return sessionsList.map((s) => SessionData.fromJson(s)).toList();
  }
}
