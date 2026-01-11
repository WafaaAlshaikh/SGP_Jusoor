import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart' hide PaymentMethod;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_models.dart';
import '../models/session.dart';
import '../screens/stripe_checkout_screen.dart';
import '../services/payment_service.dart';
import '../theme/app_colors.dart';

class PaymentScreen extends StatefulWidget {
  final Invoice invoice;
  final Session session;

  const PaymentScreen({
    super.key,
    required this.invoice,
    required this.session,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPaymentMethod = 'credit_card';
  bool _isProcessing = false;
  bool _isLoadingMethods = true;
  String? _cardToken;
  List<PaymentMethod> _availablePaymentMethods = [];
  Map<String, dynamic>? _bankDetails;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final methods = await PaymentService.getPaymentMethods(
        token,
        invoiceId: widget.invoice.invoiceId,
      );

      setState(() {
        _availablePaymentMethods = methods;
        _isLoadingMethods = false;

        if (methods.isNotEmpty) {
          _selectedPaymentMethod = methods.first.id;
        }
      });
    } catch (e) {
      print('Error loading payment methods: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load payment methods: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      setState(() {
        _isLoadingMethods = false;
      });
    }
  }

  String _extractPaymentIntentId(String clientSecret) {
    return clientSecret.split('_secret_').first;
  }

  Widget _buildPaymentMethodsList() {
    if (_availablePaymentMethods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent1),
        ),
        child: Column(
          children: [
            Icon(Icons.payment_rounded, size: 72, color: AppColors.textLight),
            const SizedBox(height: 20),
            Text(
              'No Payment Methods',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later or contact support',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _availablePaymentMethods.map((method) {
        final isSelected = _selectedPaymentMethod == method.id;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.accent2,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
                blurRadius: isSelected ? 15 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _isProcessing
                  ? null
                  : () {
                setState(() {
                  _selectedPaymentMethod = method.id;
                });
                if (method.id == 'bank_transfer') {
                  _loadBankDetails();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: isSelected ? null : AppColors.background,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ] : null,
                      ),
                      child: Icon(
                        _getPaymentMethodIcon(method.id),
                        color: isSelected ? AppColors.textWhite : AppColors.textGray,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            method.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textGray,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (method.processingFee > 0 || method.verificationTime != null)
                            LayoutBuilder(
  builder: (context, constraints) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          if (method.processingFee > 0)
            _buildTag(
              'Fee: ${(method.processingFee * 100).toStringAsFixed(1)}%',
              AppColors.warning,
            ),
          if (method.verificationTime != null)
            _buildTag(
              'Verification: ${method.verificationTime}',
              AppColors.info,
            ),
        ],
      ),
    );
  },
),

                        ],
                      ),
                    ),
                    if (method.estimatedTotal > 0) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${method.estimatedTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: isSelected ? AppColors.primary : AppColors.textDark,
                            ),
                          ),
                          if (method.processingFee > 0)
                            Text(
                              'incl. fee',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textLight,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                    ],
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.textLight,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: isSelected ? AppColors.textWhite : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTag(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}


  Widget _buildPaymentContent() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildInvoiceCard(),
              const SizedBox(height: 28),
              _buildPaymentMethodsSection(),
              const SizedBox(height: 28),
              _buildPaymentButton(),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _loadBankDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final details = await PaymentService.getBankDetails(token);
      setState(() {
        _bankDetails = details;
      });
    } catch (e) {
      print('Error loading bank details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Complete Payment',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textDark),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, size: 22),
            onPressed: () {
              // Show help dialog
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _isLoadingMethods
          ? _buildLoadingState()
          : _buildPaymentContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.payment_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Payment Methods',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we prepare your payment options',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with improved layout
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.textWhite,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVOICE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${widget.invoice.invoiceNumber}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.invoice.status),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(widget.invoice.status).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.invoice.status.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Session Details
            _buildDetailItem('Child', widget.session.childName, Icons.child_care_rounded),
            _buildDetailItem('Specialist', widget.session.specialistName, Icons.person_rounded),
            _buildDetailItem('Institution', widget.session.institutionName, Icons.school_rounded),
            _buildDetailItem('Session Type', widget.session.sessionType, Icons.work_rounded),
            _buildDetailItem('Date & Time', '${widget.session.date} • ${widget.session.time}', Icons.calendar_today_rounded),

            const SizedBox(height: 20),
            Divider(height: 1, color: AppColors.accent2),
            const SizedBox(height: 20),

            // Amount Breakdown
            _buildAmountRow('Amount', widget.invoice.amount),
            _buildAmountRow('Tax', widget.invoice.taxAmount),
            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.accent2),
            const SizedBox(height: 16),

            // Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '\$${widget.invoice.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.primary,
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

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textGray,
              fontSize: 15,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'overdue':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your preferred payment option',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textGray,
          ),
        ),
        const SizedBox(height: 24),
        _buildPaymentMethodsList(),
      ],
    );
  }

  IconData _getPaymentMethodIcon(String methodId) {
    switch (methodId) {
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'cash':
        return Icons.money_rounded;
      case 'bank_transfer':
        return Icons.account_balance_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Widget _buildPaymentButton() {
    if (_availablePaymentMethods.isEmpty) {
      return Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.accent2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No Payment Methods Available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
        ),
      );
    }

    final selectedMethod = _availablePaymentMethods.firstWhere(
      (method) => method.id == _selectedPaymentMethod,
      orElse: () => _availablePaymentMethods.first,
    );

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isProcessing ? null : _processPayment,
          child: Stack(
            children: [
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
                ),
              Center(
                child: _isProcessing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textWhite,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Pay \$${selectedMethod.estimatedTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textWhite,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.textWhite.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: AppColors.textWhite,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final paymentResponse = await PaymentService.processPayment(
        token: token,
        invoiceId: widget.invoice.invoiceId,
        paymentMethod: _selectedPaymentMethod,
        cardToken: _cardToken,
      );

      if (paymentResponse.success) {
        if (!kIsWeb &&
            _selectedPaymentMethod == 'credit_card' &&
            paymentResponse.paymentIntentClientSecret != null &&
            paymentResponse.paymentIntentClientSecret!.isNotEmpty) {
          try {
            await Stripe.instance.initPaymentSheet(
              paymentSheetParameters: SetupPaymentSheetParameters(
                paymentIntentClientSecret: paymentResponse.paymentIntentClientSecret!,
                merchantDisplayName: widget.session.institutionName,
                style: ThemeMode.light,
              ),
            );

            await Stripe.instance.presentPaymentSheet();

            final paymentIntentId = paymentResponse.paymentIntentId ??
                _extractPaymentIntentId(paymentResponse.paymentIntentClientSecret!);

            await PaymentService.confirmStripePayment(
              token: token,
              paymentIntentId: paymentIntentId,
              invoiceId: widget.invoice.invoiceId,
            );

            if (!mounted) return;

            Navigator.pop(context, {
              'success': true,
              'payment_flow': 'stripe_mobile',
              'payment_intent_id': paymentIntentId,
              'payment_id': paymentResponse.paymentId,
              'transaction_id': paymentIntentId,
              'session_status': 'Confirmed',
            });
            return;
          } on StripeException catch (e) {
            if (e.error.code == FailureCode.Canceled) {
              return;
            }
            throw Exception(e.error.localizedMessage ?? 'Stripe payment failed');
          }
        }

        if (_selectedPaymentMethod == 'credit_card' && paymentResponse.checkoutUrl != null) {
          final completed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => StripeCheckoutScreen(
                checkoutUrl: paymentResponse.checkoutUrl!,
                sessionId: paymentResponse.checkoutSessionId,
                institutionName: widget.session.institutionName,
                amount: widget.invoice.totalAmount,
              ),
            ),
          );

          if (!mounted) return;

          if (completed == true) {
            Navigator.pop(context, {
              'success': true,
              'payment_flow': 'stripe',
              'checkout_session_id': paymentResponse.checkoutSessionId,
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info_rounded, color: AppColors.textWhite),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Payment not completed yet')),
                  ],
                ),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.textWhite),
                const SizedBox(width: 8),
                Expanded(child: Text(paymentResponse.message)),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (mounted) {
          Navigator.pop(context, {
            'success': true,
            'payment_id': paymentResponse.paymentId,
            'transaction_id': paymentResponse.transactionId,
            'session_status': 'Confirmed'
          });
        }
      } else {
        throw Exception(paymentResponse.message);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_rounded, color: AppColors.textWhite),
              const SizedBox(width: 8),
              Expanded(child: Text('Payment failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showCardTokenDialog() {
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.textWhite.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.credit_card_rounded,
                        color: AppColors.textWhite,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Card Payment',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your card details securely',
                      style: TextStyle(
                        color: AppColors.textWhite.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Test Cards Info
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: AppColors.warning.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.info_rounded, color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Card Numbers',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Success: 4242 4242 4242 4242\nDecline: 4000 0000 0000 0002',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    TextField(
                      controller: cardNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '4242 4242 4242 4242',
                        prefixIcon: Icon(Icons.credit_card_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.accent2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.accent2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: cardHolderController,
                      decoration: InputDecoration(
                        labelText: 'Cardholder Name',
                        hintText: 'John Doe',
                        prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.accent2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.accent2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: expiryController,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: 'MM/YY',
                              hintText: '12/25',
                              prefixIcon: Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.accent2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.accent2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: cvvController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                              prefixIcon: Icon(Icons.lock_rounded, color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.accent2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.accent2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          cardNumberController.dispose();
                          cardHolderController.dispose();
                          expiryController.dispose();
                          cvvController.dispose();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: AppColors.accent2),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (cardNumberController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please enter card number'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                            return;
                          }

                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('token') ?? '';

                          final paymentDetails = {
                            'card_number': cardNumberController.text.replaceAll(' ', ''),
                            'card_holder': cardHolderController.text,
                            'expiry': expiryController.text,
                            'cvv': cvvController.text,
                          };

                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          navigator.pop();

                          setState(() {
                            _isProcessing = true;
                          });

                          try {
                            final paymentResponse = await PaymentService.processPayment(
                              token: token,
                              invoiceId: widget.invoice.invoiceId,
                              paymentMethod: 'credit_card',
                              paymentDetails: paymentDetails,
                            );

                            if (paymentResponse.success) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: AppColors.textWhite),
                                      const SizedBox(width: 8),
                                      Text(paymentResponse.message),
                                    ],
                                  ),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              if (mounted) {
                                Navigator.pop(context, true);
                              }
                            } else {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.error_rounded, color: AppColors.textWhite),
                                      const SizedBox(width: 8),
                                      Text(paymentResponse.message),
                                    ],
                                  ),
                                  backgroundColor: AppColors.error,
                                  duration: const Duration(seconds: 4),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.error_rounded, color: AppColors.textWhite),
                                    const SizedBox(width: 8),
                                    Text('Payment error: ${e.toString()}'),
                                  ],
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                              });
                            }
                          }

                          cardNumberController.dispose();
                          cardHolderController.dispose();
                          expiryController.dispose();
                          cvvController.dispose();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Pay Now',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}