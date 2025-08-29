import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const _endpoint = 'https://nominatim.openstreetmap.org/search';
  static const _reverseEndpoint = 'https://nominatim.openstreetmap.org/reverse';
  static const _userAgent = 'StudentTransportApp/1.0 (contact: app@example.com)';

  /// Returns (lat, lon) or null if not found
  Future<({double lat, double lon})?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': address,
      'format': 'json',
      'limit': '1',
    });
    try {
      final resp = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      });
      if (resp.statusCode != 200) return null;
      final body = json.decode(resp.body);
      if (body is List && body.isNotEmpty) {
        final item = body.first as Map<String, dynamic>;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat != null && lon != null) {
          return (lat: lat, lon: lon);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocode lat/lng to a readable place label (display_name)
  Future<String?> reverseGeocode({required double lat, required double lon}) async {
    final uri = Uri.parse(_reverseEndpoint).replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'format': 'json',
      'zoom': '16', // neighborhood/street level
      'addressdetails': '0',
    });
    try {
      final resp = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      });
      if (resp.statusCode != 200) return null;
      final body = json.decode(resp.body);
      if (body is Map && body['display_name'] is String) {
        return body['display_name'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
