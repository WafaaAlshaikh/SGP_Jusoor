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
  final VoidCallback? onRated;

  const SessionDetailsBottomSheet({
    super.key,
    required this.session,
    this.onRateSession,
    this.onReschedule,
    this.onSetReminder,
    this.onShareSession,
    this.onDownloadInvoice,
    this.onRated,
  });

  // نظام الألوان المتناسق مع التطبيق
  final Color _primaryColor = const Color(0xFF7815A0);
  final Color _secondaryColor = const Color(0xFF976EF4);
  final Color _accentColor = const Color(0xFFCAA9F8);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;
  final Color _textPrimary = const Color(0xFF212529);
  final Color _textSecondary = const Color(0xFF6C757D);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _warningColor = const Color(0xFFFF9800);
  final Color _errorColor = const Color(0xFFF44336);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.only(
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
                  ],

                  // Rating Prompt (if completed and not rated)
                  if (session.displayStatus == 'completed' && session.rating == null) ...[
                    _buildRatingPromptCard(context),
                    const SizedBox(height: 24),
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
        Text(
          'Session Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, size: 24, color: _textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _textPrimary,
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _textSecondary.withOpacity(0.2)),
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
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: _textSecondary,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.person,
                size: 30,
                color: _primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.specialistName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Specialist',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '4.8', // Placeholder - should come from API
                        style: TextStyle(fontSize: 14, color: _textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.message, color: _primaryColor),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Chat feature coming soon'),
                    backgroundColor: _primaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.child_care,
                size: 30,
                color: _warningColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.childName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${session.childAge ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Condition: ${session.childCondition ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parent Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              session.parentNotes!,
              style: TextStyle(fontSize: 14, color: _textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPaymentRow('Session Fee', '\$${session.price.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildPaymentRow('Insurance Discount', '-\$0.00'),
            const SizedBox(height: 8),
            _buildPaymentRow('Tax', '\$${(session.price * 0.16).toStringAsFixed(2)}'),
            const Divider(height: 20),
            _buildPaymentRow(
              'Total Amount',
              '\$${(session.price * 1.16).toStringAsFixed(2)}',
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
            color: isTotal ? _textPrimary : _textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? _primaryColor : _textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCancellationCard() {
    return Card(
      color: _errorColor.withOpacity(0.1),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: _errorColor),
                const SizedBox(width: 8),
                Text(
                  'Cancellation Reason',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _errorColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session.cancellationReason!,
              style: TextStyle(fontSize: 14, color: _textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard() {
    return Card(
      color: _successColor.withOpacity(0.1),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Rating',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary),
                ),
              ],
            ),
            if (session.review != null && session.review!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                session.review!,
                style: TextStyle(fontSize: 14, color: _textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingPromptCard(BuildContext context) { // Add context parameter
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.star_outline, size: 48, color: Colors.amber),
            const SizedBox(height: 8),
            Text(
              'Rate This Session',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your experience to help us improve',
              style: TextStyle(fontSize: 14, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.star, size: 18),
                label: const Text('Rate Now'),
                onPressed: () {
                  Navigator.pop(context);
                  onRateSession?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: _warningColor,
                  side: BorderSide(color: _warningColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
                  Navigator.pop(context);
                  onRateSession?.call();
                  onRated?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Share Button
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share'),
              onPressed: () {
                Navigator.pop(context);
                onShareSession?.call();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _secondaryColor,
                side: BorderSide(color: _secondaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Download Invoice Button
          if (session.price > 0)
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Invoice'),
                onPressed: onDownloadInvoice,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _errorColor,
                  side: BorderSide(color: _errorColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final statusConfig = {
      'upcoming': {'color': Colors.blue, 'icon': Icons.schedule},
      'completed': {'color': _successColor, 'icon': Icons.check_circle},
      'pending': {'color': _warningColor, 'icon': Icons.pending},
      'cancelled': {'color': _errorColor, 'icon': Icons.cancel},
    };

    final config = statusConfig[status] ?? statusConfig['pending']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config['color'] as Color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
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
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: _textPrimary,
    );
  }
}