import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import '../theme/app_colors.dart';

class EquipmentTrackingScreen extends StatefulWidget {
  const EquipmentTrackingScreen({super.key});

  @override
  State<EquipmentTrackingScreen> createState() => _EquipmentTrackingScreenState();
}

class _EquipmentTrackingScreenState extends State<EquipmentTrackingScreen> {
  final TextEditingController _trackingCodeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _donationInfo;
  String? _errorMessage;

  Future<void> _trackDonation() async {
    final trackingCode = _trackingCodeController.text.trim();
    final phone = _phoneController.text.trim();

    if (trackingCode.isEmpty || phone.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter tracking code and phone number';
      });
      return;
    }

    // Extract donation ID from tracking code (EQ000123 -> 123)
    if (!trackingCode.startsWith('EQ')) {
      setState(() {
        _errorMessage = 'Invalid tracking code format';
      });
      return;
    }

    final donationIdStr = trackingCode.substring(2);
    final donationId = int.tryParse(donationIdStr);

    if (donationId == null) {
      setState(() {
        _errorMessage = 'Invalid tracking code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _donationInfo = null;
    });

    try {
      final result = await ApiService.checkEquipmentDonationStatus(
        donationId: donationId,
        contactPhone: phone,
      );

      setState(() {
        _donationInfo = result['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to track donation: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'scheduled':
        return 'مجدول للاستلام';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'scheduled':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Equipment Donation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.track_changes, size: 32, color: Colors.blue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Track Your Donation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your tracking code and phone number to check status',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Tracking Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _trackingCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Tracking Code',
                        hintText: 'e.g., EQ000123',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Phone number used during donation',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _trackDonation,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _isLoading ? 'Tracking...' : 'Track Donation',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Results
            if (_donationInfo != null) ...[
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Donation Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                                  _donationInfo!['status'].toString())
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(
                                _donationInfo!['status'].toString()),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                    _donationInfo!['status'].toString()),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getStatusText(_donationInfo!['status'].toString()),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(
                                    _donationInfo!['status'].toString()),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Donation Details
                      _buildInfoRow(
                        label: 'Equipment',
                        value: _donationInfo!['equipment_name'].toString(),
                        icon: Icons.medical_services,
                      ),

                      const SizedBox(height: 12),

                      _buildInfoRow(
                        label: 'Tracking Code',
                        value: _donationInfo!['tracking_code'].toString(),
                        icon: Icons.qr_code,
                      ),

                      const SizedBox(height: 12),

                      _buildInfoRow(
                        label: 'Institution',
                        value: _donationInfo!['institution_name']?.toString() ??
                            'Institution',
                        icon: Icons.apartment,
                      ),

                      const SizedBox(height: 12),

                      _buildInfoRow(
                        label: 'Submitted Date',
                        value: _formatDate(_donationInfo!['created_at']),
                        icon: Icons.calendar_today,
                      ),

                      const SizedBox(height: 24),

                      // Next Steps based on status
                      _buildNextSteps(),

                      const SizedBox(height: 16),

                      // Contact Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Implement contact functionality
                          },
                          icon: const Icon(Icons.help_outline),
                          label: const Text('Need Help? Contact Support'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Information Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFAQItem(
                    question: 'How long does review take?',
                    answer: 'Typically 2-3 business days. You will be contacted by the institution.',
                  ),
                  _buildFAQItem(
                    question: 'What if my donation is rejected?',
                    answer: 'You will receive a reason and can collect the equipment or donate elsewhere.',
                  ),
                  _buildFAQItem(
                    question: 'Can I update my contact information?',
                    answer: 'Yes, contact the institution directly with your tracking code.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• $question',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSteps() {
    final status = _donationInfo!['status'].toString().toLowerCase();
    
    String message;
    Color color;
    
    switch (status) {
      case 'pending':
        message = 'Your donation is under review. The institution will contact you soon.';
        color = Colors.orange;
        break;
      case 'approved':
        message = 'Your donation has been approved! Expect a call to schedule pickup/delivery.';
        color = Colors.green;
        break;
      case 'scheduled':
        message = 'Pickup/delivery has been scheduled. Please be available on the agreed date.';
        color = Colors.blue;
        break;
      case 'delivered':
        message = 'Thank you! Your donation has been successfully delivered.';
        color = Colors.green;
        break;
      case 'rejected':
        message = 'Your donation was not accepted. Please check with the institution for details.';
        color = Colors.red;
        break;
      default:
        message = 'Status update will be provided by the institution.';
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }
}