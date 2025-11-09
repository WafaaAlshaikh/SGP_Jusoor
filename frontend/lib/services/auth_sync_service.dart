// services/auth_sync_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSyncService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> syncCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 🔹 استخدام المفاتيح الصحيحة - هذه كانت المشكلة!
      final userEmail = prefs.getString('user_email');
      final userToken = prefs.getString('token'); // المفتاح الصحيح
      final userName = prefs.getString('user_name');
      final userRole = prefs.getString('user_role');
      final userId = prefs.getString('user_id');

      print('🔍 بيانات المزامنة:');
      print('📧 Email: $userEmail');
      print('🔐 Token: ${userToken != null ? 'موجود' : 'مفقود'}');
      print('👤 ID: $userId');
      print('🎯 Role: $userRole');

      if (userEmail == null || userId == null || userToken == null) {
        print('❌ لا توجد بيانات مستخدم محلية كافية للمزامنة');
        return;
      }

      print('🔄 مزامنة المستخدم الحقيقي: $userName ($userEmail)');

      final firebaseEmail = 'user_${userId}@jusoor.com';
      // ✅ استخدام password ثابت بدلاً من token المتغير
      final firebasePassword = 'jusoor_user_${userId}_fixed_password';

      try {
        await _auth.signInWithEmailAndPassword(
          email: firebaseEmail,
          password: firebasePassword,
        );
        print('✅ تم تسجيل الدخول إلى Firebase بالمستخدم الحقيقي');

      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          print('🔄 إنشاء حساب Firebase جديد أو تحديث كلمة المرور...');
          
          try {
            // محاولة إنشاء حساب جديد
            final userCredential = await _auth.createUserWithEmailAndPassword(
              email: firebaseEmail,
              password: firebasePassword,
            );

            if (userName != null) {
              await userCredential.user!.updateDisplayName(userName);
            }

            await prefs.setString('firebase_uid', userCredential.user!.uid);
            await prefs.setString('firebase_email', firebaseEmail);

            print('✅ تم إنشاء مستخدم حقيقي في Firebase: $userName');
          } catch (createError) {
            print('❌ خطأ في إنشاء الحساب: $createError');
          }
        } else {
          print('❌ خطأ في المصادقة: ${e.message}');
        }
      }

      final user = _auth.currentUser;
      if (user != null) {
        print('🎯 Firebase sync successful: ${user.uid}');
        print('📧 Firebase Email: ${user.email}');
        print('👤 Firebase Display Name: ${user.displayName}');
      }

    } catch (e) {
      print('❌ خطأ في مزامنة المستخدم الحقيقي: $e');
    }
  }

  // دالة احتياطية إذا فشلت المزامنة
  Future<void> _createFallbackUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fallbackEmail = 'user_${DateTime.now().millisecondsSinceEpoch}@jusoor.com';

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: fallbackEmail,
        password: 'fallback_password_${DateTime.now().millisecondsSinceEpoch}',
      );

      await prefs.setString('firebase_uid', userCredential.user!.uid);
      await prefs.setString('firebase_email', fallbackEmail);

      print('✅ تم إنشاء مستخدم احتياطي في Firebase');

    } catch (e) {
      print('❌ فشل إنشاء مستخدم احتياطي: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firebase_uid');
    await prefs.remove('firebase_email');
    print('✅ تم تسجيل الخروج من Firebase');
  }

  bool get isUserLoggedIn => _auth.currentUser != null;

  String? get currentUserId => _auth.currentUser?.uid;
}