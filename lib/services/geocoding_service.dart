import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Search result from Nominatim
class SearchResult {
  final String displayName;
  final LatLng location;
  final String type;

  SearchResult({
    required this.displayName,
    required this.location,
    required this.type,
  });

  /// Get a short name (first part before comma)
  String get shortName {
    final parts = displayName.split(',');
    return parts.isNotEmpty ? parts[0].trim() : displayName;
  }
}

/// Service for geocoding using Nominatim (free, no API key)
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  /// Search for locations by query
  Future<List<SearchResult>> searchLocations(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Search limited to India only, limit to 10 results, include all types
      final url = Uri.parse(
        '$_baseUrl/search?q=${Uri.encodeComponent(query)}&format=json&limit=10&addressdetails=1&countrycodes=in',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'StepPulse/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body) as List;

      return data.map<SearchResult>((item) {
        return SearchResult(
          displayName: item['display_name'] as String,
          location: LatLng(
            double.parse(item['lat'] as String),
            double.parse(item['lon'] as String),
          ),
          type: item['type'] as String? ?? 'place',
        );
      }).toList();
    } catch (e) {
      print('Geocoding error: $e');
      return [];
    }
  }
}
