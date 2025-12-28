import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/donations_success.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/screens/stripe_checkout_screen.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class QuickDonationScreen extends StatefulWidget {
  final int institutionId;
  final String institutionName;
  
  const QuickDonationScreen({
    super.key,
    required this.institutionId,
    required this.institutionName,
  });

  @override
  State<QuickDonationScreen> createState() => _QuickDonationScreenState();
}

class _QuickDonationScreenState extends State<QuickDonationScreen> {
  bool _isLoading = false;
  String _selectedAmount = '50';
  final List<String> _amounts = ['10', '25', '50', '100', '250', '500'];
  bool _isAnonymous = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  Future<void> _processDonation() async {
    try {
      setState(() => _isLoading = true);
      
      final amount = double.parse(_selectedAmount);
      
      Map<String, dynamic> requestBody = {
        'institution_id': widget.institutionId,
        'amount': amount,
        'anonymous': _isAnonymous,
      };
      
      // إضافة بيانات المتبرع إذا لم يكن مجهولاً
      if (!_isAnonymous) {
        if (_nameController.text.isNotEmpty) {
          requestBody['donor_name'] = _nameController.text;
        }
        if (_emailController.text.isNotEmpty) {
          requestBody['donor_email'] = _emailController.text;
        }
      }
      
      // استخدام API مرن (لا يحتاج token)
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/donations/flexible/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        final url = result['url']?.toString();
        final sessionId = result['sessionId']?.toString();
        
        if (url != null && url.isNotEmpty) {
          final completed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => StripeCheckoutScreen(
                checkoutUrl: url,
                sessionId: sessionId,
                institutionId: widget.institutionId,
                institutionName: widget.institutionName,
                amount: amount,
              ),
            ),
          ) ?? false;
          
          if (completed && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DonationSuccessScreen(
                  sessionId: sessionId,
                  institutionId: widget.institutionId,
                  isAnonymous: _isAnonymous,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Donate to ${widget.institutionName}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Text(
              'Quick Donation',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Support ${widget.institutionName} with a quick donation',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // اختيار المبلغ
            Text(
              'Select Amount (JOD)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _amounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return ChoiceChip(
                  label: Text('$amount JOD'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedAmount = amount);
                    }
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // خيار التبرع المجهول
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Donate Anonymously'),
                      subtitle: const Text('Your name will not be displayed'),
                      value: _isAnonymous,
                      onChanged: (value) {
                        setState(() => _isAnonymous = value);
                      },
                    ),
                    
                    if (!_isAnonymous) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name (Optional)',
                          hintText: 'John Doe',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Your Email (Optional)',
                          hintText: 'email@example.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // زر التبرع
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _processDonation,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite),
                label: Text(
                  _isLoading 
                      ? 'Processing...' 
                      : 'Donate ${_selectedAmount} JOD',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // ملاحظة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isAnonymous
                          ? 'No login required. Payment processed securely via Stripe.'
                          : 'Your information is kept private and secure.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}