import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getMyChildWithBus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Find parent link -> student
    final parent = await _supabase
        .from('parents')
        .select('student_id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (parent == null || parent['student_id'] == null) return null;
    final studentId = parent['student_id'] as String;

    // Fetch student + bus info + bus stop coords (+school_id)
    final srow = await _supabase
        .from('students')
        .select('id, name, bus_id, bus_stop, bus_stop_area, bus_stop_city, bus_stop_country, bus_stop_lat, bus_stop_lng, bus:bus_id(plate_number), school_id')
        .eq('id', studentId)
        .maybeSingle();
    if (srow == null) return null;
    final result = Map<String, dynamic>.from(srow);
    
    print('[ParentService] Student data: id=${result['id']}, bus_stop_lat=${result['bus_stop_lat']}, bus_stop_lng=${result['bus_stop_lng']}');
    print('[ParentService] Bus stop: area=${result['bus_stop_area']}, city=${result['bus_stop_city']}, country=${result['bus_stop_country']}');

    // Try to fetch school coordinates (may be forbidden by RLS for parents).
    try {
      final sid = srow['school_id'] as String?;
      if (sid != null) {
        final school = await _supabase
            .from('schools')
            .select('latitude, longitude')
            .eq('id', sid)
            .maybeSingle();
        if (school != null) {
          result['school'] = school;
        }
      }
    } catch (_) {
      // ignore if not permitted
    }

    return result;
  }

  RealtimeChannel subscribeBoarding({
    required String studentId,
    required void Function(Map<String, dynamic> row) onInsert,
  }) {
    final ch = _supabase.channel('parent-boarding-$studentId');
    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'student_boarding',
      callback: (payload) {
        final row = payload.newRecord;
        if (row != null && row['student_id'] == studentId) {
          onInsert(row);
        }
      },
    );
    // Some backends update a single row per student instead of inserting
    ch.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'student_boarding',
      callback: (payload) {
        final row = payload.newRecord;
        if (row != null && row['student_id'] == studentId) {
          onInsert(row);
        }
      },
    );
    ch.subscribe();
    return ch;
  }

  RealtimeChannel subscribeBusLocation({
    required String busId,
    required void Function(Map<String, dynamic> row) onInsert,
  }) {
    final ch = _supabase.channel('parent-busloc-$busId');
    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'bus_locations',
      callback: (payload) {
        final row = payload.newRecord;
        if (row != null && row['bus_id'] == busId) {
          onInsert(row);
        }
      },
    );
    // If the bus location table updates the last row instead of inserting
    ch.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'bus_locations',
      callback: (payload) {
        final row = payload.newRecord;
        if (row != null && row['bus_id'] == busId) {
          onInsert(row);
        }
      },
    );
    ch.subscribe();
    return ch;
  }

  Future<Map<String, dynamic>?> getLatestBusLocation(String busId) async {
    final row = await _supabase
        .from('bus_locations')
        .select('latitude, longitude, timestamp')
        .eq('bus_id', busId)
        .order('timestamp', ascending: false)
        .limit(1)
        .maybeSingle();
    return row;
  }

  Future<void> persistHomeCoords({
    required String studentId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _supabase
          .from('students')
          .update({'bus_stop_lat': lat, 'bus_stop_lng': lng})
          .eq('id', studentId);
    } catch (e) {
      print('persistHomeCoords error for student $studentId: $e');
    }
  }

  Future<void> updateBusStopAddress({
    required String studentId,
    required String area,
    required String city,
    required String country,
  }) async {
    try {
      await _supabase
          .from('students')
          .update({
            'bus_stop_area': area,
            'bus_stop_city': city,
            'bus_stop_country': country,
          })
          .eq('id', studentId);
    } catch (e) {
      print('updateBusStopAddress error for student $studentId: $e');
      rethrow;
    }
  }
}
