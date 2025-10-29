import 'dart:ui';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
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
      ],
    );

    // ✅ Do NOT auto-open settings. Only optionally ask.
    if (promptUser) {
      await ensurePermission(prompt: true);
    }
  }

  /// Centralized guard. If `prompt` is true, show the OS dialog once.
  /// If `openSettingsOnDeny` is true and the user still denies after the
  /// system prompt, we open the app's Settings page.
  static Future<bool> ensurePermission({
    bool prompt = false,
    bool openSettingsOnDeny = false,
  }) async {
    // Check current status first
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (allowed) return true;

    // Optionally show the native permission dialog
    if (prompt) {
      try {
        // Some plugin versions return void here; that's fine — we'll re-check below
        await AwesomeNotifications().requestPermissionToSendNotifications();
      } catch (_) {
        // Ignore and fall through to re-check
      }
    } else {
      // No prompt requested and not allowed
      return false;
    }

    // Re-check after the prompt
    final allowedAfterPrompt = await AwesomeNotifications().isNotificationAllowed();
    if (allowedAfterPrompt) return true;

    // Still denied — optionally take user to Settings
    if (openSettingsOnDeny) {
      try {
        await openAppSettings();
      } catch (_) {
        // Best-effort only
      }
    }

    // Final status after any Settings jump
    return await AwesomeNotifications().isNotificationAllowed();
  }

  /// Optional: expose a manual way to open Settings from a user-tapped button.
  static Future<void> openSettings() async {
    // Uses permission_handler's top-level API
    await openAppSettings();
  }

  /// --- SCHEDULERS (all guarded) ---

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