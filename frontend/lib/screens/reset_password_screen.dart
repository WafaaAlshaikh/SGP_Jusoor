import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset Password')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Enter your new password'),
              SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(labelText: 'New Password'),
                obscureText: true,
                onChanged: (val) => newPassword = val,
                validator: (val) => val!.length < 6 ? 'Password too short' : null,
              ),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: isLoading ? null : resetPassword,
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Reset Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
