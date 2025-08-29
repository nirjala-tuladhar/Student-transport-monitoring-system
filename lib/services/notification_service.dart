import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> initialize() async {
    if (_inited) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Note: For Android 13+, ensure POST_NOTIFICATIONS permission is declared in Manifest.

    // Create a default channel on Android
    const androidChannel = AndroidNotificationChannel(
      'parent_default_channel',
      'Parent Notifications',
      description: 'Alerts for boarding, arrival, and drop',
      importance: Importance.high,
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    _inited = true;
  }

  Future<void> show({required String title, required String body, int id = 0}) async {
    const androidDetails = AndroidNotificationDetails(
      'parent_default_channel',
      'Parent Notifications',
      channelDescription: 'Alerts for boarding, arrival, and drop',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }
}
