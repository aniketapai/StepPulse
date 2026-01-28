import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Route information from OSRM
class RouteInfo {
  final List<LatLng> routePoints;
  final double distanceMeters;
  final int durationSeconds;

  RouteInfo({
    required this.routePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Distance in kilometers
  double get distanceKm => distanceMeters / 1000;

  /// Duration formatted as "X min" or "X h Y min"
  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  /// Distance formatted as "X.X km"
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';
}

/// Service for fetching walking routes using OSRM (free, no API key)
class RoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// Get walking route between two points
  /// Returns null if request fails
  Future<RouteInfo?> getWalkingRoute(LatLng start, LatLng end) async {
    try {
      // OSRM expects coordinates as lng,lat (not lat,lng!)
      final url = Uri.parse(
        '$_baseUrl/route/v1/foot/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?geometries=geojson&overview=full',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          (data['routes'] as List).isEmpty) {
        return null;
      }

      final route = data['routes'][0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;

      // Convert GeoJSON coordinates [lng, lat] to LatLng
      final routePoints = coordinates.map<LatLng>((coord) {
        final c = coord as List;
        return LatLng(c[1] as double, c[0] as double);
      }).toList();

      return RouteInfo(
        routePoints: routePoints,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toInt(),
      );
    } catch (e) {
      print('Routing error: $e');
      return null;
    }
  }
}
