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
        .select('id, name, bus_id, bus_stop, bus_stop_lat, bus_stop_lng, bus:bus_id(plate_number), school_id')
        .eq('id', studentId)
        .maybeSingle();
    if (srow == null) return null;
    final result = Map<String, dynamic>.from(srow);

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
      // Log if parent role cannot update students due to RLS or other errors
      // ignore: avoid_print
      // Use debugPrint so it shows in Flutter logs
      // Note: This won't expose sensitive data; only the error string
      // and the student id to help diagnose policy/privilege issues.
      // If this is too verbose, we can gate behind a debug flag.
      // print('persistHomeCoords failed: $e');
      // Prefer debugPrint in Flutter apps
      // ignore: deprecated_member_use
      // ignore_for_file: deprecated_member_use_from_same_package
      // ignore_for_file: use_build_context_synchronously
      // The above ignores are precautionary; primary intent is to surface the error.
      // Using Supabase client directly is safe here.
      // If needed, switch to a server-side RPC to enforce least privilege.
      //
      // Actual log:
      // ignore: avoid_print
      // print('persistHomeCoords error for student $studentId: $e');
      // Using Supabase Flutter's logger-compatible output
      // But to keep dependencies minimal, use debugPrint from foundation via Flutter
      // however we are in a pure Dart file; still, debugPrint is available via flutter import in map_tab
      // Here, fallback to print.
      print('persistHomeCoords error for student $studentId: $e');
    }
  }
}
