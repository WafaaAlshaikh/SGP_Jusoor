// ملف donations_success.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/donation_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class DonationSuccessScreen extends StatefulWidget {
  final String? sessionId;
  final int? institutionId;
  final bool isAnonymous; 

  const DonationSuccessScreen({
    super.key,
    this.sessionId,
    this.institutionId,
    this.isAnonymous = false,
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

      // 1. التحقق من حالة التبرع
      _statusMessage = 'Checking donation status...';
      final statusResult = await ApiService.checkDonationStatusBySession(
        token,
        sessionId: widget.sessionId!,
      );

      if (statusResult['success'] == true &&
          statusResult['donation']?['status'] == 'completed') {
        _donationDetails = statusResult;
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Donation already confirmed!';
        });
        return;
      }

      // 2. تأكيد التبرع
      _statusMessage = 'Confirming donation...';
      final confirmResult = await ApiService.confirmDonationFromStripe(
        token,
        sessionId: widget.sessionId!,
      );

      _donationDetails = confirmResult;

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = 'Donation confirmed successfully!';
      });

      _showLocalNotification();
    } catch (e) {
      print('Donation processing error: $e');

      setState(() {
        _isProcessing = false;
        _isFailed = true;
        _statusMessage = _getErrorMessage(e);
      });
    }
  }

  String _getErrorMessage(Object e) {
    final errorStr = e.toString();

    if (errorStr.contains('404')) {
      return 'Donation not found. It may have expired or been cancelled.';
    } else if (errorStr.contains('401')) {
      return 'Authentication failed. Please login again.';
    } else if (errorStr.contains('Network')) {
      return 'Network error. Please check your connection.';
    } else if (errorStr.contains('Payment not completed')) {
      return 'Payment not completed yet. Please check your payment status.';
    } else {
      return 'Failed to process donation: ${e.toString()}';
    }
  }

  void _showLocalNotification() {
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
  // الحصول على amount وتحويله إلى double
  final dynamic amountData = _donationDetails?['donation']?['amount'] ?? 
                           _donationDetails?['amount'] ?? 0;
  
  // تحويل amount إلى double
  double amount;
  if (amountData is String) {
    amount = double.tryParse(amountData) ?? 0.0;
  } else if (amountData is int) {
    amount = amountData.toDouble();
  } else if (amountData is double) {
    amount = amountData;
  } else {
    amount = 0.0;
  }
  
  // الحصول على institutionName
  final dynamic institutionData = _institutionDetails?['name'] ?? 
                                _donationDetails?['donation']?['institution']?['name'] ??
                                _donationDetails?['institution_name'] ?? 
                                'the institution';
  
  final String institutionName = institutionData is String ? institutionData : 'the institution';
  
  // الحصول على donation object
  final Map<String, dynamic>? donation = _donationDetails?['donation'] is Map<String, dynamic> 
      ? _donationDetails!['donation'] as Map<String, dynamic>
      : null;

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
          
          // ✅ عنوان مختلف للمتبرعين المجهولين
          if (widget.isAnonymous) ...[
            const Text(
              '🎉 Thank You, Anonymous Donor!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your generosity speaks louder than any name.',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const Text(
              '🎉 Thank You!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // الرسالة
          Text(
            'Your generous donation of ${amount.toStringAsFixed(2)} JOD',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'has been successfully sent to $institutionName.',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          
          // ✅ رسالة إضافية للمتبرعين المجهولين
          if (widget.isAnonymous) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_off, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your donation is recorded anonymously. '
                      'No personal information is linked to this contribution.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
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
                  
                  // ✅ عرض حالة التبرع المجهول
                  _buildReceiptItem(
                    'Donation Type', 
                    widget.isAnonymous ? 'Anonymous Donation' : 'Regular Donation'
                  ),
                  
                  // Donation ID
                  if (donation?['donation_id'] != null)
                    _buildReceiptItem(
                      'Donation ID', 
                      '#${donation!['donation_id']}'
                    ),
                  
                  // Amount
                  _buildReceiptItem(
                    'Amount', 
                    '${amount.toStringAsFixed(2)} JOD'
                  ),
                  // Date
                  _buildReceiptItem(
                    'Date', 
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())
                  ),
                  
                  // Payment Status
                  if (donation?['payment_status'] != null)
                    _buildReceiptItem(
                      'Payment Status', 
                      '${donation!['payment_status']}'.toUpperCase()
                    ),
                  
                  // Payment Method
                  if (donation?['payment_method'] != null)
                    _buildReceiptItem(
                      'Payment Method', 
                      '${donation!['payment_method']}'
                    ),
                  
                  // Receipt URL
                  if (_donationDetails?['receipt_url'] != null)
                    _buildReceiptItem(
                      'Receipt', 
                      'Available online'
                    ),
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
              
              // زر فتح الإيصال إذا كان متاحاً
              if (_donationDetails?['receipt_url'] != null || 
                  donation?['receipt_url'] != null)
                TextButton.icon(
                  onPressed: () {
                    final receiptUrl = _donationDetails?['receipt_url'] ?? 
                                     donation?['receipt_url'];
                    if (receiptUrl != null) {
                      launchUrl(Uri.parse(receiptUrl.toString()));
                    }
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
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFailedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 80, color: Colors.red),
            const SizedBox(height: 24),
            const Text('Donation Failed',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red)),
            const SizedBox(height: 16),
            Text(_statusMessage,
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _processDonation,
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
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
              'Initializing donation verification...'),
        ],
      ),
    );
  }
}
