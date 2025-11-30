import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String code;

  ResetPasswordScreen({required this.email, required this.code});

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String newPassword = '';
  bool isLoading = false;
  bool showPassword = false;

  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      final response = await ApiService.resetPassword(widget.email, widget.code, newPassword);
      print('Reset password response: $response');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Unknown response'),
          backgroundColor: response['success'] == true ? Colors.green : Colors.red,
        ),
      );

      if (response['success'] == true) {
        Future.delayed(Duration(milliseconds: 1500), () {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
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
                  // Header Section
                  Container(
                    margin: EdgeInsets.only(bottom: isWeb ? 40 : 30),
                    child: Column(
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: isWeb ? 80 : 70,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Create New Password',
                          style: TextStyle(
                            fontSize: isWeb ? 32 : 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter a strong password to secure your account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 14,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reset Password Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 25,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isWeb ? 35 : 25),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Display (Read-only)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: isWeb ? 14 : 12,
                                    color: AppColors.textGray,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  widget.email,
                                  style: TextStyle(
                                    fontSize: isWeb ? 16 : 14,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isWeb ? 25 : 20),

                          // New Password Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Password',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isWeb ? 16 : 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                decoration: InputDecoration(
                                  hintText: 'Enter your new password',
                                  hintStyle: TextStyle(color: AppColors.textGray),
                                  filled: true,
                                  fillColor: AppColors.backgroundColor.withOpacity(0.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: isWeb ? 16 : 14,
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
                                onChanged: (val) => newPassword = val,
                                validator: (val) {
                                  if (val!.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (val.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: AppColors.textGray),
                                  SizedBox(width: 4),
                                  Text(
                                    'Use at least 6 characters for security',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: isWeb ? 30 : 25),

                          // Reset Password Button
                          Container(
                            width: double.infinity,
                            height: isWeb ? 55 : 50,
                            decoration: BoxDecoration(
                              color: AppColors.buttonColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.buttonColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isLoading ? null : resetPassword,
                              child: isLoading
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white),
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_reset_rounded,
                                    color: Colors.white,
                                    size: isWeb ? 20 : 18,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Reset Password',
                                    style: TextStyle(
                                      fontSize: isWeb ? 16 : 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: isWeb ? 20 : 16),

                          // Back to Login
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Remember your password? ",
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: isWeb ? 14 : 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                },
                                child: Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: AppColors.buttonColor,
                                    fontSize: isWeb ? 14 : 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom decorative element
                  SizedBox(height: isWeb ? 40 : 30),
                  Container(
                    width: 100,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.buttonColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}