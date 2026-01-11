import 'package:flutter/material.dart';
import 'package:frontend/screens/donation_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class DonationSuccessScreen extends StatefulWidget {
  final String? sessionId;
  final int? donationId;
  final int? institutionId;
  final bool isAnonymous;
  final double amount;

  const DonationSuccessScreen({
    super.key,
    this.sessionId,
    this.donationId,
    this.institutionId,
    this.isAnonymous = false,
    this.amount = 0.0,
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
    print('🎉 Success screen initialized:');
    print('   Session ID: ${widget.sessionId}');
    print('   Donation ID: ${widget.donationId}');
    print('   Institution ID: ${widget.institutionId}');
    print('   Is Anonymous: ${widget.isAnonymous}');

    // إذا كان عندنا donationId من Mobile، نستخدمه مباشرة
    if (widget.donationId != null) {
      _processMobileDonation();
    } else if (widget.sessionId != null) {
      _processWebDonation();
    } else {
      setState(() {
        _isFailed = true;
        _statusMessage = 'No donation information provided';
      });
    }
  }

  // ✅ للـ Mobile: نستخدم donationId مباشرة
  Future<void> _processMobileDonation() async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Verifying your payment...';
      });

      // محاكاة تأخير بسيط للـ UI
      await Future.delayed(const Duration(milliseconds: 500));

      // الدفع نجح بالفعل في Stripe
      // فقط نعرض رسالة النجاح
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = 'Donation confirmed successfully!';
        _donationDetails = {
          'donation': {
            'donation_id': widget.donationId,
            'status': 'completed',
            'payment_status': 'paid',
          }
        };
      });

      _showLocalNotification();
    } catch (e) {
      print('❌ Mobile donation processing error: $e');
      setState(() {
        _isProcessing = false;
        _isFailed = true;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  // ✅ للـ Web: نستخدم sessionId
  Future<void> _processWebDonation() async {
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
      setState(() {
        _statusMessage = 'Checking donation status...';
      });

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
      setState(() {
        _statusMessage = 'Confirming donation...';
      });

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
      print('❌ Web donation processing error: $e');

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
    if (!mounted) return;

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
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    // الحصول على amount وتحويله إلى double
    final dynamic amountData = _donationDetails?['donation']?['amount'] ??
        _donationDetails?['amount'] ??
        0;

    // تحويل amount إلى double
     double amount = widget.amount;
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

    final String institutionName =
        institutionData is String ? institutionData : 'the institution';

    // الحصول على donation object
    final Map<String, dynamic>? donation =
        _donationDetails?['donation'] is Map<String, dynamic>
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
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
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

            const SizedBox(height: 24),

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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility_off, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your donation is recorded anonymously. '
                        'No personal information is linked to this contribution.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          height: 1.4,
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Donation Receipt',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ✅ عرض حالة التبرع المجهول
                    _buildReceiptItem(
                      'Donation Type',
                      widget.isAnonymous
                          ? 'Anonymous Donation'
                          : 'Regular Donation',
                    ),

                    // Donation ID
                    if (donation?['donation_id'] != null)
                      _buildReceiptItem(
                        'Donation ID',
                        '#${donation!['donation_id']}',
                      ),

                    // Amount
                    _buildReceiptItem(
                      'Amount',
                      '${amount.toStringAsFixed(2)} JOD',
                    ),

                    // Date
                    _buildReceiptItem(
                      'Date',
                      DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    ),

                    // Payment Status
                    if (donation?['payment_status'] != null)
                      _buildReceiptItem(
                        'Payment Status',
                        '${donation!['payment_status']}'.toUpperCase(),
                      ),

                    // Payment Method
                    if (donation?['payment_method'] != null)
                      _buildReceiptItem(
                        'Payment Method',
                        '${donation!['payment_method']}',
                      ),

                    // Receipt URL
                    if (_donationDetails?['receipt_url'] != null)
                      _buildReceiptItem(
                        'Receipt',
                        'Available online',
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // أزرار الإجراء
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home, size: 22),
                    label: const Text(
                      'Return Home',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DonationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite, size: 22),
                    label: const Text(
                      'Make Another Donation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                    icon: const Icon(Icons.receipt, size: 20),
                    label: const Text('View Receipt'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Donation Failed',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // إعادة المحاولة
                      if (widget.donationId != null) {
                        _processMobileDonation();
                      } else if (widget.sessionId != null) {
                        _processWebDonation();
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Initializing donation verification...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}