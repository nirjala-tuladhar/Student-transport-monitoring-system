import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParentNotificationItem {
  final String id;
  final String type; // boarding, unboarding, arrival, home_reached, drop
  final String message;
  final DateTime createdAt;

  ParentNotificationItem({required this.id, required this.type, required this.message, required this.createdAt});
}

class ParentNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ParentNotificationItem>> fetchMyNotifications({int limit = 200}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final rows = await _supabase
        .from('parent_notifications')
        .select('id, type, message, created_at')
        .eq('parent_user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => ParentNotificationItem(
              id: r['id'] as String,
              type: (r['type'] as String?) ?? 'info',
              message: (r['message'] as String?) ?? '',
              createdAt: DateTime.parse((r['created_at'] as String)).toLocal(),
            ))
        .toList();
  }

  RealtimeChannel subscribeMyNotifications({
    required void Function(ParentNotificationItem item) onInsert,
  }) {
    final uid = _supabase.auth.currentUser?.id;
    // If not authenticated yet, return a no-op channel
    if (uid == null) {
      return _supabase.channel('parent-notifs-noop');
    }
    final ch = _supabase.channel('parent-notifs-$uid');
    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'parent_notifications',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'parent_user_id', value: uid),
      callback: (payload) {
        final row = payload.newRecord;
        if (row['parent_user_id'] != uid) return; // extra guard
        onInsert(ParentNotificationItem(
          id: row['id'] as String,
          type: (row['type'] as String?) ?? 'info',
          message: (row['message'] as String?) ?? '',
          createdAt: DateTime.parse((row['created_at'] as String)).toLocal(),
        ));
      },
    );
    ch.subscribe();
    return ch;
  }

  Future<void> createMyNotification({
    required String type,
    required String message,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('[ParentNotificationService] ❌ Cannot create notification: user not authenticated');
      return;
    }
    try {
      debugPrint('[ParentNotificationService] Creating notification: type=$type, message=$message');
      await _supabase.from('parent_notifications').insert({
        'parent_user_id': uid,
        'type': type,
        'message': message,
      });
      debugPrint('[ParentNotificationService] ✅ Notification created successfully');
    } catch (e) {
      debugPrint('[ParentNotificationService] ❌ Failed to create notification: $e');
    }
  }
}
