import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationLogItem {
  final String message;
  final String type; // e.g., arrival, boarding, drop
  final DateTime timestamp; // local time

  NotificationLogItem({required this.message, required this.type, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'message': message,
        'type': type,
        'ts': timestamp.toIso8601String(),
      };

  static NotificationLogItem fromJson(Map<String, dynamic> json) => NotificationLogItem(
        message: json['message'] as String? ?? '',
        type: json['type'] as String? ?? 'info',
        timestamp: DateTime.tryParse(json['ts'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class NotificationLogService {
  static const _key = 'parent_notification_log_v1';
  static final NotificationLogService _instance = NotificationLogService._internal();
  factory NotificationLogService() => _instance;
  NotificationLogService._internal();

  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get onChanged => _changes.stream;

  Future<List<NotificationLogItem>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return list.map(NotificationLogItem.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addLog(NotificationLogItem item, {int maxItems = 200}) async {
    final logs = await getLogs();
    logs.insert(0, item);
    if (logs.length > maxItems) {
      logs.removeRange(maxItems, logs.length);
    }
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(logs.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    if (!_changes.isClosed) _changes.add(null);
  }

  // Returns map keyed by yyyy-MM-dd (local), values sorted desc by time
  Future<Map<String, List<NotificationLogItem>>> getLogsGroupedByDate() async {
    final logs = await getLogs();
    final Map<String, List<NotificationLogItem>> grouped = {};
    for (final item in logs) {
      final d = _dateKey(item.timestamp);
      grouped.putIfAbsent(d, () => []).add(item);
    }
    return grouped;
  }

  String _dateKey(DateTime dt) {
    final l = dt.toLocal();
    final y = l.year.toString().padLeft(4, '0');
    final m = l.month.toString().padLeft(2, '0');
    final d = l.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String formatTime(DateTime dt) {
    final l = dt.toLocal();
    int h = l.hour;
    final m = l.minute.toString().padLeft(2, '0');
    final ap = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $ap';
  }
}
