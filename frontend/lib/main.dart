import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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


// 📌 دالة استقبال الإشعارات بالخلفية
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
    print("📋 Background message received: ${message.messageId}");
    await CompleteNotificationService.handleBackgroundMessage(message);
  }
}


// 📌 MAIN
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // اللغة
  final locale = await LanguageService.getLocale();

  print('🚀 بدء تشغيل تطبيق Jusoor...');

  // 🔥 Firebase
  if (kIsWeb) {
    await Firebase.initializeApp(options: firebaseWebOptions);
  } else {
    await Firebase.initializeApp();
  }

  // المزامنة مع Firebase
  await _syncUserWithFirebase();

  // 🔥 الإشعارات (موبايل فقط)
  if (!kIsWeb) {
    try {
      await CompleteNotificationService().initializeCompleteNotifications();
      print('✅ النظام الكامل للإشعارات جاهز');
    } catch (e) {
      print('⚠️ استخدام النظام القديم للإشعارات بسبب: $e');
      await initializeNotifications();
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    String? token = await FirebaseMessaging.instance.getToken();
    print("📱 Device Token: $token");
  } else {
    print('🌐 تشغيل على الويب - الإشعارات محدودة');
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      print("🌐 Web Token: $token");
    } catch (e) {
      print('⚠️ لا يمكن الحصول على token للويب: $e');
    }
  }

  runApp(MyApp(locale: locale));
}


// 📌 دالة المزامنة مع Firebase
Future<void> _syncUserWithFirebase() async {
  try {
    final authSync = AuthSyncService();
    await authSync.syncCurrentUser();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('🎯 Firebase sync successful: ${user.uid}');
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
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb) {
      switch (state) {
        case AppLifecycleState.resumed:
          _notificationService.updateAppState(true);
          print('📱 التطبيق في المقدمة');
          break;

        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          _notificationService.updateAppState(false);
          print('📱 التطبيق في الخلفية');
          break;

        case AppLifecycleState.detached:
          print('📱 التطبيق مغلق');
          break;

        case AppLifecycleState.hidden:
          print('📱 التطبيق مخفي');
          _notificationService.updateAppState(false);
          break;
      }
    }
  }


  // تغيير اللغة
  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jusoor App',
      locale: _locale,

      // اللغات
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', ''),
      ],

      // RTL / LTR
      builder: (context, child) {
        return Directionality(
          textDirection:
              _locale?.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },

      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),

      initialRoute: '/splash',

      // 🚀 جميع الـ Routes (دمج كامل)
      routes: {
        '/splash': (context) => SplashScreen(),
        '/signup': (context) => SignupScreen(),
        '/login': (context) => LoginScreen(),
        '/parentDashboard': (context) => ParentDashboardScreen(),
        '/parent-payment-dashboard': (context) => ParentPaymentDashboard(),
        '/profileSettings': (context) => ProfileSettingsScreen(),
        '/vacation': (context) => VacationRequestScreen(),
        '/forgotPassword': (context) => ForgotPasswordScreen(),
        '/specialistDashboard': (context) => SpecialistDashboardScreen(),
        '/chats': (context) => ChatListScreen(),
        '/map': (context) => MapScreen(),

        // Reset Password using arguments
        '/resetPassword': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return ResetPasswordScreen(
            email: args['email'],
            code: args['code'],
          );
        },
      },
    );
  }
}
