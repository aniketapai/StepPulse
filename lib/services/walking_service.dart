import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/walk_session.dart';

/// Service for GPS tracking and walk session management
class WalkingService {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _durationTimer;

  // Callbacks
  Function(RoutePoint)? onLocationUpdate;
  Function(Duration)? onDurationUpdate;
  Function(String)? onError;

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError?.call('Location services are disabled. Please enable GPS.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError?.call('Location permission denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError?.call(
        'Location permissions are permanently denied. Please enable in settings.',
      );
      return false;
    }

    return true;
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Minimum distance (meters) before update
        ),
      );
    } catch (e) {
      onError?.call('Failed to get location: $e');
      return null;
    }
  }

  /// Start GPS tracking
  Future<void> startTracking() async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return;

    // Configure location settings for walking
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            final routePoint = RoutePoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: DateTime.now(),
              altitude: position.altitude,
              speed: position.speed,
            );
            onLocationUpdate?.call(routePoint);
          },
          onError: (error) {
            onError?.call('GPS tracking error: $error');
          },
        );
  }

  /// Stop GPS tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  /// Start duration timer
  void startDurationTimer(DateTime startTime) {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final duration = DateTime.now().difference(startTime);
      onDurationUpdate?.call(duration);
    });
  }

  /// Pause duration timer
  void pauseDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  /// Resume duration timer with accumulated time
  void resumeDurationTimer(DateTime startTime, Duration pausedDuration) {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(startTime);
      onDurationUpdate?.call(elapsed - pausedDuration);
    });
  }

  /// Calculate distance between two points using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Calculate total distance from a list of route points
  static double calculateTotalDistance(List<RoutePoint> points) {
    if (points.length < 2) return 0;

    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += calculateDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
  }
}
