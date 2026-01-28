/// Walk session data model for GPS tracking
library;

import 'package:latlong2/latlong.dart';

/// A single GPS point recorded during a walk
class RoutePoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude;
  final double? speed; // m/s

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.speed,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'altitude': altitude,
      'speed': speed,
    };
  }

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      timestamp: DateTime.parse(map['timestamp'] as String),
      altitude: map['altitude'] as double?,
      speed: map['speed'] as double?,
    );
  }
}

/// Status of a walking session
enum WalkStatus { idle, walking, paused }

/// A complete walking session with all tracking data
class WalkSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<RoutePoint> routePoints;
  final int steps;
  final double totalDistanceMeters;
  final WalkStatus status;
  final String? description; // Optional user description
  final int rating; // 1-5 stars, 0 means not rated

  const WalkSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.routePoints = const [],
    this.steps = 0,
    this.totalDistanceMeters = 0,
    this.status = WalkStatus.idle,
    this.description,
    this.rating = 0,
  });

  /// Duration of the walk
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Distance in kilometers
  double get distanceKm => totalDistanceMeters / 1000;

  /// Distance in miles
  double get distanceMiles => totalDistanceMeters / 1609.344;

  /// Average pace in minutes per kilometer
  double get paceMinPerKm {
    if (distanceKm == 0) return 0;
    return duration.inMinutes / distanceKm;
  }

  /// Average pace in minutes per mile
  double get paceMinPerMile {
    if (distanceMiles == 0) return 0;
    return duration.inMinutes / distanceMiles;
  }

  /// Average speed in km/h
  double get speedKmh {
    if (duration.inSeconds == 0) return 0;
    return distanceKm / (duration.inSeconds / 3600);
  }

  /// Estimated calories burned (rough estimate based on steps)
  int get estimatedCalories {
    // Rough estimate: ~0.04 calories per step
    return (steps * 0.04).round();
  }

  /// Get all points as LatLng for polyline
  List<LatLng> get polylinePoints => routePoints.map((p) => p.latLng).toList();

  /// Copy with new values
  WalkSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    List<RoutePoint>? routePoints,
    int? steps,
    double? totalDistanceMeters,
    WalkStatus? status,
    String? description,
    int? rating,
  }) {
    return WalkSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      routePoints: routePoints ?? this.routePoints,
      steps: steps ?? this.steps,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      status: status ?? this.status,
      description: description ?? this.description,
      rating: rating ?? this.rating,
    );
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'routePoints': routePoints.map((p) => p.toMap()).toList(),
      'steps': steps,
      'totalDistanceMeters': totalDistanceMeters,
      'status': status.name,
      'description': description,
      'rating': rating,
    };
  }

  /// Create from map
  factory WalkSession.fromMap(Map<String, dynamic> map) {
    // Handle routePoints - might be missing or have nested maps
    List<RoutePoint> points = [];
    if (map['routePoints'] != null) {
      for (final p in map['routePoints'] as List<dynamic>) {
        if (p is Map) {
          points.add(RoutePoint.fromMap(Map<String, dynamic>.from(p)));
        }
      }
    }

    return WalkSession(
      id:
          map['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      routePoints: points,
      steps: map['steps'] as int? ?? 0,
      totalDistanceMeters:
          (map['totalDistanceMeters'] as num?)?.toDouble() ?? 0,
      status: WalkStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => WalkStatus.idle,
      ),
      description: map['description'] as String?,
      rating: map['rating'] as int? ?? 0,
    );
  }

  /// Create a new empty session
  factory WalkSession.create() {
    return WalkSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      status: WalkStatus.idle,
    );
  }
}
