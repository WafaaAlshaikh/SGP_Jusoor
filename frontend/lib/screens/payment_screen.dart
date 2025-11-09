import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_models.dart';
import '../models/session.dart';
import '../services/payment_service.dart';

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
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {
        _isLoadingMethods = false;
      });
    }
  }

  Widget _buildPaymentMethodsList() {
    if (_availablePaymentMethods.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.payment_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No Payment Methods Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please try again later or contact our support team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _availablePaymentMethods.map((method) {
        final isSelected = _selectedPaymentMethod == method.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPaymentMethodIcon(method.id),
                        color: isSelected ? Colors.white : Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            method.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (method.processingFee > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Fee: ${(method.processingFee * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (method.verificationTime != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Verification: ${method.verificationTime}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
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
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isSelected ? Colors.blue : Colors.black87,
                            ),
                          ),
                          if (method.processingFee > 0)
                            Text(
                              'incl. fee',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? Colors.blue : Colors.grey[400],
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

  Widget _buildPaymentContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInvoiceCard(),
          const SizedBox(height: 24),
          _buildPaymentMethodsSection(),
          const SizedBox(height: 24),
          _buildPaymentButton(),
          const SizedBox(height: 20),
        ],
      ),
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
        title: const Text(
          'Payment',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
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
          const CircularProgressIndicator(
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Payment Methods...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice #${widget.invoice.invoiceNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.invoice.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.invoice.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInvoiceRow('Child', widget.session.childName),
            _buildInvoiceRow('Specialist', widget.session.specialistName),
            _buildInvoiceRow('Institution', widget.session.institutionName),
            _buildInvoiceRow('Session Type', widget.session.sessionType),
            _buildInvoiceRow('Date & Time', '${widget.session.date} • ${widget.session.time}'),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildInvoiceRow('Amount', '\$${widget.invoice.amount.toStringAsFixed(2)}'),
            _buildInvoiceRow('Tax', '\$${widget.invoice.taxAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildInvoiceRow(
              'Total Amount',
              '\$${widget.invoice.totalAmount.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInvoiceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? Colors.black : Colors.grey[700],
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? Colors.blue : Colors.black87,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your preferred payment option',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),
        _buildPaymentMethodsList(),
      ],
    );
  }

  IconData _getPaymentMethodIcon(String methodId) {
    switch (methodId) {
      case 'credit_card':
        return Icons.credit_card_outlined;
      case 'cash':
        return Icons.money_outlined;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  Widget _buildPaymentButton() {
    if (_availablePaymentMethods.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'No Payment Methods Available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    final selectedMethod = _availablePaymentMethods.firstWhere(
          (method) => method.id == _selectedPaymentMethod,
    );

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: Colors.blue.withOpacity(0.3),
        ),
        child: _isProcessing
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pay \$${selectedMethod.estimatedTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == 'credit_card' && _cardToken == null) {
      _showCardTokenDialog();
      return;
    }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paymentResponse.message),
            backgroundColor: Colors.green,
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
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
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
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Card Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your card details securely',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Test Cards Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.orange.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[800], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Cards',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Success: 4242 4242 4242 4242 • Decline: 4000 0000 0000 0002',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: cardNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '4242 4242 4242 4242',
                        prefixIcon: const Icon(Icons.credit_card_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cardHolderController,
                      decoration: InputDecoration(
                        labelText: 'Cardholder Name',
                        hintText: 'John Doe',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: expiryController,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: 'MM/YY',
                              hintText: '12/25',
                              prefixIcon: const Icon(Icons.calendar_today_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
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
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
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

              // Buttons
              Padding(
                padding: const EdgeInsets.all(16),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (cardNumberController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter card number'),
                                backgroundColor: Colors.red,
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
                                  content: Text(paymentResponse.message),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              if (mounted) {
                                Navigator.pop(context, true);
                              }
                            } else {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(paymentResponse.message),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Payment error: ${e.toString()}'),
                                backgroundColor: Colors.red,
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
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
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