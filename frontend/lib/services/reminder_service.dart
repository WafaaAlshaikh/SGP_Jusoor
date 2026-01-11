// services/reminder_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReminderService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Initialize notifications
  static Future<void> initialize() async {
    if (!_isInitialized) {
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
      );

      await _notificationsPlugin.initialize(settings);
      _isInitialized = true;
      print('✅ ReminderService initialized successfully');
    }
  }

  // Schedule a reminder
  Future<void> scheduleReminder(SessionReminder reminder) async {
    try {
      print('🔍 ======= DEBUG SCHEDULE REMINDER =======');
      print('📅 وقت التذكير المدخل: ${reminder.reminderTime}');
      print('⏰ الوقت الحالي على الجهاز: ${DateTime.now()}');
      print(
          '📊 الفرق بالثواني: ${reminder.reminderTime.difference(DateTime.now()).inSeconds}');

      if (!_isInitialized) {
        await initialize();
      }

      final now = DateTime.now();
      final difference = reminder.reminderTime.difference(now);

      if (difference.inSeconds <= 0) {
        print(
            '⚠️ Reminder time is in the past, showing immediate notification');
        await _showImmediateNotification(reminder);
        return;
      }

      print('✅ الوقت في المستقبل، سيتم الجدولة');

      const androidDetails = AndroidNotificationDetails(
        'reminder_channel',
        'Session Reminders',
        channelDescription: 'Reminders for upcoming sessions',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        timeoutAfter: 3600000,
        styleInformation: BigTextStyleInformation(''),
      );

      final scheduledTime = _getSafeTZDateTime(reminder.reminderTime);

      print('📅 الوقت بعد التحويل إلى TZDateTime: $scheduledTime');

      // ✅ Schedule notification بدون السطر الذي يسبب المشكلة
      await _notificationsPlugin.zonedSchedule(
        reminder.hashCode,
        'Session Reminder: ${reminder.sessionTitle}',
        'Your session starts at ${DateFormat('h:mm a').format(reminder.sessionDateTime)}',
        scheduledTime,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: json.encode({
          'type': 'session_reminder',
          'sessionId': reminder.sessionId,
          'title': reminder.sessionTitle,
          'time': reminder.sessionDateTime.toIso8601String(),
        }),
      );

      await _saveReminder(reminder);

      print(
          '✅ Reminder scheduled for ${DateFormat('yyyy-MM-dd HH:mm').format(reminder.reminderTime)}');
    } catch (e, stackTrace) {
      print('❌ Failed to schedule reminder: $e');
      print('   Stack trace: $stackTrace');
      await _scheduleWithAlternativeMethod(reminder);
    }
  }

  Future<void> _scheduleWithAlternativeMethod(SessionReminder reminder) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'reminder_channel_backup',
        'Session Reminders Backup',
        channelDescription: 'Backup reminder notifications',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      final delay = reminder.reminderTime.difference(DateTime.now());

      if (delay.inSeconds > 0) {
        await _showImmediateNotification(reminder);
        await _saveReminderWithDelay(reminder, delay);
        print(
            '✅ Reminder scheduled with backup method (${delay.inMinutes} minutes delay)');
      } else {
        print(
            '⚠️ Reminder time is in the past, showing immediate notification');
        await _showImmediateNotification(reminder);
      }
    } catch (e) {
      print('❌ Backup method also failed: $e');
      await _showImmediateNotification(reminder);
    }
  }

  Future<void> _saveReminderWithDelay(
      SessionReminder reminder, Duration delay) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = await getReminders();

      final actualDelay =
          delay.inMinutes > 60 ? const Duration(minutes: 60) : delay;

      final reminderWithDelay = SessionReminder(
        sessionId: reminder.sessionId,
        sessionTitle: reminder.sessionTitle,
        sessionDateTime: reminder.sessionDateTime,
        reminderTime: DateTime.now().add(actualDelay),
        isActive: true,
      );

      reminders.add(reminderWithDelay);
      final reminderMaps = reminders.map((r) => r.toMap()).toList();
      await prefs.setString('session_reminders', json.encode(reminderMaps));
    } catch (e) {
      print('⚠️ Error saving reminder with delay: $e');
    }
  }

  Future<void> _showImmediateNotification(SessionReminder reminder) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'reminder_channel_immediate',
        'Session Reminders',
        channelDescription: 'Immediate session reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _notificationsPlugin.show(
        reminder.hashCode,
        '📅 Session Reminder',
        '${reminder.sessionTitle}',
        const NotificationDetails(android: androidDetails),
        payload: json.encode({
          'type': 'reminder_immediate',
          'sessionId': reminder.sessionId,
          'title': reminder.sessionTitle,
        }),
      );

      print('📱 Immediate notification shown for: ${reminder.sessionTitle}');
    } catch (e) {
      print('⚠️ Could not show immediate notification: $e');
    }
  }

  tz.TZDateTime _getSafeTZDateTime(DateTime dateTime) {
    try {
      print('🔧 تحويل DateTime إلى TZDateTime...');
      print('   المدخل: $dateTime');

      if (!tz.timeZoneDatabase.isInitialized) {
        tz.initializeTimeZones();
      }

      final location = tz.getLocation('UTC');
      print('   الموقع الزمني المستخدم: ${location.name}');

      final result = tz.TZDateTime.from(dateTime, location);
      print('   الناتج: $result');

      return result;
    } catch (e) {
      print('⚠️ Error in _getSafeTZDateTime: $e');
      final location = tz.getLocation('UTC');
      return tz.TZDateTime.from(dateTime, location);
    }
  }

  Future<void> _saveReminder(SessionReminder reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = await getReminders();

      final existingIndex =
          reminders.indexWhere((r) => r.sessionId == reminder.sessionId);
      if (existingIndex != -1) {
        reminders[existingIndex] = reminder;
      } else {
        reminders.add(reminder);
      }

      final reminderMaps = reminders.map((r) => r.toMap()).toList();
      await prefs.setString('session_reminders', json.encode(reminderMaps));

      print('💾 Reminder saved: ${reminder.sessionTitle}');
    } catch (e) {
      print('❌ Error saving reminder: $e');
    }
  }

  Future<List<SessionReminder>> getReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = prefs.getString('session_reminders');

    if (remindersJson == null) return [];

    try {
      final List<dynamic> reminderMaps = json.decode(remindersJson);
      return reminderMaps.map((map) {
        return SessionReminder(
          sessionId: map['sessionId'],
          sessionTitle: map['sessionTitle'],
          sessionDateTime: DateTime.parse(map['sessionDateTime']),
          reminderTime: DateTime.parse(map['reminderTime']),
          isActive: map['isActive'] ?? true,
        );
      }).toList();
    } catch (e) {
      print('Error loading reminders: $e');
      return [];
    }
  }

  Future<void> cancelReminder(String sessionId) async {
    try {
      final reminders = await getReminders();
      final reminder = reminders.firstWhere(
        (r) => r.sessionId == sessionId,
        orElse: () => throw Exception('Reminder not found'),
      );

      await _notificationsPlugin.cancel(reminder.hashCode);

      final updatedReminders =
          reminders.where((r) => r.sessionId != sessionId).toList();
      final prefs = await SharedPreferences.getInstance();
      final reminderMaps = updatedReminders.map((r) => r.toMap()).toList();
      await prefs.setString('session_reminders', json.encode(reminderMaps));

      print('✅ Reminder cancelled for session: $sessionId');
    } catch (e) {
      print('⚠️ Error cancelling reminder: $e');
    }
  }

  Future<void> cleanUpPastReminders() async {
    try {
      final reminders = await getReminders();
      final now = DateTime.now();

      final activeReminders = reminders.where((reminder) {
        final sessionPassed = reminder.sessionDateTime.isBefore(now);

        if (sessionPassed) {
          _notificationsPlugin.cancel(reminder.hashCode);
          return false;
        }

        return reminder.isActive;
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      final reminderMaps = activeReminders.map((r) => r.toMap()).toList();
      await prefs.setString('session_reminders', json.encode(reminderMaps));

      print('✅ Cleaned up past reminders. Active: ${activeReminders.length}');
    } catch (e) {
      print('⚠️ Error cleaning up past reminders: $e');
    }
  }

  Future<bool> hasReminder(String sessionId) async {
    final reminders = await getReminders();
    return reminders.any(
        (reminder) => reminder.sessionId == sessionId && reminder.isActive);
  }

  Future<SessionReminder?> getReminderForSession(String sessionId) async {
    final reminders = await getReminders();
    try {
      return reminders
          .firstWhere((reminder) => reminder.sessionId == sessionId);
    } catch (e) {
      return null;
    }
  }
}
