// lib/widgets/session_details_sheet.dart
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../utils/app_colors.dart';

class SessionDetailsBottomSheet extends StatelessWidget {
  final Session session;
  final VoidCallback? onRateSession;
  final VoidCallback? onReschedule;
  final VoidCallback? onSetReminder;
  final VoidCallback? onShareSession;
  final VoidCallback? onDownloadInvoice;
  final VoidCallback? onRated; // أضف هذا


  const SessionDetailsBottomSheet({
    super.key,
    required this.session,
    this.onRateSession,
    this.onReschedule,
    this.onSetReminder,
    this.onShareSession,
    this.onDownloadInvoice,
    this.onRated, // أضف هذا

  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),
          const SizedBox(height: 24),

          // Session Details
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info Section
                  _buildSectionTitle('Session Information'),
                  const SizedBox(height: 16),
                  _buildInfoGrid(),
                  const SizedBox(height: 24),

                  // Specialist Details
                  _buildSectionTitle('Specialist Details'),
                  const SizedBox(height: 16),
                  _buildSpecialistCard(context),
                  const SizedBox(height: 24),

                  // Child Details
                  _buildSectionTitle('Child Information'),
                  const SizedBox(height: 16),
                  _buildChildCard(),
                  const SizedBox(height: 24),

                  // Additional Information
                  if (session.parentNotes != null && session.parentNotes!.isNotEmpty) ...[
                    _buildSectionTitle('Additional Notes'),
                    const SizedBox(height: 16),
                    _buildNotesCard(),
                    const SizedBox(height: 24),
                  ],

                  // Payment Information
                  if (session.price > 0) ...[
                    _buildSectionTitle('Payment Information'),
                    const SizedBox(height: 16),
                    _buildPaymentCard(),
                    const SizedBox(height: 24),
                  ],

                  // Cancellation Info (if cancelled)
                  if (session.displayStatus == 'cancelled' && session.cancellationReason != null) ...[
                    _buildSectionTitle('Cancellation Details'),
                    const SizedBox(height: 16),
                    _buildCancellationCard(),
                    const SizedBox(height: 24),
                  ],

                  // Rating (if completed)
                  if (session.displayStatus == 'completed' && session.rating != null) ...[
                    _buildSectionTitle('Session Rating'),
                    const SizedBox(height: 16),
                    _buildRatingCard(),
                    const SizedBox(height: 24),
                    // بعد سطر الـ Rating Card، أضف زر التقييم إذا الجلسة مكتملة ومش مترقية
                    if (session.displayStatus == 'completed' && session.rating == null) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.star_outline, size: 48, color: Colors.amber),
                              const SizedBox(height: 8),
                              const Text(
                                'Rate This Session',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Share your experience to help us improve',
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.star, size: 18),
                                  label: const Text('Rate Now'),
                                  onPressed: () {
                                    Navigator.pop(context); // يغلق الـ sheet
                                    onRateSession?.call(); // يفتح dialog التقييم
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Session Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ParentAppColors.textDark,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: ParentAppColors.textDark,
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildInfoRow('Status', _buildStatusChip(session.displayStatus)),
          const SizedBox(height: 12),
          _buildInfoRow('Date', Text(session.date, style: _infoTextStyle())),
          const SizedBox(height: 12),
          _buildInfoRow('Time', Text(session.time, style: _infoTextStyle())),
          const SizedBox(height: 12),
          _buildInfoRow('Duration', Text('${session.duration} minutes', style: _infoTextStyle())),
          const SizedBox(height: 12),
          _buildInfoRow('Type', Text(session.sessionType, style: _infoTextStyle())),
          const SizedBox(height: 12),
          _buildInfoRow('Location', Text(session.sessionLocation, style: _infoTextStyle())),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: value),
      ],
    );
  }

  Widget _buildSpecialistCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: ParentAppColors.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.person,
                size: 30,
                color: ParentAppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.specialistName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Specialist',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '4.8', // Placeholder - should come from API
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.message, color: ParentAppColors.primaryTeal),
              onPressed: () {
                // TODO: Implement chat with specialist
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat feature coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.child_care,
                size: 30,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.childName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${session.childAge ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Condition: ${session.childCondition ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
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

  Widget _buildNotesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parent Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              session.parentNotes!,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPaymentRow('Session Fee', '\$${session.price.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildPaymentRow('Insurance Discount', '-\$0.00'), // Placeholder
            const SizedBox(height: 8),
            _buildPaymentRow('Tax', '\$${(session.price * 0.16).toStringAsFixed(2)}'), // Placeholder
            const Divider(height: 20),
            _buildPaymentRow(
              'Total Amount',
              '\$${(session.price * 1.16).toStringAsFixed(2)}', // Placeholder
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? ParentAppColors.textDark : Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? ParentAppColors.primaryTeal : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCancellationCard() {
    return Card(
      color: Colors.red[50],
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Cancellation Reason',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session.cancellationReason!,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard() {
    return Card(
      color: Colors.green[50],
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Rating',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    size: 20,
                    color: index < session.rating!.floor() ? Colors.amber : Colors.grey[300],
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  '${session.rating!.toStringAsFixed(1)}/5',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (session.review != null && session.review!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                session.review!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          // Set Reminder Button
          if (session.displayStatus == 'upcoming') ...[
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.notifications_none, size: 18),
                label: const Text('Reminder'),
                onPressed: onSetReminder,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Reschedule Button
          if (session.displayStatus == 'pending') ...[
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Reschedule'),
                onPressed: onReschedule,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Rate Session Button
          if (session.displayStatus == 'completed' && session.rating == null) ...[
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.star, size: 18),
                label: const Text('Rate Session'),
                onPressed: () {
                  Navigator.pop(context); // يغلق الـ sheet
                  onRateSession?.call(); // يفتح dialog التقييم
                  onRated?.call(); // يحدث البيانات بعد التقييم
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Share Button
          // بدل الـ Share Button الحالي، غير لـ:
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.share, size: 18),
              label: const Text('share'),
              onPressed: () {
                Navigator.pop(context); // يغلق الـ sheet أول
                if (onShareSession != null) {
                  onShareSession!(); // ثم ينفذ المشاركة
                }
              },
            ),
          ),

          const SizedBox(width: 12),

          // Download Invoice Button
          if (session.price > 0)
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: const Text('فاتورة'),
                onPressed: onDownloadInvoice,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final statusConfig = {
      'upcoming': {'color': Colors.blue, 'icon': Icons.schedule},
      'completed': {'color': Colors.green, 'icon': Icons.check_circle},
      'pending': {'color': Colors.orange, 'icon': Icons.pending},
      'cancelled': {'color': Colors.red, 'icon': Icons.cancel},
    };

    final config = statusConfig[status] ?? statusConfig['pending']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config['color'] as Color? ?? Colors.orange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData? ?? Icons.pending,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _infoTextStyle() {
    return const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
  }
}