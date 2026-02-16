enum VehicleType {
  motorcycle,
  car,
  bicycle,
}

class SpeedData {
  final double speed;
  final double distance;
  final DateTime timestamp;

  SpeedData({
    required this.speed,
    required this.distance,
    required this.timestamp,
  });
}

class SessionData {
  final DateTime startTime;
  final DateTime endTime;
  final double distance;
  final double maxSpeed;
  final double avgSpeed;
  final Duration duration;
  final VehicleType vehicleType;

  SessionData({
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.duration,
    required this.vehicleType,
  });

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'distance': distance,
    'maxSpeed': maxSpeed,
    'avgSpeed': avgSpeed,
    'duration': duration.inSeconds,
    'vehicleType': vehicleType.index,
  };

  factory SessionData.fromJson(Map<String, dynamic> json) => SessionData(
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    distance: json['distance'],
    maxSpeed: json['maxSpeed'],
    avgSpeed: json['avgSpeed'],
    duration: Duration(seconds: json['duration']),
    vehicleType: VehicleType.values[json['vehicleType']],
  );
}
