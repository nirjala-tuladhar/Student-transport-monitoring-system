import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/parent_notification_service.dart';

class NotificationsTab extends StatefulWidget {
  final String studentId;
  final String studentName;
  const NotificationsTab({super.key, required this.studentId, required this.studentName});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  final _notifService = ParentNotificationService();
  RealtimeChannel? _notifChannel;
  Map<String, List<ParentNotificationItem>> _grouped = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final items = await _notifService.fetchMyNotifications();
    // Group by yyyy-MM-dd local
    final Map<String, List<ParentNotificationItem>> g = {};
    for (final it in items) {
      final l = it.createdAt.toLocal();
      final key = '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
      g.putIfAbsent(key, () => []).add(it);
    }
    if (!mounted) return;
    // Sort items within each day by time desc
    for (final e in g.entries) {
      e.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    setState(() {
      _grouped = g;
      _loading = false;
    });
  }

  void _subscribe() {
    // Realtime inserts for my notifications
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _notifChannel = Supabase.instance.client.channel('parent-notifs-$uid');
    _notifChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'parent_notifications',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'parent_user_id', value: uid),
      callback: (_) => _loadLogs(),
    );
    _notifChannel!.subscribe();
  }

  @override
  void dispose() {
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateKeys = _grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest day first

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (dateKeys.isEmpty) {
      body = const Center(child: Text('No notifications yet'));
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: dateKeys.length,
        itemBuilder: (context, idx) {
          final day = dateKeys[idx];
          final items = _grouped[day] ?? [];
          return _DaySection(day: day, items: items);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: body,
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final String day; // yyyy-MM-dd
  final List<ParentNotificationItem> items;
  const _DaySection({required this.day, required this.items});

  String _prettyDay(BuildContext context, String yyyyMmDd) {
    final parts = yyyyMmDd.split('-');
    if (parts.length != 3) return yyyyMmDd;
    final now = DateTime.now();
    final d = DateTime(
      int.tryParse(parts[0]) ?? now.year,
      int.tryParse(parts[1]) ?? now.month,
      int.tryParse(parts[2]) ?? now.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final yday = today.subtract(const Duration(days: 1));
    if (DateTime(d.year, d.month, d.day) == today) return 'Today';
    if (DateTime(d.year, d.month, d.day) == yday) return 'Yesterday';
    return yyyyMmDd;
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'boarding':
        return Icons.directions_bus;
      case 'arrival':
        return Icons.timer;
      case 'home_reached':
        return Icons.home;
      case 'drop':
        return Icons.school;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _prettyDay(context, day),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue[700],
              ),
            ),
          ),
          const Divider(height: 1),
          ...items.map((e) => ListTile(
                leading: Icon(_iconFor(e.type), color: Colors.blue[700]),
                title: Text(
                  e.message,
                  style: const TextStyle(color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                trailing: Text(
                  _formatTime(e.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              )),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    int h = l.hour;
    final m = l.minute.toString().padLeft(2, '0');
    final ap = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $ap';
  }
}
