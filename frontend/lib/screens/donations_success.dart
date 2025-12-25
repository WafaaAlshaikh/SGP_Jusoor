// ملف donations_success.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/donation_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class DonationSuccessScreen extends StatefulWidget {
  final String? sessionId;
  final int? institutionId;

  const DonationSuccessScreen({
    super.key, 
    this.sessionId,
    this.institutionId,
  });

  @override
  State<DonationSuccessScreen> createState() => _DonationSuccessScreenState();
}

class _DonationSuccessScreenState extends State<DonationSuccessScreen> {
  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isFailed = false;
  String _statusMessage = 'Processing your donation...';
  Map<String, dynamic>? _donationDetails;
  Map<String, dynamic>? _institutionDetails;

  @override
  void initState() {
    super.initState();
    _processDonation();
  }

  Future<void> _processDonation() async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Verifying your payment...';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('Authentication required');
      }

      if (widget.sessionId == null) {
        throw Exception('Invalid donation session');
      }

      // 1. تأكيد الدفع
      _statusMessage = 'Confirming donation...';
      final result = await ApiService.confirmDonationFromStripe(
        token,
        sessionId: widget.sessionId!,
      );

      _donationDetails = result;

      // 2. الحصول على معلومات المؤسسة
      // if (widget.institutionId != null) {
      //   _institutionDetails = await ApiService.getInstitutionDetails(
      //     token,
      //     widget.institutionId!,
      //   );
      // }

      // 3. تحديث الحالة
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = 'Donation confirmed successfully!';
      });

      // 4. إرسال إشعار محلي
      _showLocalNotification();

    } catch (e) {
      print('Donation processing error: $e');
      
      setState(() {
        _isProcessing = false;
        _isFailed = true;
        _statusMessage = 'Failed to process donation: ${e.toString()}';
      });
    }
  }

  void _showLocalNotification() {
    // إضافة إشعار محلي
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🎉 Thank you for your generous donation!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Status'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return _buildProcessingView();
    } else if (_isSuccess) {
      return _buildSuccessView();
    } else if (_isFailed) {
      return _buildFailedView();
    } else {
      return _buildInitialView();
    }
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final donation = _donationDetails?['donation'] as Map<String, dynamic>?;
    final amount = donation?['amount'] ?? _donationDetails?['amount'] ?? 0;
    final institutionName = _institutionDetails?['name'] ?? 
                         donation?['institution']?['name'] ??
                         _donationDetails?['institution_name'] ?? 
                         'the institution';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // شعار النجاح
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // عنوان النجاح
            const Text(
              '🎉 Thank You!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // الرسالة
            Text(
              'Your generous donation of ${amount.toStringAsFixed(2)} JOD',
              style: const TextStyle(fontSize: 18),
            ),
            
            Text(
              'has been successfully sent to $institutionName.',
              style: const TextStyle(fontSize: 18),
            ),
            
            const SizedBox(height: 32),
            
            // تفاصيل التبرع
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Donation Receipt',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildReceiptItem('Donation ID', '#${donation?['donation_id'] ?? _donationDetails?['donation_id']}'),
                    _buildReceiptItem('Amount', '${amount.toStringAsFixed(2)} JOD'),
                    _buildReceiptItem('Date', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
                    _buildReceiptItem('Payment Method', donation?['payment_method'] ?? _donationDetails?['payment_method'] ?? 'Card'),
                    if (donation?['receipt_url'] != null || _donationDetails?['receipt_url'] != null)
                      _buildReceiptItem('Receipt', 'Available online'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // أزرار الإجراء
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Return Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DonationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.favorite),
                  label: const Text('Make Another Donation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                if (_donationDetails?['receipt_url'] != null)
                  TextButton.icon(
                    onPressed: () {
                      // فتح رابط الإيصال
                    },
                    icon: const Icon(Icons.receipt),
                    label: const Text('View Receipt'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Donation Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _processDonation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Initializing donation verification...'),
        ],
      ),
    );
  }
}