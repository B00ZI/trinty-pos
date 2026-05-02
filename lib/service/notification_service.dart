import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/game_session.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> playNotificationSound() async {
    try {
      _audioPlayer.audioCache.prefix = '';
      await _audioPlayer.play(AssetSource('lib/assets/notif.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

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

  // scheduleSessionEnd removed - dynamic sessions do not have a fixed end time

  static Future<void> showHeadsUpNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'game_sessions_alerts',
      'Game Session Alerts',
      channelDescription: 'High priority alerts for finished games',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  static Future<void> cancelSessionNotification(int sessionId) async {
    await _notificationsPlugin.cancel(sessionId);
  }
}
