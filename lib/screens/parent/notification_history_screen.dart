import 'package:flutter/material.dart';
import '../../services/notification_log_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final _log = NotificationLogService();
  late Future<Map<String, List<NotificationLogItem>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _log.getLogsGroupedByDate();
  }

  void _refresh() {
    setState(() {
      _future = _log.getLogsGroupedByDate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear notifications'),
                  content: const Text('Are you sure you want to clear all notification history?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) {
                await _log.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification history cleared')),
                  );
                  _refresh();
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, List<NotificationLogItem>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final grouped = snapshot.data!;
          if (grouped.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          final dateKeys = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a)); // newest date first

          return ListView.builder(
            itemCount: dateKeys.length,
            itemBuilder: (context, index) {
              final dateKey = dateKeys[index];
              final items = grouped[dateKey]!..sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return _DateSection(dateKey: dateKey, items: items);
            },
          );
        },
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  final String dateKey; // yyyy-MM-dd
  final List<NotificationLogItem> items;
  const _DateSection({required this.dateKey, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            _formatDateHeader(dateKey),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...items.map((e) => _NotificationTile(item: e)).toList(),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }

  String _formatDateHeader(String key) {
    // key is yyyy-MM-dd
    final parts = key.split('-');
    if (parts.length != 3) return key;
    final y = parts[0];
    final m = parts[1];
    final d = parts[2];
    return '$d/$m/$y';
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationLogItem item;
  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(item.type);
    final time = NotificationLogService.formatTime(item.timestamp);
    return ListTile(
      leading: Icon(icon),
      title: Text(item.message),
      subtitle: Text(time),
      dense: true,
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'arrival':
        return Icons.access_time;
      case 'boarding':
        return Icons.directions_bus;
      case 'drop':
        return Icons.school;
      default:
        return Icons.notifications;
    }
  }
}
