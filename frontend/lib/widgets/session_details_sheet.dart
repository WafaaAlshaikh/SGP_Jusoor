// lib/widgets/session_details_sheet.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/reminder_selection_screen.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../theme/app_colors.dart';

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

  String _generateSessionId(Session session) {
    final uniqueString = '${session.date}_${session.time}_${session.childName}_${session.specialistName}';
    return uniqueString.hashCode.toString();
  }

  DateTime _parseSessionDateTime(Session session) {
    try {
      // Parse session date
      final sessionDate = DateFormat('yyyy-MM-dd').parse(session.date);
      
      // Parse time
      final timeParts = session.time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1].split(' ')[0]);
      final isPM = session.time.toLowerCase().contains('pm');
      
      return DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        isPM && hour != 12 ? hour + 12 : hour,
        minute,
      );
    } catch (e) {
      print('⚠️ Error parsing session date/time: $e');
      return DateTime.now().add(const Duration(days: 1)); // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Header with Drag Handle
          _buildHeader(context),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Status & Quick Info
                  _buildSessionHeader(),
                  const SizedBox(height: 24),

                  // Basic Info Section
                  _buildInfoSection(),
                  const SizedBox(height: 24),

                  // Specialist Details
                  _buildSpecialistSection(),
                  const SizedBox(height: 24),

                  // Child Details
                  _buildChildSection(),
                  const SizedBox(height: 24),

                  // Additional Notes
                  if (session.parentNotes != null && session.parentNotes!.isNotEmpty) ...[
                    _buildNotesSection(),
                    const SizedBox(height: 24),
                  ],

                  // Payment Information
                  if (session.price > 0) ...[
                    _buildPaymentSection(),
                    const SizedBox(height: 24),
                  ],

                  // Cancellation Info
                  if (session.displayStatus == 'cancelled' && session.cancellationReason != null) ...[
                    _buildCancellationSection(),
                    const SizedBox(height: 24),
                  ],

                  // Rating Section
                  if (session.displayStatus == 'completed') ...[
                    _buildRatingSection(context),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close, size: 20, color: AppColors.textGray),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.accent1.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent2.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(session.displayStatus).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(session.displayStatus),
              size: 24,
              color: _getStatusColor(session.displayStatus),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.sessionType,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.date} • ${session.time}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusChip(session.displayStatus),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Session Information'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDetailItem(
                icon: Icons.calendar_today_outlined,
                title: 'Date',
                value: session.date,
              ),
              _buildDivider(),
              _buildDetailItem(
                icon: Icons.access_time_outlined,
                title: 'Time',
                value: session.time,
              ),
              _buildDivider(),
              _buildDetailItem(
                icon: Icons.timer_outlined,
                title: 'Duration',
                value: '${session.duration} minutes',
              ),
              _buildDivider(),
              _buildDetailItem(
                icon: Icons.category_outlined,
                title: 'Type',
                value: session.sessionType,
              ),
              _buildDivider(),
              _buildDetailItem(
                icon: Icons.location_on_outlined,
                title: 'Location',
                value: session.sessionLocation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        height: 1,
        color: AppColors.textLight.withOpacity(0.2),
      ),
    );
  }

  Widget _buildSpecialistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Specialist Details'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent2.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primaryLight,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: Colors.white,
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Therapy Specialist',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '4.8',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '25+ Sessions',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChildSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Child Information'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent2.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              // Child Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.child_care,
                  size: 28,
                  color: AppColors.primary,
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (session.childAge != null)
                          _buildChildDetail('Age', session.childAge!.toString()),
                        if (session.childCondition != null)
                          _buildChildDetail('Condition', session.childCondition!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChildDetail(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Additional Notes'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.accent1.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.note_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parent Notes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.parentNotes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGray,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    String formatAmount(double value) {
      return '${value.toStringAsFixed(2)} JOD';
    }

    final baseAmount = session.originalPrice ?? session.price;
    final discountAmount = session.discountAmount ?? session.autoDiscountAmount ?? 0;
    final finalAmount = session.finalPrice ?? (baseAmount - discountAmount);
    final invoiceTotal = session.sessionTypePrice > 0 ? (session.refundAmount == null ? null : null) : null;
    final refundAmount = session.refundAmount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Payment Information'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent3.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildPaymentRow('Payment Status', session.paymentStatus.isNotEmpty ? session.paymentStatus : 'Pending'),
              const SizedBox(height: 8),
              _buildPaymentRow('Original Amount', formatAmount(baseAmount)),
              const SizedBox(height: 8),
              if (discountAmount > 0) ...[
                _buildPaymentRow('Discount', '-${formatAmount(discountAmount)}'),
                const SizedBox(height: 8),
              ],
              _buildPaymentRow('Final Amount', formatAmount(finalAmount < 0 ? 0 : finalAmount)),
              if (refundAmount > 0) ...[
                const SizedBox(height: 8),
                _buildPaymentRow('Refunded', formatAmount(refundAmount)),
              ],
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: AppColors.textLight.withOpacity(0.2),
              ),
              const SizedBox(height: 12),
              _buildPaymentRow(
                'Total',
                formatAmount(finalAmount < 0 ? 0 : finalAmount),
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
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
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppColors.textDark : AppColors.textGray,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: isTotal ? AppColors.primary : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildCancellationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Cancellation Details'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.accent1.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent3),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent3.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.accent4,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cancellation Reason',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.cancellationReason!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGray,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    if (session.rating != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Your Rating'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accent1.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent2.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        Icons.star_rounded,
                        size: 22,
                        color: index < session.rating!.floor()
                            ? Colors.amber
                            : AppColors.textLight,
                      );
                    }),
                    const SizedBox(width: 12),
                    Text(
                      '${session.rating!.toStringAsFixed(1)}/5',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                if (session.review != null && session.review!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.review!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent1.withOpacity(0.3),
              AppColors.accent2.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent2.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_outline_rounded,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate This Session',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share your experience to help us improve',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.pop(context);
                onRateSession?.call();
                onRated?.call();
              },
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                padding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      );
    }
  }

 Widget _buildActionButtons(BuildContext context) {
  Widget? mainButton;
  
  // تحديد الزر المناسب بناءً على الحالة
  switch (session.displayStatus) {
    case 'upcoming':
      mainButton = Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _onSetReminder(context),
          icon: Icon(Icons.notifications_outlined, size: 20),
          label: Text('Set Reminder'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 1,
          ),
        ),
      );
      break;
      
    case 'pending':
      mainButton = Expanded(
        child: ElevatedButton.icon(
          onPressed: onReschedule,
          icon: Icon(Icons.schedule_outlined, size: 20),
          label: Text('Reschedule'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent4,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 1,
          ),
        ),
      );
      break;
      
    case 'completed':
      if (session.rating == null) {
        mainButton = Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onRateSession?.call();
              onRated?.call();
            },
            icon: Icon(Icons.star_outline_rounded, size: 20),
            label: Text('Rate Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 1,
            ),
          ),
        );
      } else {
        mainButton = const Spacer();
      }
      break;
      
    default:
      mainButton = const Spacer();
  }
  
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border(
        top: BorderSide(
          color: AppColors.textLight.withOpacity(0.2),
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        mainButton,
        const SizedBox(width: 12),
        // يمكنك إضافة Secondary Actions هنا إذا أردت
      ],
    ),
  );
}
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    );
  }


  Future<void> _onSetReminder(BuildContext context) async {
  // احفظ الـ context الأصلي
  final originalContext = context;
  
  // احسب sessionDateTime
  final sessionDateTime = _parseSessionDateTime(session);
  
  // فتح شاشة ReminderSelectionScreen
  final result = await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ReminderSelectionScreen(
        sessionId: _generateSessionId(session),
        sessionTitle: '${session.sessionType} - ${session.childName}',
        sessionDateTime: sessionDateTime,
      ),
    ),
  );
  
  // بعد العودة من الشاشة الجديدة، أغلق الـ Bottom Sheet
  Navigator.of(originalContext).pop();
  
  // عرض رسالة النجاح
  if (result == true) {
    // استخدم Future.delayed لضمان إغلاق الـ Sheet أولاً
    Future.delayed(const Duration(milliseconds: 300), () {
      if (originalContext.mounted) {
        ScaffoldMessenger.of(originalContext).showSnackBar(
          const SnackBar(
            content: Text('✅ Reminder set successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }
}


  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming':
        return AppColors.primary;
      case 'completed':
        return AppColors.primaryLight;
      case 'pending':
        return AppColors.accent4;
      case 'cancelled':
        return AppColors.textGray;
      default:
        return AppColors.textGray;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'upcoming':
        return Icons.schedule_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.pending_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }
}