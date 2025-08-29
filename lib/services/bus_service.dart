import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, Timer> _simTimers = {};
  final Map<String, DateTime> _lastSendAt = {};

  Future<String> getMyBusId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final row = await _supabase
        .from('buses')
        .select('id')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
    if (row == null || row['id'] == null) {
      throw Exception('No bus linked to this account');
    }
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> listMyBuses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final rows = await _supabase
        .from('buses')
        .select('id, plate_number, driver:drivers(*)')
        .eq('user_id', user.id);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> getBusWithDriver(String busId) async {
    final row = await _supabase
        .from('buses')
        .select('id, plate_number, driver:drivers(*)')
        .eq('id', busId)
        .limit(1)
        .maybeSingle();
    if (row == null) {
      throw PostgrestException(message: 'Bus not found', code: 'PGRST116');
    }
    return Map<String, dynamic>.from(row);
  }

  Future<String?> getActiveTripId(String busId) async {
    final row = await _supabase
        .from('bus_trips')
        .select('id')
        .eq('bus_id', busId)
        .filter('ended_at', 'is', null)
        .order('started_at', ascending: false)
        .maybeSingle();
    return row == null ? null : row['id'] as String?;
  }

  Future<String> startTrip(String busId) async {
    final existing = await getActiveTripId(busId);
    if (existing != null) return existing;
    final inserted = await _supabase
        .from('bus_trips')
        .insert({'bus_id': busId})
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  Future<void> endTrip(String tripId) async {
    await _supabase
        .from('bus_trips')
        .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', tripId);
  }

  Future<List<Map<String, dynamic>>> listStudentsForBus(String busId) async {
    final rows = await _supabase
        .from('students')
        .select('id, name, fingerprint_data')
        .eq('bus_id', busId)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listBoarded(String tripId) async {
    // Fetch all statuses for the trip, then reduce to latest per student
    final rows = await _supabase
        .from('student_boarding')
        .select('student_id, status, timestamp, students(name)')
        .eq('trip_id', tripId)
        .order('timestamp', ascending: false);
    final latestByStudent = <String, Map<String, dynamic>>{};
    for (final r in (rows as List)) {
      final sid = r['student_id'] as String?;
      if (sid == null) continue;
      if (!latestByStudent.containsKey(sid)) {
        latestByStudent[sid] = r as Map<String, dynamic>;
      }
    }
    final boarded = latestByStudent.values
        .where((r) => r['status'] == 'boarded')
        .map((r) => {
              'student_id': r['student_id'],
              'students': r['students'],
            })
        .toList();
    return boarded;
  }

  Future<void> markBoarded({required String tripId, required String studentId}) async {
    await _supabase.from('student_boarding').insert({
      'trip_id': tripId,
      'student_id': studentId,
      'status': 'boarded',
    });
  }

  Future<void> markUnboarded({required String tripId, required String studentId}) async {
    await _supabase.from('student_boarding').insert({
      'trip_id': tripId,
      'student_id': studentId,
      'status': 'unboarded',
    });
  }

  Future<void> uploadFingerprint({required String studentId, required Uint8List data}) async {
    // Store raw bytes; in production, consider templates instead of raw bytes
    await _supabase.from('students').update({
      'fingerprint_data': data,
    }).eq('id', studentId);
  }

  Future<void> sendLocation({
    required String busId,
    required double latitude,
    required double longitude,
    Duration minInterval = const Duration(seconds: 10),
  }) async {
    final now = DateTime.now();
    final last = _lastSendAt[busId];
    if (last != null && now.difference(last) < minInterval) {
      return; // throttle writes
    }
    await _supabase.from('bus_locations').insert({
      'bus_id': busId,
      'latitude': latitude,
      'longitude': longitude,
    });
    _lastSendAt[busId] = now;
  }

  // Debug helper: simulate bus movement and push to DB every [interval].
  void startSimulatingLocation({
    required String busId,
    double startLat = 27.7172,
    double startLng = 85.3240,
    double stepPerTick = 0.00005, // ~5.5m per tick
    Duration interval = const Duration(seconds: 10),
    bool debugPrints = false,
  }) {
    // Stop any existing simulator for this bus first
    stopSimulatingLocation(busId);
    _simTimers[busId] = Timer.periodic(interval, (timer) async {
      final lat = startLat + (timer.tick * stepPerTick);
      final lng = startLng + (timer.tick * stepPerTick);
      if (debugPrints) {
        // ignore: avoid_print
        print('Sim bus $busId at: $lat, $lng');
      }
      try {
        await sendLocation(busId: busId, latitude: lat, longitude: lng);
      } catch (e) {
        // ignore: avoid_print
        print('sendLocation failed: $e');
      }
    });
  }

  void stopSimulatingLocation(String busId) {
    _simTimers.remove(busId)?.cancel();
  }
}
