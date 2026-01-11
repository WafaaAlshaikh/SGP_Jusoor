import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class StripePaymentScreen extends StatefulWidget {
  final int institutionId;
  final String institutionName;
  final double amount;
  final int? campaignId;
  final String donationMode;
  final bool isAnonymous;
  final String? donorName;
  final String? donorEmail;
  final String? inviteCode;

  const StripePaymentScreen({
    super.key,
    required this.institutionId,
    required this.institutionName,
    required this.amount,
    this.campaignId,
    this.donationMode = 'one_time',
    this.isAnonymous = false,
    this.donorName,
    this.donorEmail,
    this.inviteCode,
  });

  @override
  State<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends State<StripePaymentScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _clientSecret;
  int? _donationId;

  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  Future<void> _initPayment() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    print('🔄 Initializing payment...');
    
    // 1️⃣ إنشاء Payment Intent من Backend
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    print('📱 Calling API...');
    
    final paymentData = await ApiService.createMobileDonationPayment(
      token: token,
      institutionId: widget.institutionId,
      amount: widget.amount,
      campaignId: widget.campaignId,
      mode: widget.donationMode,
      anonymous: widget.isAnonymous,
      donorName: widget.donorName,
      donorEmail: widget.donorEmail,
      inviteCode: widget.inviteCode,
    );

    print('✅ Payment data received:');
    print('   Keys: ${paymentData.keys}');
    
    _clientSecret = paymentData['payment_intent_client_secret'] as String?;
    _donationId = paymentData['donation_id'] as int?;

    print('🔑 Client Secret: ${_clientSecret?.substring(0, 20)}...');
    print('🆔 Donation ID: $_donationId');

    if (_clientSecret == null || _clientSecret!.isEmpty) {
      print('❌ No client secret in response');
      print('Full response: $paymentData');
      throw Exception('No payment client secret received from server');
    }

    // 2️⃣ تهيئة Payment Sheet
    print('🔧 Initializing Stripe Payment Sheet...');
    
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: _clientSecret!,
        merchantDisplayName: widget.institutionName,
        style: ThemeMode.light,
        billingDetails: widget.isAnonymous
            ? null
            : BillingDetails(
                name: widget.donorName,
                email: widget.donorEmail,
              ),
        appearance: PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            primary: AppColors.primary,
          ),
          shapes: PaymentSheetShape(
            borderRadius: 12,
          ),
        ),
      ),
    );

    print('✅ Payment Sheet initialized successfully');

    setState(() {
      _isLoading = false;
    });

    // 3️⃣ عرض Payment Sheet مباشرة
    await _presentPaymentSheet();

  } catch (e) {
    print('❌ Payment initialization error: $e');
    print('Stack trace: ${StackTrace.current}');
    
    setState(() {
      _isLoading = false;
      _errorMessage = _formatError(e.toString());
    });
  }
}

  Future<void> _presentPaymentSheet() async {
    try {
      // عرض Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // ✅ نجح الدفع!
      if (!mounted) return;

      // تأكيد الدفع في Backend
      await _confirmPaymentWithBackend();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Payment completed successfully!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // العودة للشاشة السابقة مع نتيجة النجاح
      Navigator.pop(context, {
        'success': true,
        'donation_id': _donationId,
        'session_id': _donationId?.toString(), 
      });

    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        // المستخدم ألغى
        if (mounted) {
          Navigator.pop(context, {'success': false, 'cancelled': true});
        }
      } else {
        setState(() {
          _errorMessage = e.error.localizedMessage ?? 'Payment failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  Future<void> _confirmPaymentWithBackend() async {
    try {
      if (_clientSecret == null) return;

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      await ApiService.confirmDonationPayment(
        token: token,
        paymentIntentId: _extractPaymentIntentId(_clientSecret!),
        donationId: _donationId,
      );
    } catch (e) {
      print('⚠️ Backend confirmation error: $e');
      // لا نعرض خطأ للمستخدم لأن الدفع نجح في Stripe
    }
  }

  String _extractPaymentIntentId(String clientSecret) {
    // client_secret format: pi_xxx_secret_yyy
    return clientSecret.split('_secret_').first;
  }

  String _formatError(String error) {
    if (error.contains('Network')) {
      return 'Please check your internet connection';
    } else if (error.contains('401') || error.contains('Unauthorized')) {
      return 'Authentication error. Please try again';
    }
    return 'Payment failed. Please try again';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !_isLoading, // منع الرجوع أثناء التحميل
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preparing payment...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount: ${widget.amount.toStringAsFixed(2)} JOD',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _initPayment,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : const Center(
                  child: Text('Payment ready'),
                ),
    );
  }
}