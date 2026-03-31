import 'dart:ui';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  // Fixed notification IDs
  static const int _streakReminderMorningId  = 201;
  static const int _streakReminderEveningId  = 203;
  static const int _streakUrgencyId          = 204;
  static const int _flashSaleId              = 202;

  // SharedPreferences key set by background tap handler
  static const String flashSalePendingKey = 'flash_sale_pending';

  /// Call this once (e.g. in main or app bootstrap).
  /// `promptUser` false => do NOT show the system dialog here.
  static Future<void> init({bool promptUser = false}) async {
    await AwesomeNotifications().initialize(
      'resource://drawable/notification_icon',
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
        NotificationChannel(
          channelKey: 'streak_reminder_channel',
          channelName: 'Streak Reminders',
          channelDescription: 'Daily reminders to keep your streak alive',
          importance: NotificationImportance.High,
          defaultColor: const Color(0xFFFF6B35),
          ledColor: Colors.orange,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'flash_sale_channel',
          channelName: 'Flash Sales',
          channelDescription: 'Weekly flash sale offers for Premium',
          importance: NotificationImportance.High,
          defaultColor: const Color(0xFFFFD700),
          ledColor: Colors.yellow,
          playSound: true,
          enableVibration: true,
        ),
      ],
    );

    if (promptUser) {
      await ensurePermission(prompt: true);
    }
  }

  // ── Notification tap handler (runs in background isolate when app is killed)
  @pragma('vm:entry-point')
  static Future<void> onNotificationTapMethod(ReceivedAction receivedAction) async {
    if (receivedAction.channelKey == 'flash_sale_channel') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(flashSalePendingKey, true);
    }
  }

static Future<bool> ensurePermission({
  bool prompt = false,
  bool openSettingsOnDeny = false,
}) async {
  // Check current status
  final allowed = await AwesomeNotifications().isNotificationAllowed();
  if (allowed) return true;

  if (prompt) {
    // Check if previously denied (iOS won't show dialog again)
    final status = await Permission.notification.status;
    
    // If permanently denied and we're not supposed to open settings, abort
    if (status.isPermanentlyDenied && !openSettingsOnDeny) {
      debugPrint('[NOTIFS] Permission previously denied, not opening settings');
      return false;
    }
    
    // If never asked, show system dialog
    if (status.isDenied) {
      try {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      } catch (_) {}
      
      // Re-check
      final nowAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (nowAllowed) return true;
    }
    
    if (openSettingsOnDeny) {
      await openAppSettings();
    }
  }

  return await AwesomeNotifications().isNotificationAllowed();
}

  static Future<void> scheduleCooldownNotification({
    required String id,
    required Duration delay,
  }) async {
    if (!await ensurePermission(prompt: false)) {
      debugPrint('[NOTIFS] Blocked scheduleCooldown (permission=false)');
      return;
    }

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

    // ignore: avoid_print
    print('Notification scheduled for: $scheduledDate');
  }

  static Future<void> scheduleInactivityNotification({ required String id }) async {
    if (!await ensurePermission(prompt: false)) {
      debugPrint('[NOTIFS] Blocked scheduleInactivity (permission=false)');
      return;
    }

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

  static Future<void> showTestNotification() async {
    if (!await ensurePermission(prompt: false)) {
      debugPrint('[NOTIFS] Blocked showTestNotification (permission=false)');
      return;
    }

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

  // ── Streak reminders ─────────────────────────────────────────────────────

  /// Schedules two fixed repeating daily reminders:
  ///   • 07:00 — morning motivation
  ///   • 22:00 — evening wind-down
  /// Safe to call on every app open — replaces the previous schedule.
  static Future<void> scheduleFixedStreakReminders() async {
    if (!await ensurePermission(prompt: false)) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _streakReminderMorningId,
        channelKey: 'streak_reminder_channel',
        icon: 'resource://drawable/notification_icon',
        largeIcon: 'resource://drawable/app_logo',
        title: '🌅 Start your day the right way!',
        body: 'Keep your streak strong — open the app and swipe today.',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: 7, minute: 0, second: 0,
        repeats: true,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _streakReminderEveningId,
        channelKey: 'streak_reminder_channel',
        icon: 'resource://drawable/notification_icon',
        largeIcon: 'resource://drawable/app_logo',
        title: '🌙 Evening wind-down',
        body: 'Keep your streak going — take a moment to swipe before you rest.',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: 22, minute: 0, second: 0,
        repeats: true,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );

    debugPrint('[NOTIFS] Fixed streak reminders scheduled (07:00 & 22:00 daily)');
  }

  static Future<void> cancelFixedStreakReminders() async {
    await AwesomeNotifications().cancel(_streakReminderMorningId);
    await AwesomeNotifications().cancel(_streakReminderEveningId);
    debugPrint('[NOTIFS] Fixed streak reminders cancelled');
  }

  /// Schedules a one-shot "last chance" notification 22 hours after
  /// [lastSwipeTime] — 2 hours before the user's personal 24 h mark.
  ///
  /// Only call this when the user has no streak protection:
  /// non-premium users, or premium users with 0 freezes remaining.
  /// If the fire-time is already in the past the call is a no-op.
  static Future<void> scheduleStreakUrgencyNotification({
    required DateTime lastSwipeTime,
  }) async {
    if (!await ensurePermission(prompt: false)) return;

    final fireAt = lastSwipeTime.add(const Duration(hours: 22));
    if (fireAt.isBefore(DateTime.now())) {
      debugPrint('[NOTIFS] Urgency notification skipped — fire time in the past');
      return;
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _streakUrgencyId,
        channelKey: 'streak_reminder_channel',
        icon: 'resource://drawable/notification_icon',
        largeIcon: 'resource://drawable/app_logo',
        title: '⚠️ Your streak is about to end!',
        body: 'You have 2 hours left — open the app and swipe to save your streak.',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(
        date: fireAt,
        allowWhileIdle: true,
        preciseAlarm: true,
        repeats: false,
      ),
    );
    debugPrint('[NOTIFS] Urgency notification scheduled for $fireAt');
  }

  static Future<void> cancelStreakUrgencyNotification() async {
    await AwesomeNotifications().cancel(_streakUrgencyId);
    debugPrint('[NOTIFS] Urgency notification cancelled');
  }

  // ── Flash sale (every Friday at 18:00) ────────────────────────────────────

  /// Schedules a weekly flash-sale notification on Fridays at 6 pm.
  /// Safe to call on every app open — replaces the previous schedule if any.
  static Future<void> scheduleFlashSaleNotification() async {
    if (!await ensurePermission(prompt: false)) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _flashSaleId,
        channelKey: 'flash_sale_channel',
        icon: 'resource://drawable/notification_icon',
        largeIcon: 'resource://drawable/app_logo',
        title: '⚡ Flash Sale — Limited Time!',
        body: 'Get Premium at a special price today only. Tap to claim your deal!',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        weekday: 6, // Dart/awesome_notifications: Mon=2 … Fri=6 … Sun=1
        hour: 18,
        minute: 0,
        second: 0,
        repeats: true,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
    debugPrint('[NOTIFS] Flash sale notification scheduled (weekly Fri 18:00)');
  }

  static Future<void> cancelFlashSaleNotification() async {
    await AwesomeNotifications().cancel(_flashSaleId);
    debugPrint('[NOTIFS] Flash sale notification cancelled');
  }

  /// Returns true and clears the pending flag if a flash-sale tap was recorded
  /// (e.g. by [onNotificationTapMethod] in a background isolate).
  static Future<bool> consumeFlashSalePending() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(flashSalePendingKey) ?? false;
    if (pending) await prefs.remove(flashSalePendingKey);
    return pending;
  }

  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> cancelCooldownNotification(String id) async {
    await AwesomeNotifications().cancel(id.hashCode.abs());
  }

  static Future<bool> areNotificationsEnabled() async {
    return AwesomeNotifications().isNotificationAllowed();
  }

  static Future<void> debugPrintScheduled() async {
    final list = await AwesomeNotifications().listScheduledNotifications();
    // ignore: avoid_print
    print('Scheduled notifications: ${list.map((n) => n.content?.id).toList()}');
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());