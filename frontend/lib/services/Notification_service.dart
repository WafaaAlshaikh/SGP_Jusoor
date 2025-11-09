// services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// تهيئة الإشعارات
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  print('✅ Notifications initialized');
}

// 🔔 NEW: Chat notification function (simplified)
Future<void> showChatNotification({
  required String senderName,
  required String message,
  required String chatRoomId,
}) async {
  try {
    final androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      chatRoomId.hashCode,
      'New message from $senderName',
      message,
      platformDetails,
    );

    print('💬 Chat notification sent: $senderName - $message');
  } catch (e) {
    print('❌ Error in showChatNotification: $e');
    // Fallback
    await showSimpleNotification(
      title: 'New message from $senderName',
      body: message,
      id: chatRoomId.hashCode,
    );
  }
}

// دالة للإشعارات العادية
Future<void> showSimpleNotification({
  required String title,
  required String body,
  int id = 0
}) async {
  try {
    final androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General Notifications',
      channelDescription: 'All notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(id, title, body, platformDetails);
    print('✅ Notification shown: $title');
  } catch (e) {
    print('❌ Error showing simple notification: $e');
  }
}

// دالة للإشعارات المستمرة في الشاد
Future<void> showPersistentShadeNotification({
  required int id,
  required String title,
  required String body
}) async {
  try {
    final androidDetails = AndroidNotificationDetails(
      'persistent_shade_channel',
      'Persistent Shade Notifications',
      channelDescription: 'Notifications that stay in shade until manually dismissed',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(id, title, body, platformDetails);
    print('🔥 Persistent notification shown: $title');
  } catch (e) {
    print('❌ Error showing persistent notification: $e');
    await showSimpleNotification(title: title, body: body, id: id);
  }
}

// 🔔 NEW: Setup Firebase messaging
Future<void> setupFirebaseMessaging() async {
  try {
    // طلب الإذن للإشعارات (لـ iOS)
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('🔔 User granted permission: ${settings.authorizationStatus}');

    // التعامل مع الإشعارات عندما التطبيق في المقدمة
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    // التعامل مع الإشعارات عندما يضغط المستخدم عليها
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 A notification message was clicked!');
      print('Message data: ${message.data}');
    });

    print('✅ Firebase Messaging setup completed');
  } catch (e) {
    print('❌ Error setting up Firebase Messaging: $e');
  }
}

// دالة لجدولة الإشعار اليومي
Future<void> scheduleDailyMoodNotification() async {
  final now = DateTime.now();
  var targetTime = DateTime(now.year, now.month, now.day, 20, 0);

  if (targetTime.isBefore(now)) {
    targetTime = targetTime.add(const Duration(days: 1));
  }

  final durationUntil8PM = targetTime.difference(now);

  print('⏰ Daily notification scheduled in: ${durationUntil8PM.inHours}h ${durationUntil8PM.inMinutes.remainder(60)}m');

  Future.delayed(durationUntil8PM, () async {
    await showPersistentShadeNotification(
      id: 0,
      title: 'PureMood - تسجيل المزاج 🎯',
      body: 'هل سجلت مزاجك اليوم؟ اضغط لتسجيل مزاجك الآن!',
    );

    // جدول ليوم الغد
    scheduleDailyMoodNotification();
  });
}

// دالة لجدولة إشعار تجريبي
Future<void> scheduleTestNotification() async {
  print('⏰ Scheduling test notification in 1 minute...');

  Future.delayed(const Duration(minutes: 1), () async {
    await showPersistentShadeNotification(
      id: 999,
      title: 'PureMood - Test Notification',
      body: 'This is a test notification! 🎯',
    );
  });
}

// دالة لإعادة جدولة الإشعارات
Future<void> rescheduleNotificationsOnAppStart() async {
  await flutterLocalNotificationsPlugin.cancelAll();
  await scheduleDailyMoodNotification();
  await scheduleTestNotification();
  print('🔄 All notifications rescheduled');
}

// دالة لإلغاء الإشعارات المستمرة
Future<void> cancelPersistentNotifications() async {
  await flutterLocalNotificationsPlugin.cancel(0);
  await flutterLocalNotificationsPlugin.cancel(998);
  await flutterLocalNotificationsPlugin.cancel(999);
  print('❌ All persistent notifications cancelled');
}