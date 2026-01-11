import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// متغير لتتبع ما إذا تم إنشاء القنوات
bool _channelsCreated = false;

/// ===============================
/// INITIALIZE NOTIFICATIONS
/// ===============================


Future<void> initializeNotifications() async {
  print('📱 تهيئة الإشعارات الأساسية...');

  // فقط تهيئة الأساسيات
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  print('✅ الإشعارات الأساسية جاهزة');
}

/// ===============================
/// إنشاء القنوات بدون crash
/// ===============================
Future<void> _createNotificationChannelsSafely() async {
  try {
    print('🔄 Creating notification channels...');

    final androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      print('⚠️ Android plugin not available');
      return;
    }

    // الانتظار قليلاً لضمان استقرار النظام
    await Future.delayed(Duration(milliseconds: 500));

    // تعريف القنوات المطلوبة
    final channels = [
      AndroidNotificationChannel(
        'default_channel',
        'General Notifications',
        description: 'All general notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'chat_channel',
        'Chat Messages',
        description: 'Notifications for new chat messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'persistent_shade_channel',
        'Persistent Notifications',
        description: 'Notifications that stay until manually dismissed',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),

      AndroidNotificationChannel(
    'manager_channel',
    'Manager Notifications',
    description: 'Notifications for managers',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  ),

  AndroidNotificationChannel(
    'payment_channel',
    'Payment Notifications',
    description: 'Notifications for payments',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  ),
  AndroidNotificationChannel(
    'pending_sessions_channel',
    'Pending Sessions',
    description: 'Notifications for new session requests',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  ),
    ];
    


    // محاولة إنشاء كل قناة مع معالجة الأخطاء
    for (var channel in channels) {
      try {
        await androidPlugin.createNotificationChannel(channel);
        print('✅ Created notification channel: ${channel.id}');
        await Future.delayed(Duration(milliseconds: 100)); // تأخير بين القنوات
      } catch (channelError) {
        print('⚠️ Error creating channel ${channel.id}: $channelError');

        // إذا كانت المشكلة أن القناة موجودة بالفعل، فهذا ليس خطأ
        if (channelError.toString().contains('already exists') ||
            channelError.toString().contains('EXISTS')) {
          print('ℹ️ Channel ${channel.id} already exists');
        }
      }
    }

    print('✅ Notification channels created safely');
  } catch (e) {
    print('❌ Error in _createNotificationChannelsSafely: $e');
    // محاولة إنشاء قناة أساسية فقط
    await _createBasicChannel();
  }
}

/// ===============================
/// إنشاء قناة أساسية كبديل
/// ===============================
Future<void> _createBasicChannel() async {
  try {
    final androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final basicChannel = AndroidNotificationChannel(
        'default_channel',
        'General Notifications',
        description: 'All notifications',
        importance: Importance.high,
      );

      await androidPlugin.createNotificationChannel(basicChannel);
      print('✅ Created basic notification channel');
    }
  } catch (e) {
    print('❌ Failed to create even basic channel: $e');
  }
}

/// ===============================
/// تهيئة بديلة
/// ===============================
Future<void> _initializeWithFallback() async {
  try {
    print('🔄 Trying fallback initialization...');

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    print('✅ Fallback initialization successful');
  } catch (e) {
    print('❌ Fallback initialization also failed: $e');
  }
}

/// ===============================
/// التحقق مما إذا تم تهيئة الإشعارات
/// ===============================
bool areNotificationsInitialized() {
  return _channelsCreated;
}

/// ===============================
/// إعادة تعيين حالة القنوات (للاستخدام في حالة الخطأ)
/// ===============================
void resetNotificationChannels() {
  _channelsCreated = false;
  print('🔄 Notification channels state reset');
}

/// ===============================
/// SHOW SIMPLE NOTIFICATION
/// ===============================
Future<void> showSimpleNotification({
  required String title,
  required String body,
  int id = 0,
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

/// ===============================
/// SHOW CHAT NOTIFICATION
/// ===============================
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
    await showSimpleNotification(
      title: 'New message from $senderName',
      body: message,
      id: chatRoomId.hashCode,
    );
  }
}

/// ===============================
/// SHOW PERSISTENT NOTIFICATION
/// ===============================
Future<void> showPersistentShadeNotification({
  required int id,
  required String title,
  required String body,
}) async {
  try {
    final androidDetails = AndroidNotificationDetails(
      'persistent_shade_channel',
      'Persistent Notifications',
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