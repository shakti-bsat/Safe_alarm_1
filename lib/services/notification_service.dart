import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int totalSnoozes = 3;

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
    );

    // ✅ Create Android channels (REQUIRED for v20+)
    await _createChannels();
  }

  static Future<void> _createChannels() async {
    const tripChannel = AndroidNotificationChannel(
      'trip_active',
      'Trip Monitoring',
      description: 'Shows when trip monitoring is active',
      importance: Importance.high,
    );

    const confirmationChannel = AndroidNotificationChannel(
      'confirmation_required',
      'Safety Confirmation',
      description: 'Requests safety confirmation from user',
      importance: Importance.max,
    );

    const snoozeChannel = AndroidNotificationChannel(
      'snooze',
      'Snooze',
      description: 'Trip snooze notifications',
      importance: Importance.high,
    );

    const escalationChannel = AndroidNotificationChannel(
      'escalation',
      'Emergency Escalation',
      description: 'Emergency escalation alerts',
      importance: Importance.max,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(tripChannel);
    await androidPlugin?.createNotificationChannel(confirmationChannel);
    await androidPlugin?.createNotificationChannel(snoozeChannel);
    await androidPlugin?.createNotificationChannel(escalationChannel);
  }

  static Future<void> showTripActiveNotification(DateTime eta) async {
    final h = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final m = eta.minute.toString().padLeft(2, '0');
    final period = eta.hour < 12 ? 'AM' : 'PM';
    await _plugin.show(
      id: 1,
      title: '🛡️ SafeAlarm Active',
      body: 'Monitoring your trip. ETA: $h:$m $period',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'trip_active',
          'Trip Monitoring',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
        ),
      ),
    );
  }

  static Future<void> showConfirmationRequired() async {
    await _plugin.show(
      id: 2,
      title: '⏰ Are you safe?',
      body: 'Your ETA has passed. Please confirm your arrival.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'confirmation_required',
          'Safety Confirmation',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'alert.aiff',
        ),
      ),
    );
  }

  static Future<void> showSnoozeNotification(
      int minutes, int snoozeCount) async {
    final remaining = totalSnoozes - snoozeCount;

    await _plugin.show(
      id: 3,
      title:
          '⏳ Snooze Active ($remaining snooze${remaining == 1 ? '' : 's'} left)',
      body: 'We\'ll check again in $minutes minutes.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'snooze',
          'Snooze',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showEscalationNotification() async {
    await _plugin.show(
      id: 4,
      title: '🚨 Emergency Alert Sent',
      body: 'Your trusted contacts have been notified with your location.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'escalation',
          'Emergency Escalation',
          importance: Importance.max,
          priority: Priority.max,
          color: Color(0xFFFF3B30),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
