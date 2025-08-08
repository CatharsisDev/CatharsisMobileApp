import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@drawable/app_icon');
    const darwin = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    if (Platform.isAndroid) {
      // Request runtime POST_NOTIFICATIONS permission (Android 13+)
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  static Future requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> scheduleCooldownNotification({
    required String id,
    required Duration delay,
  }) async {
    await _plugin.zonedSchedule(
      id.hashCode,
      'Swipe Cooldown',
      'Your 1-hour swipe cooldown is over—ready to dive back in?',
      tz.TZDateTime.now(tz.local).add(delay),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'cooldown_channel', 
          'Cooldown Reminders',
          channelDescription: 'Alerts when your swipe cooldown ends',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> scheduleInactivityNotification({
    required String id,
  }) async {
    await _plugin.zonedSchedule(
      id.hashCode,
      'We miss you!',
      'Work on yourself continuesly to become the best version of yourself. Come back and continue your journey!',
      tz.TZDateTime.now(tz.local).add(const Duration(days: 3)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'inactivity_channel',
          'Inactivity Reminders',
          channelDescription: 'Alerts after periods of inactivity',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelCooldownNotification(String id) =>
      _plugin.cancel(id.hashCode);
}