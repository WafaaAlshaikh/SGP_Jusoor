// services/complete_notification_service.dart
import 'package:flutter/material.dart'; // 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CompleteNotificationService {
  static final CompleteNotificationService _instance = CompleteNotificationService._internal();
  factory CompleteNotificationService() => _instance;
  CompleteNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  // 
  static const String CHAT_CHANNEL = 'chat_channel';
  static const String SYSTEM_CHANNEL = 'system_channel';
  static const String ALERT_CHANNEL = 'alert_channel';

  // 
  bool _isAppInForeground = true;

  // 
  // Future<void> initializeCompleteNotifications() async {
  //   try {
  //     print('');
  //
  //     // 1.
  //     await _initializeLocalNotifications();
  //
  //     // 2. FCM
  //     await _initializeFCM();
  //
  //     // 3.
  //     await _requestPermissions();
  //
  //     // 4.
  //     await _getFCMToken();
  //
  //     // 5.
  //     await _cleanOldNotifications();
  //
  //     print('');
  //
  //   } catch (e) {
  //     print(' $e');
  //   }
  // }

  //  1. 
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 
    await _createNotificationChannels();

    print('');
  }

  //  2. FCM
  Future<void> _initializeFCM() async {
    // 
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    print('');
  }

  //  3. 
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

      print('');

    } catch (e) {
      print(' $e');
    }
  }

  //  4. 
  Future<void> _getFCMToken() async {
    try {
      String? token = await firebaseMessaging.getToken();
      if (token != null) {
        print('');

        // 
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);

        // 
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      print(' $e');
    }
  }

  // 
  // Future<void> _createNotificationChannels() async {
  //   //
  //   final AndroidNotificationDetails chatChannel = AndroidNotificationDetails(
  //     CHAT_CHANNEL,
  //     '',
  //     channelDescription: '',
  //     importance: Importance.high,
  //     priority: Priority.high,
  //     playSound: true,
  //     enableVibration: true,
  //   );
  //
  //   //
  //   final AndroidNotificationDetails systemChannel = AndroidNotificationDetails(
  //     SYSTEM_CHANNEL,
  //     '',
  //     channelDescription: '',
  //     importance: Importance.defaultImportance,
  //     priority: Priority.defaultPriority,
  //     playSound: true,
  //     enableVibration: false,
  //   );
  //
  //   //
  //   final AndroidNotificationDetails alertChannel = AndroidNotificationDetails(
  //     ALERT_CHANNEL,
  //     '',
  //     channelDescription: '',
  //     importance: Importance.max,
  //     priority: Priority.high,
  //     playSound: true,
  //     enableVibration: true,
  //   );
  //
  //   await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
  //       AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
  //       AndroidNotificationChannel(
  //         CHAT_CHANNEL,
  //         '',
  //         importance: Importance.high,
  //       ));
  //
  //   print('');
  // }


  // 1. تعليق أو تعديل _createNotificationChannels()
  Future<void> _createNotificationChannels() async {
    print('ℹ️ تفادي إنشاء القنوات - تم إنشاؤها مسبقاً في notification_service');
    return; // لا تفعل شيئاً
  }

/// في complete_notification_service.dart
  Future<void> initializeCompleteNotifications() async {
    print('🔄 تهيئة خدمة الشات فقط...');

    // فقط معالجة الشات
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      final type = data['type'] ?? '';

      // فقط معالجة إشعارات الشات
      if (type == 'chat' || data.containsKey('chatRoomId')) {
        print('💬 Chat notification received');
        // معالجة الشات هنا
      }
    });

    print('✅ خدمة الشات جاهزة');
  }

  // 
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('');

    // //
    if (_isAppInForeground) {
     await _showInAppNotification(message);
   } else {
     await _showSystemNotification(message);
   }
  }

  // 
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('');
    await _handleNotificationAction(message.data);
  }

  // 
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print('');

    // 
    await _instance._showSystemNotification(message);

    // 
    await _instance._storeNotification(message);
  }

  // 
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

        print('');
      }
    } catch (e) {
      print(' $e');
    }
  }

  // 
  Future<void> _showInAppNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      // 
      print('');

      // 
      await _storeNotification(message);

    } catch (e) {
      print(' $e');
    }
  }

  // 
  Future<void> _storeNotification(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notification = message.notification;
      final data = message.data;

      // 
      final String? notificationsJson = prefs.getString('stored_notifications');
      List<Map<String, dynamic>> notifications = [];

      if (notificationsJson != null) {
        notifications = List<Map<String, dynamic>>.from(json.decode(notificationsJson));
      }

      // 
      notifications.add({
        'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': notification?.title ?? data['title'] ?? '',
        'body': notification?.body ?? data['body'] ?? '',
        'type': data['type'] ?? 'general',
        'chatRoomId': data['chatRoomId'],
        'senderId': data['senderId'],
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
        'data': data,
      });

      // (100 )
      if (notifications.length > 100) {
        notifications = notifications.sublist(notifications.length - 100);
      }

      await prefs.setString('stored_notifications', json.encode(notifications));

      print('');
    } catch (e) {
      print(' $e');
    }
  }

  // 
  void _onNotificationTapped(NotificationResponse response) async {
    print('');

    try {
      if (response.payload != null) {
        final Map<String, dynamic> data = json.decode(response.payload!);
        await _handleNotificationAction(data);
      }
    } catch (e) {
      print(' $e');
    }
  }

  // 
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

  // 
  Future<void> _handleChatNotification(Map<String, dynamic> data) async {
    final String? chatRoomId = data['chatRoomId'];
    final String? notificationId = data['id']?.toString();

    if (chatRoomId != null) {
      print('');

      // 
      // Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatRoomId: chatRoomId)));

      // 
      if (notificationId != null) {
        await _markNotificationAsRead(notificationId);
      }
    }
  }

  // 
  Future<void> _handleSystemNotification(Map<String, dynamic> data) async {
    print('');
    // 
  }

  // 
  Future<void> _handleGeneralNotification(Map<String, dynamic> data) async {
    print('');
    // 
  }

  // 
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token') ?? '';

      if (authToken.trim().isEmpty) {
        return;
      }

      final baseUrl = kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';
      final response = await http.post(
        Uri.parse('$baseUrl/device-tokens/register'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'token': token,
          'platform': kIsWeb ? 'web' : 'mobile',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('');
      }

    } catch (e) {
      print(' $e');
    }
  }

  // 
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