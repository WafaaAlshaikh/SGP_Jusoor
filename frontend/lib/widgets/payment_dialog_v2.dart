// widgets/payment_dialog_v2.dart
// نسخة محسّنة تدعم الطرق الثلاث + Test Cards

import 'package:flutter/material.dart';
import '../services/booking_service.dart';

class PaymentDialogV2 extends StatefulWidget {
  final int sessionId;
  final String token;
  final Map<String, dynamic>? sessionDetails;

  const PaymentDialogV2({
    Key? key,
    required this.sessionId,
    required this.token,
    this.sessionDetails,
  }) : super(key: key);

  @override
  State<PaymentDialogV2> createState() => _PaymentDialogV2State();
}

class _PaymentDialogV2State extends State<PaymentDialogV2> {
  String _selectedPaymentMethod = 'Cash';
  bool _isProcessing = false;

  // Controllers for Credit Card
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  // Controllers for Bank Transfer
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();

  final List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'Cash', 'label': 'نقدي', 'icon': Icons.money, 'color': Colors.green},
    {'value': 'Credit Card', 'label': 'بطاقة ائتمان', 'icon': Icons.credit_card, 'color': Colors.blue},
    {'value': 'Bank Transfer', 'label': 'تحويل بنكي', 'icon': Icons.account_balance, 'color': Colors.orange},
  ];

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // تجهيز البيانات حسب طريقة الدفع
      Map<String, dynamic> paymentData = {
        'payment_method': _selectedPaymentMethod,
      };

      // إضافة تفاصيل البطاقة إذا كانت الطريقة Credit Card
      if (_selectedPaymentMethod == 'Credit Card') {
        if (_cardNumberController.text.isEmpty) {
          _showError('يرجى إدخال رقم البطاقة');
          return;
        }
        paymentData['card_details'] = {
          'card_number': _cardNumberController.text.replaceAll(' ', ''),
          'card_holder': _cardHolderController.text,
          'expiry': _expiryController.text,
          'cvv': _cvvController.text,
        };
      }

      // إضافة تفاصيل التحويل البنكي
      if (_selectedPaymentMethod == 'Bank Transfer') {
        if (_bankNameController.text.isEmpty || _accountNumberController.text.isEmpty) {
          _showError('يرجى إدخال تفاصيل البنك');
          return;
        }
        paymentData['bank_details'] = {
          'bank_name': _bankNameController.text,
          'account_number': _accountNumberController.text,
          'reference_number': _referenceController.text,
        };
      }

      final result = await BookingService.confirmPaymentV2(
        token: widget.token,
        sessionId: widget.sessionId,
        paymentData: paymentData,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pop(true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result['message'] ?? 'تم الدفع بنجاح'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        _showError(result['message'] ?? 'فشل الدفع');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionDetails = widget.sessionDetails;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),
              
              // Session Details
              if (sessionDetails != null) ...[
                _buildSessionDetails(sessionDetails),
                const SizedBox(height: 24),
              ],
              
              // Payment Method Selection
              Text(
                'طريقة الدفع',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              ..._paymentMethods.map((method) => _buildPaymentMethodTile(method)),
              
              const SizedBox(height: 16),
              
              // Payment Details Form
              _buildPaymentForm(),
              
              const SizedBox(height: 24),
              
              // Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payment,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تأكيد الدفع',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'جلسة #${widget.sessionId}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetails(Map<String, dynamic> details) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'تفاصيل الجلسة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (details['session_type'] != null)
                  _buildDetailRow(Icons.medical_services, 'نوع الجلسة', details['session_type']),
                const SizedBox(height: 8),
                if (details['duration'] != null)
                  _buildDetailRow(Icons.timer, 'المدة', '${details['duration']} دقيقة'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                if (details['price'] != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'المبلغ الإجمالي',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${details['price']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile(Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == method['value'];
    
    return GestureDetector(
      onTap: _isProcessing ? null : () {
        setState(() {
          _selectedPaymentMethod = method['value'];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [method['color'].withOpacity(0.1), method['color'].withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? method['color'] : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: method['color'].withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? method['color'].withOpacity(0.2) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                method['icon'],
                size: 28,
                color: isSelected ? method['color'] : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                method['label'],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? method['color'] : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: method['color'],
                size: 24,
              )
            else
              Icon(
                Icons.circle_outlined,
                color: Colors.grey.shade400,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    switch (_selectedPaymentMethod) {
      case 'Credit Card':
        return _buildCreditCardForm();
      case 'Bank Transfer':
        return _buildBankTransferForm();
      default:
        return _buildCashInfo();
    }
  }

  Widget _buildCreditCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تفاصيل البطاقة',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
        ),
        const SizedBox(height: 12),
        
        // Test Cards Info - Demo Mode
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade50, Colors.orange.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.science, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DEMO MODE - بطاقات تجريبية',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: Colors.orange.shade900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTestCardRow('✅', '4242 4242 4242 4242', 'نجاح', Colors.green),
              const SizedBox(height: 4),
              _buildTestCardRow('❌', '4000 0000 0000 0002', 'رفض', Colors.red),
              const SizedBox(height: 4),
              _buildTestCardRow('✅', '5555 5555 5555 4444', 'Mastercard', Colors.blue),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'لا يتم خصم أموال حقيقية',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        TextField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'رقم البطاقة',
            prefixIcon: const Icon(Icons.credit_card),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 12),
        
        TextField(
          controller: _cardHolderController,
          decoration: InputDecoration(
            labelText: 'اسم حامل البطاقة',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiryController,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: 'MM/YY',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _cvvController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBankTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تفاصيل التحويل البنكي',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700),
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'ℹ️ سيتم مراجعة التحويل من قبل المدير قبل التأكيد',
            style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
          ),
        ),
        
        const SizedBox(height: 16),
        
        TextField(
          controller: _bankNameController,
          decoration: InputDecoration(
            labelText: 'اسم البنك',
            prefixIcon: const Icon(Icons.account_balance),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 12),
        
        TextField(
          controller: _accountNumberController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'رقم الحساب',
            prefixIcon: const Icon(Icons.numbers),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 12),
        
        TextField(
          controller: _referenceController,
          decoration: InputDecoration(
            labelText: 'رقم المرجع (اختياري)',
            prefixIcon: const Icon(Icons.receipt),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildCashInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الدفع النقدي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'سيتم الدفع مباشرة في المؤسسة',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 20),
              label: const Text('إلغاء', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade400, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _confirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                shadowColor: Colors.green.shade400,
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'جاري المعالجة...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'تأكيد الدفع',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.green.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCardRow(String emoji, String cardNumber, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cardNumber,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
