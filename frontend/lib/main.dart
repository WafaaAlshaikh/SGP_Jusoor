import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:frontend/screens/admin/app_content_management.dart';
import 'package:frontend/screens/financial_assistance_dashboard.dart';
import 'package:frontend/screens/manager_home_screen.dart';
import 'package:frontend/theme/app_color.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/specialist_dashboard_screen.dart';
import 'screens/full_vacation_request_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/map_screen.dart';
import 'screens/parent_payment_dashboard.dart';
import 'screens/donor_dashboard_screen.dart';
import 'screens/browse_centers_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/institution_management.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/audit_logs.dart';
import 'screens/admin/content_moderation.dart';
import 'screens/admin/detailed_statistics.dart';
import 'screens/admin/user_management.dart';
import 'screens/admin/donation_management.dart';
import 'screens/admin/report_management.dart';
import 'screens/admin/system_settings.dart';
import 'screens/manager/manager_onboarding_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/notification_service.dart';
import 'services/auth_sync_service.dart';
import 'services/complete_notification_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/language_service.dart';

// 🔥 خيارات Firebase للويب
const firebaseWebOptions = FirebaseOptions(
  apiKey: "AIzaSyATyDfeHwkbDNj02dZcxSafKT_V43ni0wQ",
  authDomain: "jusoor-eb6d3.firebaseapp.com",
  projectId: "jusoor-eb6d3",
  storageBucket: "jusoor-eb6d3.firebasestorage.app",
  messagingSenderId: "576013693747",
  appId: "1:576013693747:web:8c45cbfa9b10009796c446",
  measurementId: "G-Y33PDKTVJD",
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// 📌 دالة استقبال الإشعارات بالخلفية
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
    print("📋 Background message received: ${message.messageId}");
  }
}

// 📌 MAIN
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // اللغة
  final locale = await LanguageService.getLocale();

  print('🚀 بدء تشغيل تطبيق Jusoor...');

  // 🔥 Firebase
  // 🔥 Firebase فقط
  if (kIsWeb) {
    await Firebase.initializeApp(options: firebaseWebOptions);
  } else {
    await Firebase.initializeApp();
  }

  // المزامنة مع Firebase
  await _syncUserWithFirebase();

  // 🔥 الإشعارات - أبسط طريقة ممكنة
  if (!kIsWeb) {
    await _setupSimpleNotifications();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        // يمكنك إضافة المزيد من Providers هنا
      ],
      child: MyApp(locale: locale),
    ),
  );
}

Future<void> _setupSimpleNotifications() async {
  try {
    print('📱 إعداد الإشعارات المبسطة...');

    // 1. طلب الصلاحيات فقط
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. الحصول على التوكن
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      print("📱 Device Token: ${token.substring(0, 20)}...");
      await _saveTokenToPrefs(token);
    }

    // 3. استماع للإشعارات في المقدمة
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🎯 🔥🔥🔥 NOTIFICATION RECEIVED IN APP! 🔥🔥🔥');
      print('   Title: ${message.notification?.title}');
      print('   Body: ${message.notification?.body}');
      print('   Data: ${message.data}');

      // ⬇️ تحقق من نوع الإشعار
      final notificationType = message.data['notificationType'] ?? message.data['type'] ?? 'general';

      switch (notificationType) {
        case 'session_created':
          _handleSessionCreatedNotification(message);
          break;
        case 'schedule_change':
          _handleScheduleNotification(message);
          break;
        case 'session_cancelled':
          _handleSessionCancelledNotification(message);
          break;
        case 'session_status_update':
          _handleSessionStatusNotification(message);
          break;
        case 'session_reschedule_request':
          _handleRescheduleRequestNotification(message);
          break;
        case 'session_approved':
          _handleSessionApprovedNotification(message);
          break;
        case 'session_rejected':
          _handleSessionRejectedNotification(message);
          break;
        case 'session_completed_bulk':
          _handleBulkCompletedNotification(message);
          break;
        case 'specialist_daily_summary':
          _handleSpecialistSummaryNotification(message);
          break;
        default:
          _showSimpleLocalNotification(message);
      }
    });

    print('✅ الإشعارات المبسطة جاهزة');
  } catch (e) {
    print('⚠️ خطأ في إعداد الإشعارات المبسطة: $e');
  }
}

// 📌 معالجة إشعار الجلسة الجديدة
void _handleSessionCreatedNotification(RemoteMessage message) {
  print('📅 Handling session created notification');

  final data = message.data;
  final notification = message.notification;

  print('   Session ID: ${data['sessionId']}');
  print('   Child: ${data['childName']}');
  print('   Date: ${data['sessionDate']}');
  print('   Time: ${data['sessionTime']}');

  // عرض إشعار محلي مخصص
  _showSessionNotification(message);
}

// 📌 معالجة إشعار إلغاء الجلسة
void _handleSessionCancelledNotification(RemoteMessage message) {
  print('❌ Handling session cancelled notification');

  final data = message.data;
  print('   Session ID: ${data['sessionId']}');
  print('   Child: ${data['childName']}');
  print('   Reason: ${data['reason']}');

  _showSessionCancelledNotification(message);
}

// 📌 عرض إشعار إلغاء الجلسة
Future<void> _showSessionCancelledNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    // إعداد محتوى الإشعار
    String? childName = data['childName'];
    String? reason = data['reason'];

    String notificationTitle = notification.title ?? 'Session Cancelled';
    String notificationBody = notification.body ?? '';

    if (notificationBody.isEmpty) {
      notificationBody = 'Session for $childName has been cancelled';
      if (reason != null && reason.isNotEmpty) {
        notificationBody += '\nReason: $reason';
      }
    }

    // عرض الإشعار
    await _showSessionStyleNotification(
      title: notificationTitle,
      body: notificationBody,
      data: data,
      channelId: 'session_channel',
      color: Color(0xFFF44336), // لون أحمر للإلغاء
    );

    print('📱 Session cancelled notification shown');
  } catch (e) {
    print('⚠️ Error showing session cancelled notification: $e');
  }
}

// 📌 معالجة إشعار حالة الجلسة (مكتملة/غائب)
void _handleSessionStatusNotification(RemoteMessage message) {
  print('🔄 Handling session status notification');

  final data = message.data;
  print('   Status: ${data['status']}');
  print('   Child: ${data['childName']}');

  _showSessionStatusNotification(message);
}

// 📌 عرض إشعار حالة الجلسة
Future<void> _showSessionStatusNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    String? status = data['status'];
    String? childName = data['childName'];
    String? reason = data['reason'];

    String notificationTitle = notification.title ?? 'Session Status Updated';
    String notificationBody = notification.body ?? '';

    if (notificationBody.isEmpty) {
      String statusText = status?.toLowerCase() ?? 'updated';
      notificationBody = '${childName ?? "Session"}\'s status changed to $statusText';
      if (reason != null && reason.isNotEmpty) {
        notificationBody += '\nReason: $reason';
      }
    }

    Color? color;
    switch (status?.toLowerCase()) {
      case 'completed':
        color = Color(0xFF4CAF50); // أخضر
        break;
      case 'absent':
        color = Color(0xFFFF9800); // برتقالي
        break;
      default:
        color = Color(0xFF2196F3); // أزرق
    }

    await _showSessionStyleNotification(
      title: notificationTitle,
      body: notificationBody,
      data: data,
      channelId: 'session_channel',
      color: color,
    );

    print('📱 Session status notification shown');
  } catch (e) {
    print('⚠️ Error showing session status notification: $e');
  }
}

// 📌 معالجة إشعار طلب إعادة جدولة
void _handleRescheduleRequestNotification(RemoteMessage message) {
  print('📅 Handling reschedule request notification');

  final data = message.data;
  print('   Old Date: ${data['oldDate']} ${data['oldTime']}');
  print('   New Date: ${data['newDate']} ${data['newTime']}');

  _showRescheduleRequestNotification(message);
}

// 📌 عرض إشعار طلب إعادة جدولة
Future<void> _showRescheduleRequestNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    String? childName = data['childName'];
    String? oldDate = data['oldDate'];
    String? oldTime = data['oldTime'];
    String? newDate = data['newDate'];
    String? newTime = data['newTime'];
    String? reason = data['reason'];

    String notificationTitle = notification.title ?? 'Reschedule Request';
    String notificationBody = notification.body ?? '';

    if (notificationBody.isEmpty) {
      notificationBody = 'Reschedule request for $childName\n';
      if (oldDate != null && oldTime != null) {
        notificationBody += 'From: $oldDate $oldTime\n';
      }
      if (newDate != null && newTime != null) {
        notificationBody += 'To: $newDate $newTime\n';
      }
      if (reason != null && reason.isNotEmpty) {
        notificationBody += 'Reason: $reason';
      }
    }

    await _showSessionStyleNotification(
      title: notificationTitle,
      body: notificationBody,
      data: data,
      channelId: 'session_channel',
      color: Color(0xFF9C27B0), // بنفسجي
    );

    print('📱 Reschedule request notification shown');
  } catch (e) {
    print('⚠️ Error showing reschedule request notification: $e');
  }
}

// 📌 معالجة إشعار موافقة على الجلسة
void _handleSessionApprovedNotification(RemoteMessage message) {
  print('✅ Handling session approved notification');
  _showSessionApprovedNotification(message);
}

// 📌 عرض إشعار موافقة على الجلسة
Future<void> _showSessionApprovedNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    await _showSessionStyleNotification(
      title: notification.title ?? 'Session Approved',
      body: notification.body ?? 'Session has been approved',
      data: data,
      channelId: 'session_channel',
      color: Color(0xFF4CAF50), // أخضر
    );

    print('📱 Session approved notification shown');
  } catch (e) {
    print('⚠️ Error showing session approved notification: $e');
  }
}

// 📌 معالجة إشعار رفض الجلسة
void _handleSessionRejectedNotification(RemoteMessage message) {
  print('❌ Handling session rejected notification');
  _showSessionRejectedNotification(message);
}

// 📌 عرض إشعار رفض الجلسة
Future<void> _showSessionRejectedNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    await _showSessionStyleNotification(
      title: notification.title ?? 'Session Rejected',
      body: notification.body ?? 'Session has been rejected',
      data: data,
      channelId: 'session_channel',
      color: Color(0xFFF44336), // أحمر
    );

    print('📱 Session rejected notification shown');
  } catch (e) {
    print('⚠️ Error showing session rejected notification: $e');
  }
}

// 📌 معالجة إشعار إكمال الجلسات المجمعة
void _handleBulkCompletedNotification(RemoteMessage message) {
  print('📊 Handling bulk completed notification');
  _showBulkCompletedNotification(message);
}

// 📌 عرض إشعار إكمال الجلسات المجمعة
Future<void> _showBulkCompletedNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    await _showSessionStyleNotification(
      title: notification.title ?? 'Sessions Completed',
      body: notification.body ?? 'Multiple sessions have been completed',
      data: data,
      channelId: 'session_channel',
      color: Color(0xFF009688), // تركواز
    );

    print('📱 Bulk completed notification shown');
  } catch (e) {
    print('⚠️ Error showing bulk completed notification: $e');
  }
}

// 📌 معالجة إشعار ملخص المختص
void _handleSpecialistSummaryNotification(RemoteMessage message) {
  print('📈 Handling specialist summary notification');
  _showSpecialistSummaryNotification(message);
}

// 📌 عرض إشعار ملخص المختص
Future<void> _showSpecialistSummaryNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    await _showSessionStyleNotification(
      title: notification.title ?? 'Daily Summary',
      body: notification.body ?? 'Your daily sessions summary',
      data: data,
      channelId: 'system_channel',
      color: Color(0xFF607D8B), // أزرق رمادي
    );

    print('📱 Specialist summary notification shown');
  } catch (e) {
    print('⚠️ Error showing specialist summary notification: $e');
  }
}

// 📌 دالة مساعدة لعرض إشعارات الجلسات بنمط موحد
Future<void> _showSessionStyleNotification({
  required String title,
  required String body,
  required Map<String, dynamic> data,
  required String channelId,
  Color color = const Color(0xFF2196F3),
}) async {
  try {
    // إنشاء القناة إذا لم تكن موجودة
    final channel = AndroidNotificationChannel(
      channelId,
      channelId == 'session_channel' ? 'Session Notifications' : 'System Notifications',
      description: channelId == 'session_channel'
          ? 'Notifications for session updates'
          : 'System notifications and summaries',
      importance: Importance.high,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }

    // عرض الإشعار
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            body,
          ),
          icon: '@mipmap/ic_launcher',
          color: color,
        ),
      ),
      payload: json.encode(data),
    );
  } catch (e) {
    print('⚠️ Error showing session style notification: $e');
  }
}
// 📌 عرض إشعار الجلسة
Future<void> _showSessionNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    // إنشاء قناة مخصصة للجلسات
    const sessionChannel = AndroidNotificationChannel(
      'session_channel',
      'Session Notifications',
      description: 'Notifications for new sessions and updates',
      importance: Importance.max,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(sessionChannel);
    }

    // إعداد محتوى الإشعار
    String? childName = data['childName'];
    String? sessionDate = data['sessionDate'];
    String? sessionTime = data['sessionTime'];

    String notificationBody = notification.body ?? '';
    if (childName != null) {
      notificationBody = 'New session for $childName';
      if (sessionDate != null && sessionTime != null) {
        notificationBody += ' on $sessionDate at $sessionTime';
      }
    }

    // عرض الإشعار
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title ?? 'New Session',
      notificationBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          sessionChannel.id,
          sessionChannel.name,
          channelDescription: sessionChannel.description,
          importance: sessionChannel.importance,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            '${notification.body}\n\n'
                'Tap to view details',
          ),
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2196F3),
        ),
      ),
      payload: json.encode(data),
    );

    print('📱 Session notification shown');
  } catch (e) {
    print('⚠️ Error showing session notification: $e');
  }
}

// 📌 معالجة إشعارات الجداول
void _handleScheduleNotification(RemoteMessage message) {
  print('📅 Handling schedule notification');

  final data = message.data;
  print('   Action: ${data['action']}');
  print('   Day: ${data['day_of_week']}');
  print('   Time: ${data['start_time']} - ${data['end_time']}');

  _showScheduleNotification(message);
}

// 📌 عرض إشعار الجدول
Future<void> _showScheduleNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    // إنشاء قناة مخصصة للجداول
    const scheduleChannel = AndroidNotificationChannel(
      'schedule_channel',
      'Schedule Notifications',
      description: 'Notifications for schedule changes',
      importance: Importance.high,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(scheduleChannel);
    }

    // إعداد محتوى الإشعار
    String action = data['action'] ?? 'updated';
    String day = data['day_of_week'] ?? '';
    String startTime = data['start_time'] ?? '';
    String endTime = data['end_time'] ?? '';

    String notificationTitle = notification.title ?? 'Schedule Update';
    String notificationBody = notification.body ?? '';

    // تخصيص الرسالة حسب نوع التغيير
    if (notificationBody.isEmpty) {
      switch (action) {
        case 'added':
          notificationBody = 'New schedule added for $day: $startTime - $endTime';
          break;
        case 'updated':
          notificationBody = 'Schedule for $day has been updated';
          break;
        case 'deleted':
          notificationBody = 'Schedule for $day has been deleted';
          break;
        case 'bulk_added':
          final count = data['count'] ?? 'multiple';
          notificationBody = '$count schedules have been added';
          break;
      }
    }

    // عرض الإشعار
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notificationTitle,
      notificationBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          scheduleChannel.id,
          scheduleChannel.name,
          channelDescription: scheduleChannel.description,
          importance: scheduleChannel.importance,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            notificationBody,
          ),
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF4CAF50), // لون أخضر للجداول
        ),
      ),
      payload: json.encode(data),
    );

    print('📱 Schedule notification shown');
  } catch (e) {
    print('⚠️ Error showing schedule notification: $e');
  }
}

// 📌 حفظ التوكن في SharedPreferences
Future<void> _saveTokenToPrefs(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    print('💾 Token saved to SharedPreferences');
  } catch (e) {
    print('⚠️ Error saving token: $e');
  }
}

// 📌 عرض إشعار محلي بسيط
Future<void> _showSimpleLocalNotification(RemoteMessage message) async {
  try {
    final notification = message.notification;
    if (notification == null) return;

    // إنشاء قناة مؤقتة إذا لم تكن موجودة
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'simple_channel', // ⬅️ ID جديد مختلف
      'Simple Notifications',
      description: 'Simple notification channel',
      importance: Importance.high,
    );

    // إنشاء القناة
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }

    // عرض الإشعار
    await flutterLocalNotificationsPlugin.show(
      0,
      notification.title ?? 'No Title',
      notification.body ?? 'No Body',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );

    print('📱 Simple local notification shown');
  } catch (e) {
    print('⚠️ Error showing local notification: $e');
  }
}

// 📌 دالة المزامنة مع Firebase
Future<void> _syncUserWithFirebase() async {
  try {
    final authSync = AuthSyncService();
    await authSync.syncCurrentUser();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('🎯 Firebase sync successful: ${user.uid}');
      print('📧 Firebase Email: ${user.email}');
      print('👤 Firebase Display Name: ${user.displayName}');
    } else {
      print('⚠️ No user logged in to Firebase');
    }
  } catch (e) {
    print('❌ Firebase sync failed: $e');
  }
}


// ----------------------------------------------------------------------
// ⭐ APP ROOT
// ----------------------------------------------------------------------

class MyApp extends StatefulWidget {
  final Locale locale;

  const MyApp({super.key, required this.locale});

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final CompleteNotificationService _notificationService =
      CompleteNotificationService();

  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;

    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
      print('📱 بدء متابعة حالة التطبيق');
    }
  }

  

  @override
  void dispose() {
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  // 🔥 حالة التطبيق
  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (!kIsWeb) {
  //     switch (state) {
  //       case AppLifecycleState.resumed:
  //         _notificationService.updateAppState(true);
  //         print('📱 التطبيق في المقدمة');
  //         break;

  //       case AppLifecycleState.paused:
  //       case AppLifecycleState.inactive:
  //         _notificationService.updateAppState(false);
  //         print('📱 التطبيق في الخلفية');
  //         break;

  //       case AppLifecycleState.detached:
  //         print('📱 التطبيق مغلق');
  //         break;

  //       case AppLifecycleState.hidden:
  //         print('📱 التطبيق مخفي');
  //         _notificationService.updateAppState(false);
  //         break;
  //     }
  //   }
  // }

  // تغيير اللغة
  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();

          return MaterialApp(
            title: 'Jusoor App',
            locale: _locale,

            // 🌍 Localization
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],

            // ↔ RTL / LTR
            builder: (context, child) {
              return Directionality(
                textDirection: _locale?.languageCode == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              );
            },

            debugShowCheckedModeBanner: false,

            // 🎨 Theme (مربوط بالـ Provider)
            theme: AppTheme.lightTheme(),
darkTheme: AppTheme.darkTheme(),
themeMode: themeProvider.themeMode,

            initialRoute: '/login',

            // 🚀 Routes
            routes: {
              '/splash': (_) => SplashScreen(),
              '/signup': (_) => SignupScreen(),
              '/login': (_) => LoginScreen(),
              '/parentDashboard': (_) => ParentDashboardScreen(),
              '/parent-payment-dashboard': (_) => ParentPaymentDashboard(),
              '/profileSettings': (_) => ProfileSettingsScreen(),
              '/vacation': (_) => VacationRequestScreen(),
              '/forgotPassword': (_) => ForgotPasswordScreen(),
              '/specialistDashboard': (_) => SpecialistDashboardScreen(),
              '/managerDashboard': (_) => ManagerHomeScreen(),
              '/managerOnboarding': (_) => const ManagerOnboardingScreen(),
              '/donorDashboard': (_) => const DonorDashboardScreen(),
              '/adminDashboard': (_) => AdminDashboard(),
              '/publicInstitutions': (_) => const BrowseCentersScreen(),
              '/chats': (_) => ChatListScreen(),
              '/map': (_) => MapScreen(),
              '/financial-assistance': (_) => FinancialAssistanceDashboard(),
              '/institutionManagement': (_) => InstitutionManagement(),
              '/auditLogs': (_) => AuditLogs(),
              '/contentModeration': (_) => ContentModeration(),
              '/detailedStatistics': (_) => DetailedStatistics(),
              '/userManagement': (_) => UserManagement(),
              '/donationManagement': (_) => DonationManagement(),
              '/reportManagement': (_) => ReportManagement(),
              '/systemSettings': (_) => SystemSettings(),
              '/appContentManagement': (_) => AppContentManagement(),
              '/adminProfile': (_) => const ProfileScreen(),
              '/resetPassword': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map;
                return ResetPasswordScreen(
                  email: args['email'],
                  code: args['code'],
                );
              },

            },

            home: Builder(
        builder: (context) {
          return _MyAppInheritedWidget(
            appState: this,
            child: LoginScreen(),
          );
        },
      ),
          );
        },
      ),
    );
  }
}

class _MyAppInheritedWidget extends InheritedWidget {
  final _MyAppState appState;

  const _MyAppInheritedWidget({
    required this.appState,
    required Widget child,
  }) : super(child: child);

  static _MyAppInheritedWidget? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_MyAppInheritedWidget>();
  }

  @override
  bool updateShouldNotify(_MyAppInheritedWidget oldWidget) {
    return appState != oldWidget.appState;
  }
}