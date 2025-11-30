import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  bool codeSent = false;
  bool isLoading = false;

  Future<void> sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiService.sendResetCode(email);
      print('Send code response: $response');

      if (response is Map<String, dynamic>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Verification code sent to your email'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() => codeSent = true);

        Future.delayed(Duration(milliseconds: 100), () {
          FocusScope.of(context).requestFocus(_codeFocusNode);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server returned invalid response'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error sending code: $e');
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

  Future<void> verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiService.verifyResetCode(email, code);
      print('Verify code response: $response');

      if (response is Map<String, dynamic>) {
        final message = response['message'] ?? '';
        final success = message.toLowerCase().contains('verified');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          Future.delayed(Duration(milliseconds: 100), () {
            Navigator.pushNamed(
              context,
              '/resetPassword',
              arguments: {
                'email': email,
                'code': code,
              },
            );
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server returned invalid response'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error verifying code: $e');
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
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
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
                          Icons.lock_reset_rounded,
                          size: isWeb ? 80 : 70,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: isWeb ? 32 : 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          codeSent
                              ? 'Enter the verification code sent to your email'
                              : 'Enter your email to reset your password',
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

                  // Form Card
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
                    child: Column(
                      children: [
                        // Email Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email Address',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isWeb ? 16 : 14,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'your@email.com',
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
                                  Icons.email_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isWeb ? 25 : 20),

                        // Code Field (ظهر فقط بعد إرسال الكود)
                        if (codeSent)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verification Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isWeb ? 16 : 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _codeController,
                                focusNode: _codeFocusNode,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: 'Enter 6-digit code',
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
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: AppColors.textGray),
                                  SizedBox(width: 4),
                                  Text(
                                    'Check your email for the verification code',
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

                        // Action Button
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
                            onPressed: isLoading ? null : codeSent ? verifyCode : sendCode,
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
                                  codeSent ? Icons.verified_outlined : Icons.send_outlined,
                                  color: Colors.white,
                                  size: isWeb ? 20 : 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  codeSent ? 'Verify Code' : 'Send Code',
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