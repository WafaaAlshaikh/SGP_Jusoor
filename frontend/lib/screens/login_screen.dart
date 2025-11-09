import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_sync_service.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool isLoading = false;
  bool showPassword = false;

  // دالة submit كما هي بدون تغيير
  void submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    final response = await ApiService.login({'email': email.trim(), 'password': password});
    setState(() => isLoading = false);

    final message = response['message'] ?? 'Unknown error';
    final success = response['token'] != null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', response['token']);
      await prefs.setString('user_id', response['user']['user_id'].toString());
      await prefs.setString('user_email', response['user']['email']);
      await prefs.setString('user_name', response['user']['full_name']);
      await prefs.setString('user_role', response['user']['role']);

      print('✅ تم حفظ بيانات المستخدم في التخزين المحلي');
      print('📝 Token: ${response['token']}');
      print('👤 User ID: ${response['user']['user_id']}');
      print('🎯 Role: ${response['user']['role']}');

      try {
        final authSync = AuthSyncService();
        await authSync.syncCurrentUser();
        print('✅ تمت مزامنة Firebase بنجاح');
      } catch (e) {
        print('❌ خطأ في مزامنة Firebase: $e');
      }

      final role = response['user']['role'];
      if (role == 'Parent') {
        Navigator.pushReplacementNamed(context, '/parentDashboard');
      } else if (role == 'Specialist') {
        Navigator.pushReplacementNamed(context, '/specialistDashboard');
      } else if (role == 'Admin') {
        Navigator.pushReplacementNamed(context, '/adminDashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // تحديد إذا كان التطبيق يعمل على الويب
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Color(0xFFF0E5FF),
      body: SafeArea(
        child: Center(
          child: Container(
            // تحديد عرض الحاوية بناءً على المنصة
            width: isWeb ? 500 : double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 40 : 30,
                vertical: isWeb ? 20 : 40
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tabs: Login / Signup
                    Container(
                      decoration: isWeb ? BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          )
                        ],
                      ) : null,
                      padding: isWeb ? EdgeInsets.all(20) : EdgeInsets.zero,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  'Log in',
                                  style: TextStyle(
                                    fontSize: isWeb ? 22 : 20,
                                    color: Color(0xFF8E88C7),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              SizedBox(width: 20),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(context, '/signup');
                                },
                                child: Text(
                                  'Sign up',
                                  style: TextStyle(
                                    fontSize: isWeb ? 22 : 20,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 30 : 20),

                          // Logo
                          Image.asset(
                            'assets/images/jusoor_logo.png',
                            height: isWeb ? 120 : 100,
                          ),
                          SizedBox(height: isWeb ? 30 : 20),

                          // Email
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Your Email',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: isWeb ? 18 : 16,
                                color: Color(0xFF7815A0),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            decoration: InputDecoration(
                              hintText: 'contact@dscodetech.com',
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Color(0xFF7815A0), width: 1.2),
                              ),
                              contentPadding: isWeb
                                  ? EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                                  : null,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (val) => email = val,
                            validator: (val) =>
                            val!.isEmpty ? 'Please enter your email' : null,
                          ),
                          SizedBox(height: isWeb ? 25 : 20),

                          // Password
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: isWeb ? 18 : 16,
                                color: Color(0xFF7815A0),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Color(0xFF7815A0), width: 1.2),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => showPassword = !showPassword),
                                color: Color(0xFF7815A0),
                              ),
                              contentPadding: isWeb
                                  ? EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                                  : null,
                            ),
                            obscureText: !showPassword,
                            onChanged: (val) => password = val,
                            validator: (val) =>
                            val!.isEmpty ? 'Please enter your password' : null,
                          ),
                          SizedBox(height: 10),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => ForgotPasswordScreen()),
                                );
                              },
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: Color(0xFF7815A0),
                                  fontSize: isWeb ? 16 : null,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isWeb ? 30 : 20),

                          // Continue Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: isWeb ? 18 : 16),
                                backgroundColor: Color(0xFF7815A0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isLoading ? null : submit,
                              child: isLoading
                                  ? SizedBox(
                                height: isWeb ? 24 : 20,
                                width: isWeb ? 24 : 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : Text(
                                'Continue',
                                style: TextStyle(
                                    fontSize: isWeb ? 20 : 18,
                                    color: Colors.white
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isWeb ? 25 : 20),

                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('Or',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: isWeb ? 16 : null,
                                    )),
                              ),
                              Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                            ],
                          ),
                          SizedBox(height: isWeb ? 25 : 20),

                          // Login with Apple
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: isWeb ? 16 : 14),
                                side: BorderSide(color: Color(0xFF7815A0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.apple,
                                color: Color(0xFF7815A0),
                                size: isWeb ? 24 : null,
                              ),
                              label: Text(
                                  'Login with Apple',
                                  style: TextStyle(
                                    color: Color(0xFF7815A0),
                                    fontSize: isWeb ? 18 : null,
                                  )
                              ),
                              onPressed: () {},
                            ),
                          ),
                          SizedBox(height: 10),

                          // Login with Google
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: isWeb ? 16 : 14),
                                side: BorderSide(color: Color(0xFF7815A0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Image.asset(
                                'assets/images/jusoor_logo.png',
                                height: isWeb ? 24 : 20,
                              ),
                              label: Text(
                                  'Login with Google',
                                  style: TextStyle(
                                    color: Color(0xFF7815A0),
                                    fontSize: isWeb ? 18 : null,
                                  )
                              ),
                              onPressed: () {},
                            ),
                          ),

                          SizedBox(height: isWeb ? 20 : 10),

                          // Signup link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: isWeb ? 16 : null,
                                  )
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(context, '/signup');
                                },
                                child: Text(
                                    'Sign up',
                                    style: TextStyle(
                                      color: Color(0xFF7815A0),
                                      fontSize: isWeb ? 16 : null,
                                    )
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}