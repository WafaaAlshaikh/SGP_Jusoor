import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/auth_sync_service.dart';
import 'forgot_password_screen.dart';
import '../theme/app_colors.dart';

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

  Future<void> _registerDeviceToken(String authToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = (prefs.getString('fcm_token') ?? '').trim();
      if (fcmToken.isEmpty) return;

      final baseUrl = kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';
      await http.post(
        Uri.parse('$baseUrl/device-tokens/register'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': fcmToken,
          'platform': kIsWeb ? 'web' : 'mobile',
        }),
      );
    } catch (_) {}
  }

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

      await _registerDeviceToken(response['token']);

      if (response['user']['role'] == 'Manager' && response['institution'] != null) {
        await prefs.setString('institution_data', jsonEncode(response['institution']));
      }

      try {
        final authSync = AuthSyncService();
        await authSync.syncCurrentUser();
      } catch (e) {
        print('❌ خطأ في مزامنة Firebase: $e');
      }

      final role = response['user']['role'];
      if (role == 'Parent') {
        Navigator.pushReplacementNamed(context, '/parentDashboard');
      } else if (role == 'Donor') {
        Navigator.pushReplacementNamed(context, '/donorDashboard');
      } else if (role == 'Specialist') {
        Navigator.pushReplacementNamed(context, '/specialistDashboard');
      } else if (role == 'Admin') {
        Navigator.pushReplacementNamed(context, '/adminDashboard');
      } else if (role == 'Manager') {
        Navigator.pushReplacementNamed(context, '/managerDashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Container(
            width: isWeb ? 500 : double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isWeb ? 40 : 30,
              vertical: isWeb ? 20 : 40,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header with Logo and Welcome
                  Container(
                    margin: EdgeInsets.only(bottom: isWeb ? 40 : 30),
                    child: Column(
                      children: [
                        // Simple elegant logo - Bridge concept
                        Container(
                          width: isWeb ? 160 : 140,  
                          height: isWeb ? 160 : 140, 
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background glow effect
                              Container(
                                width: isWeb ? 150 : 130,
                                height: isWeb ? 150 : 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.1),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),

                              // Main logo - Three connected elements
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Top - Family icon
                                  Icon(
                                    Icons.groups,
                                    color: AppColors.primary,
                                    size: isWeb ? 45 : 39,  
                                  ),

                                  SizedBox(height: isWeb ? 12 : 5),

                                  // Middle - Connection symbol with full width lines
                                  Container(
                                    width: double.infinity, 
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                      children: [
                                        // Left line - extends to edge
                                        Expanded(
                                          child: Container(
                                            height: 3,  
                                            margin: EdgeInsets.only(right: isWeb ? 15 : 10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.primary.withOpacity(0.3),
                                                  AppColors.primary,
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),

                                        // Heart in the middle
                                        Container(
                                          width: isWeb ? 40 : 35,
                                          height: isWeb ? 40 : 35,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.favorite,
                                            color: Colors.white,
                                            size: isWeb ? 25 : 22,
                                          ),
                                        ),

                                        // Right line - extends to edge
                                        Expanded(
                                          child: Container(
                                            height: 3,  
                                            margin: EdgeInsets.only(left: isWeb ? 15 : 10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.primary,
                                                  AppColors.primary.withOpacity(0.3),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),




                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: isWeb ? 32 : 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Sign in to continue your journey',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 14,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Login Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isWeb ? 40 : 30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Field
                          _buildTextField(
                            label: 'Email Address',
                            hintText: 'your@email.com',
                            icon: Icons.email_outlined,
                            isWeb: isWeb,
                            onChanged: (val) => email = val,
                            validator: (val) => val!.isEmpty ? 'Please enter your email' : null,
                          ),
                          SizedBox(height: isWeb ? 25 : 20),

                          // Password Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isWeb ? 16 : 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: TextStyle(color: AppColors.textLight),
                                  filled: true,
                                  fillColor: AppColors.card,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: isWeb ? 20 : 16,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: AppColors.primary,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showPassword ? Icons.visibility_off : Icons.visibility,
                                      color: AppColors.primary,
                                    ),
                                    onPressed: () => setState(() => showPassword = !showPassword),
                                  ),
                                ),
                                obscureText: !showPassword,
                                onChanged: (val) => password = val,
                                validator: (val) => val!.isEmpty ? 'Please enter your password' : null,
                              ),
                            ],
                          ),
                          SizedBox(height: 10),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: isWeb ? 14 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isWeb ? 30 : 25),

                          // Login Button
                          Container(
                            width: double.infinity,
                            height: isWeb ? 60 : 55,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
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
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: isWeb ? 18 : 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward, size: isWeb ? 20 : 18, color: Colors.white),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: isWeb ? 30 : 25),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/publicInstitutions');
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: EdgeInsets.symmetric(vertical: isWeb ? 18 : 16),
                              ),
                              icon: Icon(Icons.explore, color: AppColors.primaryDark),
                              label: Text(
                                'Continue as Guest',
                                style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: isWeb ? 16 : 14,
                                ),
                              ),
                            ),
                          ),

                          // Sign Up Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: isWeb ? 14 : 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(context, '/signup');
                                },
                                child: Text(
                                  'Create Account',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: isWeb ? 14 : 12,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom decorative element with app purpose
                  SizedBox(height: isWeb ? 40 : 30),
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required IconData icon,
    required bool isWeb,
    required Function(String) onChanged,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isWeb ? 16 : 14,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.textLight),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isWeb ? 20 : 16,
            ),
            prefixIcon: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}