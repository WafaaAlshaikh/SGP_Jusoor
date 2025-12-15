// services/complete_notification_service.dart
import 'package:flutter/material.dart'; // 🆕 ADD THIS
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CompleteNotificationService {
  static final CompleteNotificationService _instance = CompleteNotificationService._internal();
  factory CompleteNotificationService() => _instance;
  CompleteNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  // 🔔 أنواع الإشعارات
  static const String CHAT_CHANNEL = 'chat_channel';
  static const String SYSTEM_CHANNEL = 'system_channel';
  static const String ALERT_CHANNEL = 'alert_channel';

  // 📱 حالة التطبيق
  bool _isAppInForeground = true;

  // 🎯 تهيئة كاملة للإشعارات
  Future<void> initializeCompleteNotifications() async {
    try {
      print('🚀 بدء تهيئة النظام الكامل للإشعارات...');

      // 1. تهيئة الإشعارات المحلية
      await _initializeLocalNotifications();

      // 2. تهيئة FCM
      await _initializeFCM();

      // 3. طلب الأذونات
      await _requestPermissions();

      // 4. الحصول على Token
      await _getFCMToken();

      // 5. تنظيف الإشعارات القديمة
      await _cleanOldNotifications();

      print('✅ النظام الكامل للإشعارات جاهز!');

    } catch (e) {
      print('❌ خطأ في تهيئة الإشعارات: $e');
    }
  }

  // 🔧 1. تهيئة الإشعارات المحلية
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // إنشاء قنوات الإشعارات
    await _createNotificationChannels();

    print('✅ الإشعارات المحلية مهيأة');
  }

  // 📡 2. تهيئة FCM
  Future<void> _initializeFCM() async {
    // التعامل مع الإشعارات في المقدمة
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // التعامل مع الإشعارات عند الضغط عليها
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    print('✅ FCM مهيأ');
  }

  // 🔐 3. طلب الأذونات
  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      print('🎫 حالة الأذونات: ${settings.authorizationStatus}');

    } catch (e) {
      print('❌ خطأ في طلب الأذونات: $e');
    }
  }

  // 🎫 4. الحصول على FCM Token
  Future<void> _getFCMToken() async {
    try {
      String? token = await firebaseMessaging.getToken();
      if (token != null) {
        print('📱 FCM Token: $token');

        // حفظ Token في التخزين المحلي
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);

        // هنا بتكون عملية إرسال الـ Token للـ Backend
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      print('❌ خطأ في الحصول على Token: $e');
    }
  }

  // 🛠️ إنشاء قنوات الإشعارات
  Future<void> _createNotificationChannels() async {
    // قناة المحادثات
    final AndroidNotificationDetails chatChannel = AndroidNotificationDetails(
      CHAT_CHANNEL,
      'المحادثات',
      channelDescription: 'إشعارات رسائل المحادثات الجديدة',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة النظام
    final AndroidNotificationDetails systemChannel = AndroidNotificationDetails(
      SYSTEM_CHANNEL,
      'إشعارات النظام',
      channelDescription: 'إشعارات النظام والتحديثات',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: false,
    );

    // قناة التنبيهات المهمة
    final AndroidNotificationDetails alertChannel = AndroidNotificationDetails(
      ALERT_CHANNEL,
      'التنبيهات المهمة',
      channelDescription: 'تنبيهات مهمة وعاجلة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        AndroidNotificationChannel(
          CHAT_CHANNEL,
          'المحادثات',
          importance: Importance.high,
        ));

    print('✅ قنوات الإشعارات مبنية');
  }

  // 💬 معالجة الإشعارات في المقدمة
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 إشعار في المقدمة: ${message.messageId}');

    // إذا التطبيق في المقدمة، ما نعرض إشعار نظام
    // if (_isAppInForeground) {
    //   await _showInAppNotification(message);
    // } else {
      await _showSystemNotification(message);
    // }
  }

  // 👆 معالجة الإشعارات عند الضغط
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('👆 تم الضغط على إشعار: ${message.messageId}');
    await _handleNotificationAction(message.data);
  }

  // 📋 معالجة الإشعارات في الخلفية
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print('📋 إشعار في الخلفية: ${message.messageId}');

    // عرض إشعار النظام
    await _instance._showSystemNotification(message);

    // تخزين الإشعار محلياً
    await _instance._storeNotification(message);
  }

  // 🎯 عرض إشعار في النظام
  Future<void> _showSystemNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          data['channel'] ?? CHAT_CHANNEL,
          _getChannelName(data['channel']),
          channelDescription: _getChannelDescription(data['channel']),
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          autoCancel: true,
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        );

        final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

        await flutterLocalNotificationsPlugin.show(
          message.hashCode,
          notification.title ?? 'Jusoor App',
          notification.body ?? '',
          platformDetails,
          payload: json.encode(data),
        );

        print('🔔 إشعار نظام معروض: ${notification.title}');
      }
    } catch (e) {
      print('❌ خطأ في عرض إشعار النظام: $e');
    }
  }

  // 💫 عرض إشعار داخل التطبيق
  Future<void> _showInAppNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      // هنا بتكون عملية عرض إشعار داخلي (مثل SnackBar أو Dialog)
      print('💫 إشعار داخلي: ${notification?.title}');

      // تخزين الإشعار للعرض في شاشة الإشعارات
      await _storeNotification(message);

    } catch (e) {
      print('❌ خطأ في الإشعار الداخلي: $e');
    }
  }

  // 💾 تخزين الإشعار محلياً
  Future<void> _storeNotification(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notification = message.notification;
      final data = message.data;

      // جلب الإشعارات الحالية
      final String? notificationsJson = prefs.getString('stored_notifications');
      List<Map<String, dynamic>> notifications = [];

      if (notificationsJson != null) {
        notifications = List<Map<String, dynamic>>.from(json.decode(notificationsJson));
      }

      // إضافة الإشعار الجديد
      notifications.add({
        'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': notification?.title ?? data['title'] ?? 'إشعار جديد',
        'body': notification?.body ?? data['body'] ?? '',
        'type': data['type'] ?? 'general',
        'chatRoomId': data['chatRoomId'],
        'senderId': data['senderId'],
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
        'data': data,
      });

      // حفظ الإشعارات (الحد الأقصى 100 إشعار)
      if (notifications.length > 100) {
        notifications = notifications.sublist(notifications.length - 100);
      }

      await prefs.setString('stored_notifications', json.encode(notifications));

      print('💾 الإشعار مخزن: ${notification?.title}');

    } catch (e) {
      print('❌ خطأ في تخزين الإشعار: $e');
    }
  }

  // 👆 عند الضغط على الإشعار
  void _onNotificationTapped(NotificationResponse response) async {
    print('👆 تم الضغط على إشعار: ${response.id}');

    try {
      if (response.payload != null) {
        final Map<String, dynamic> data = json.decode(response.payload!);
        await _handleNotificationAction(data);
      }
    } catch (e) {
      print('❌ خطأ في معالجة ضغط الإشعار: $e');
    }
  }

  // 🎯 معالجة إجراء الإشعار
  Future<void> _handleNotificationAction(Map<String, dynamic> data) async {
    final String type = data['type'] ?? 'general';

    switch (type) {
      case 'chat':
        await _handleChatNotification(data);
        break;
      case 'system':
        await _handleSystemNotification(data);
        break;
      default:
        await _handleGeneralNotification(data);
    }
  }

  // 💬 معالجة إشعار المحادثة
  Future<void> _handleChatNotification(Map<String, dynamic> data) async {
    final String? chatRoomId = data['chatRoomId'];
    final String? notificationId = data['id']?.toString();

    if (chatRoomId != null) {
      print('💬 فتح محادثة: $chatRoomId');

      // هنا بتكون عملية فتح شاشة المحادثة
      // Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatRoomId: chatRoomId)));

      // وضع علامة مقروء على الإشعار
      if (notificationId != null) {
        await _markNotificationAsRead(notificationId);
      }
    }
  }

  // ⚙️ معالجة إشعار النظام
  Future<void> _handleSystemNotification(Map<String, dynamic> data) async {
    print('⚙️ معالجة إشعار النظام');
    // معالجة إشعارات النظام
  }

  // 📱 معالجة الإشعارات العامة
  Future<void> _handleGeneralNotification(Map<String, dynamic> data) async {
    print('📱 معالجة إشعار عام');
    // معالجة الإشعارات العامة
  }

  // 🎫 إرسال الـ Token للـ Backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      // هنا بتكون عملية إرسال الـ Token لـ Backend
      print('📤 إرسال Token للـ Backend: $token');

    } catch (e) {
      print('❌ خطأ في إرسال Token: $e');
    }
  }

  // 🧹 تنظيف الإشعارات القديمة
  Future<void> _cleanOldNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString('stored_notifications');

      if (notificationsJson != null) {
        List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(json.decode(notificationsJson));
        final now = DateTime.now();

        // إزالة الإشعارات الأقدم من 30 يوم
        notifications = notifications.where((notification) {
          final timestamp = DateTime.parse(notification['timestamp']);
          return now.difference(timestamp).inDays <= 30;
        }).toList();

        await prefs.setString('stored_notifications', json.encode(notifications));
        print('🧹 تم تنظيف الإشعارات القديمة');
      }
    } catch (e) {
      print('❌ خطأ في تنظيف الإشعارات: $e');
    }
  }

  // ✅ وضع علامة مقروء على الإشعار
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString('stored_notifications');

      if (notificationsJson != null) {
        List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(json.decode(notificationsJson));

        for (var i = 0; i < notifications.length; i++) {
          if (notifications[i]['id'] == notificationId) {
            notifications[i]['read'] = true;
            break;
          }
        }

        await prefs.setString('stored_notifications', json.encode(notifications));
        print('✅ تم وضع علامة مقروء على الإشعار: $notificationId');
      }
    } catch (e) {
      print('❌ خطأ في وضع علامة مقروء: $e');
    }
  }

  // 🎯 دوال مساعدة
  String _getChannelName(String? channel) {
    switch (channel) {
      case CHAT_CHANNEL: return 'المحادثات';
      case SYSTEM_CHANNEL: return 'إشعارات النظام';
      case ALERT_CHANNEL: return 'التنبيهات المهمة';
      default: return 'الإشعارات';
    }
  }

  String _getChannelDescription(String? channel) {
    switch (channel) {
      case CHAT_CHANNEL: return 'إشعارات رسائل المحادثات الجديدة';
      case SYSTEM_CHANNEL: return 'إشعارات النظام والتحديثات';
      case ALERT_CHANNEL: return 'تنبيهات مهمة وعاجلة';
      default: return 'جميع الإشعارات';
    }
  }

  // 📱 تحديث حالة التطبيق
  void updateAppState(bool isForeground) {
    _isAppInForeground = isForeground;
    print(isForeground ? '📱 التطبيق في المقدمة' : '📱 التطبيق في الخلفية');
  }

  // 🗑️ حذف جميع الإشعارات
  Future<void> clearAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stored_notifications');

      print('🗑️ تم حذف جميع الإشعارات');
    } catch (e) {
      print('❌ خطأ في حذف الإشعارات: $e');
    }
  }
}