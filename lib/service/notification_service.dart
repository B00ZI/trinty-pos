import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// P52: notifications work where they can work (Android), ask for the
/// permission Android 13+ requires, and can never crash the app on a
/// platform that does not support them (Windows throws UnimplementedError
/// for every call — this service used to run there unguarded).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // P52: IDs used to be DateTime.now().millisecond — a number between 0
  // and 999! Two alerts close in time silently replaced each other.
  // A simple growing counter cannot collide.
  static int _nextNotificationId = 0;

  static Future<void> init() async {
    if (!Platform.isAndroid) return; // only Android ever shows alerts
    try {
      const settings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'));
      await _notificationsPlugin.initialize(settings);
    } catch (e) {
      if (kDebugMode) debugPrint('Notification init failed: $e');
    }
  }

  /// "La partie est terminée" — shown when a prepaid party runs out by
  /// itself (games screen timer), so the server knows to tell the client.
  static Future<void> showHeadsUpNotification(
      {required String title, required String body}) async {
    if (!Platform.isAndroid) return;
    try {
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      // P52: Android 13+ demands the POST_NOTIFICATIONS permission —
      // asked here, once, before the first alert (declared in the manifest).
      await android?.requestNotificationsPermission();
      const details = NotificationDetails(
          android: AndroidNotificationDetails(
        'game_sessions_alerts',
        'Game Session Alerts',
        channelDescription: 'High priority alerts for finished games',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ));
      await _notificationsPlugin
          .show(_nextNotificationId++, title, body, details);
    } catch (e) {
      if (kDebugMode) debugPrint('Notification failed: $e');
    }
  }
}
