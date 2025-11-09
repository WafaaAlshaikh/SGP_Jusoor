// forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
        SnackBar(content: Text('Please enter your email'), backgroundColor: Colors.red),
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
            content: Text(response['message'] ?? 'Code sent'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() => codeSent = true);

        // التركيز التلقائي على الكود بعد ظهوره
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
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        SnackBar(content: Text('Please enter the code'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiService.verifyResetCode(email, code);
      print('Verify code response: $response');

      if (response is Map<String, dynamic>) {
        final message = response['message'] ?? '';
        final success = message.toLowerCase().contains('verified'); // أي رد يحتوي على كلمة verified يعتبر نجاح

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
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
    return Scaffold(
      appBar: AppBar(title: Text('Forgot Password')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Enter your email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 20),
            if (codeSent)
              TextField(
                controller: _codeController,
                focusNode: _codeFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Enter code sent to your email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : codeSent
                    ? verifyCode
                    : sendCode,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                  codeSent ? 'Verify Code' : 'Send Code',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
