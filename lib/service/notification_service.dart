import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/game_session.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  static Future<void> scheduleSessionEnd(GameSession session) async {
    if (session.isOpenSession) return;

    final scheduledTime = tz.TZDateTime.from(session.endTime, tz.local);
    
    // Check if scheduled time is in the past
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notificationsPlugin.zonedSchedule(
      session.id,
      'Partie Terminée — ${session.postLabel}',
      'La partie #${session.partyNumber} (${session.tierLabel}) est terminée.',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'game_sessions',
          'Game Sessions',
          channelDescription: 'Notifications for game session endings',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: session.postId.toString(),
    );
  }

  static Future<void> cancelSessionNotification(int sessionId) async {
    await _notificationsPlugin.cancel(sessionId);
  }
}
