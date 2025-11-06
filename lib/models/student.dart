import 'dart:typed_data';

class Student {
  final String id;
  final String schoolId;
  final String? busId;
  final String name;
  final String? busStop; // Legacy field
  final String? busStopArea;
  final String? busStopCity;
  final String? busStopCountry;
  final double? busStopLat;
  final double? busStopLng;
  final Uint8List? fingerprintData;
  final String? parent1Email;
  final String? parent2Email;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.schoolId,
    this.busId,
    required this.name,
    this.busStop,
    this.busStopArea,
    this.busStopCity,
    this.busStopCountry,
    this.busStopLat,
    this.busStopLng,
    this.fingerprintData,
    this.parent1Email,
    this.parent2Email,
    required this.createdAt,
  });

  factory Student.fromMap(Map<String, dynamic> map) {
    Uint8List? _parseFingerprint(dynamic v) {
      if (v == null) return null;
      if (v is Uint8List) return v;
      if (v is List) {
        // Supabase may return List<dynamic> of ints
        return Uint8List.fromList(v.cast<int>());
      }
      if (v is String) {
        // Postgres BYTEA often comes as hex string like "\\x0102..."
        var s = v;
        if (s.startsWith('\\x')) s = s.substring(2);
        // If string is empty after stripping, return empty bytes
        if (s.isEmpty) return Uint8List(0);
        final len = s.length;
        final bytes = <int>[];
        for (var i = 0; i < len; i += 2) {
          final byteStr = s.substring(i, i + 2);
          bytes.add(int.parse(byteStr, radix: 16));
        }
        return Uint8List.fromList(bytes);
      }
      return null;
    }

    return Student(
      id: map['id'],
      schoolId: map['school_id'],
      busId: map['bus_id'],
      name: map['name'],
      busStop: map['bus_stop'],
      busStopArea: map['bus_stop_area'],
      busStopCity: map['bus_stop_city'],
      busStopCountry: map['bus_stop_country'],
      busStopLat: (map['bus_stop_lat'] is num) ? (map['bus_stop_lat'] as num).toDouble() : (map['bus_stop_lat'] is String ? double.tryParse(map['bus_stop_lat']) : null),
      busStopLng: (map['bus_stop_lng'] is num) ? (map['bus_stop_lng'] as num).toDouble() : (map['bus_stop_lng'] is String ? double.tryParse(map['bus_stop_lng']) : null),
      fingerprintData: _parseFingerprint(map['fingerprint_data']),
      parent1Email: map['parent1_email'],
      parent2Email: map['parent2_email'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'school_id': schoolId,
      'bus_id': busId,
      'name': name,
      'bus_stop': busStop,
      'bus_stop_area': busStopArea,
      'bus_stop_city': busStopCity,
      'bus_stop_country': busStopCountry,
      'bus_stop_lat': busStopLat,
      'bus_stop_lng': busStopLng,
      'fingerprint_data': fingerprintData,
      'parent1_email': parent1Email,
      'parent2_email': parent2Email,
    };
  }
}
