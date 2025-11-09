// widgets/payment_dialog.dart
import 'package:flutter/material.dart';
import '../services/booking_service.dart';

class PaymentDialog extends StatefulWidget {
  final int sessionId;
  final String token;
  final Map<String, dynamic>? sessionDetails;

  const PaymentDialog({
    Key? key,
    required this.sessionId,
    required this.token,
    this.sessionDetails,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _selectedPaymentMethod = 'Cash';
  final TextEditingController _transactionIdController = TextEditingController();
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'Cash', 'label': 'نقدي', 'icon': Icons.money},
    {'value': 'Credit Card', 'label': 'بطاقة ائتمان', 'icon': Icons.credit_card},
    {'value': 'Bank Transfer', 'label': 'تحويل بنكي', 'icon': Icons.account_balance},
  ];

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await BookingService.confirmPayment(
        token: widget.token,
        sessionId: widget.sessionId,
        paymentMethod: _selectedPaymentMethod,
        transactionId: _transactionIdController.text.isNotEmpty 
            ? _transactionIdController.text 
            : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Success
        Navigator.of(context).pop(true); // Return true to indicate success
        
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
        // Error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result['message'] ?? 'فشل الدفع'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
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
  }

  @override
  Widget build(BuildContext context) {
    final sessionDetails = widget.sessionDetails;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.payment,
                      color: Colors.green.shade700,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تأكيد الدفع',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'جلسة #${widget.sessionId}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Session Details (if available)
              if (sessionDetails != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تفاصيل الجلسة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (sessionDetails['session_type'] != null)
                        _buildDetailRow(
                          Icons.medical_services,
                          'نوع الجلسة',
                          sessionDetails['session_type'],
                        ),
                      if (sessionDetails['duration'] != null)
                        _buildDetailRow(
                          Icons.timer,
                          'المدة',
                          '${sessionDetails['duration']} دقيقة',
                        ),
                      if (sessionDetails['price'] != null)
                        _buildDetailRow(
                          Icons.attach_money,
                          'السعر',
                          '\$${sessionDetails['price']}',
                          isHighlighted: true,
                        ),
                    ],
                  ),
                ),
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
              
              ..._paymentMethods.map((method) => 
                RadioListTile<String>(
                  value: method['value'],
                  groupValue: _selectedPaymentMethod,
                  onChanged: _isProcessing ? null : (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                    });
                  },
                  title: Row(
                    children: [
                      Icon(method['icon'], size: 20),
                      const SizedBox(width: 12),
                      Text(method['label']),
                    ],
                  ),
                  activeColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tileColor: _selectedPaymentMethod == method['value']
                      ? Colors.green.shade50
                      : Colors.grey.shade50,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Transaction ID (optional)
              if (_selectedPaymentMethod != 'Cash') ...[
                TextField(
                  controller: _transactionIdController,
                  enabled: !_isProcessing,
                  decoration: InputDecoration(
                    labelText: 'رقم المعاملة (اختياري)',
                    hintText: 'أدخل رقم المعاملة إن وجد',
                    prefixIcon: const Icon(Icons.receipt),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing 
                          ? null 
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'تأكيد الدفع',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
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
}
