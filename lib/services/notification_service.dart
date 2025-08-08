import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    try {
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
      );
    } on PlatformException catch (e) {
      if (e.code == 'invalid_icon') {
        // fallback to mipmap launcher icon if drawable not found
        const androidFallback = AndroidInitializationSettings('@mipmap/ic_launcher');
        await _plugin.initialize(
          const InitializationSettings(android: androidFallback, iOS: darwin),
        );
      } else {
        rethrow;
      }
    }
    if (Platform.isAndroid) {
      // Request runtime POST_NOTIFICATIONS permission (Android 13+)
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
      // Ensure our Android channels exist
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
          'cooldown_channel',
          'Cooldown Reminders',
          description: 'Alerts when your swipe cooldown ends',
          importance: Importance.high,
        ));
        await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
          'inactivity_channel',
          'Inactivity Reminders',
          description: 'Alerts after periods of inactivity',
          importance: Importance.high,
        ));
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

  static Future<void> showTestNotification() async {
  await _plugin.show(
    0, // Notification ID
    'Test Notification',
    'This is a test notification!',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'cooldown_channel',
        'Cooldown Reminders',
        channelDescription: 'Alerts when your swipe cooldown ends',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
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

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());