import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/notification_icon', // Use null for default icon
      [
        NotificationChannel(
          channelKey: 'swipe_reset_channel',
          channelName: 'Swipe Reset',
          channelDescription: 'Notifications when swipe limit resets',
          importance: NotificationImportance.High,
          defaultColor: const Color.fromRGBO(242, 230, 211, 1),
          ledColor: Colors.white,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'inactivity_channel',
          channelName: 'Inactivity Reminders',
          channelDescription: 'Alerts after periods of inactivity',
          importance: NotificationImportance.High,
          defaultColor: const Color.fromRGBO(242, 230, 211, 1),
          ledColor: Colors.white,
          playSound: true,
          enableVibration: true,
        ),
      ],
    );

    // Request permissions
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  static Future<void> scheduleCooldownNotification({
    required String id,
    required Duration delay,
  }) async {
    final scheduledDate = DateTime.now().add(delay);
    
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id.hashCode.abs(),
        channelKey: 'swipe_reset_channel',
        icon: 'resource://drawable/notification_icon',
        largeIcon: 'resource://drawable/app_logo',
        title: 'Swipes Refreshed!',
        body: 'Your swipes have been reset. You can continue swiping.',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(
        date: scheduledDate,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
    
    print('Notification scheduled for: $scheduledDate');
  }

  static Future<void> showTestNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999,
        channelKey: 'swipe_reset_channel',
        icon: 'resource://drawable/notification_icon',
        largeIcon: 'resource://drawable/app_logo',
        title: 'Test Notification',
        body: 'This is a test notification!',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  static Future<void> scheduleInactivityNotification({
    required String id,
  }) async {
    final scheduledDate = DateTime.now().add(const Duration(days: 3));
    
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id.hashCode.abs(),
        channelKey: 'inactivity_channel',
        icon: 'resource://drawable/notification_icon',
        largeIcon: 'resource://drawable/app_logo',
        title: 'We miss you!',
        body: 'Work on yourself continuously to become the best version of yourself. Come back and continue your journey!',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(
        date: scheduledDate,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }

  static Future<void> cancelCooldownNotification(String id) async {
    await AwesomeNotifications().cancel(id.hashCode.abs());
  }

  static Future<bool> areNotificationsEnabled() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

  static Future<void> debugPrintScheduled() async {
    final list = await AwesomeNotifications().listScheduledNotifications();
    // ignore: avoid_print
    print('Scheduled notifications: ' + list.map((n) => n.content?.id).toList().toString());
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());