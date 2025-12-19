import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/child_model.dart';
import '../theme/app_colors.dart';

class ChildCard extends StatelessWidget {
  final Child child;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ChildCard({
    super.key,
    required this.child,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  Color _registrationStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return AppColors.success;
      case 'Pending':
        return AppColors.warning;
      case 'Not Registered':
      default:
        return AppColors.textGray;
    }
  }

  IconData _registrationStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.verified_rounded;
      case 'Pending':
        return Icons.pending_actions_rounded;
      case 'Not Registered':
      default:
        return Icons.person_outline_rounded;
    }
  }

  String get _lastSessionText {
    if (child.lastSessionDate != null) {
      final now = DateTime.now();
      final difference = now.difference(child.lastSessionDate!);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(child.lastSessionDate!);
      }
    }
    return 'No sessions yet';
  }

  Color _conditionColor(String? condition) {
    final c = (condition ?? '').toLowerCase();
    if (c.contains('asd') || c.contains('autism')) return Color(0xFF6366F1);
    if (c.contains('adhd')) return Color(0xFFF59E0B);
    if (c.contains('down')) return Color(0xFF8B5CF6);
    if (c.contains('speech')) return Color(0xFF06B6D4);
    return AppColors.textLight;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return '?';
    final parts = trimmedName.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  IconData _getConditionIcon(String? condition) {
    final c = (condition ?? '').toLowerCase();
    if (c.contains('asd') || c.contains('autism')) return Icons.psychology_alt_rounded;
    if (c.contains('adhd')) return Icons.bolt_rounded;
    if (c.contains('down')) return Icons.favorite_rounded;
    if (c.contains('speech')) return Icons.record_voice_over_rounded;
    return Icons.medical_information_rounded;
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _registrationStatusColor(child.registrationStatus).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _registrationStatusColor(child.registrationStatus).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _registrationStatusIcon(child.registrationStatus),
            size: 12,
            color: _registrationStatusColor(child.registrationStatus),
          ),
          const SizedBox(width: 4),
          Text(
            child.registrationStatus,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _registrationStatusColor(child.registrationStatus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIIndicator() {
    if (!child.hasAiAnalysis) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 10, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final hasImage = child.photo.isNotEmpty &&
        !child.photo.contains('base64') &&
        child.photo.startsWith('http');

    return Stack(
      children: [
        // Main Avatar with Gradient Border
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: hasImage
                ? ClipOval(
              child: Image.network(
                child.photo,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(),
              ),
            )
                : _buildInitialsAvatar(),
          ),
        ),

        // Online Status Indicator
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.primaryLight.withOpacity(0.6),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitials(child.fullName),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppColors.textLight),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildConditionChip() {
    if (child.condition == null || child.condition!.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _conditionColor(child.condition).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getConditionIcon(child.condition),
            size: 12,
            color: _conditionColor(child.condition),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              child.condition!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _conditionColor(child.condition),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    _buildAvatar(),

                    const SizedBox(width: 16),

                    // Name and Basic Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            child.fullName,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textDark,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Status beside the name
                                        _buildStatusIndicator(),
                                      ],
                                    ),
                                    if (child.age != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryLight
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppColors.primaryLight
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                '${child.age} years old',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildAIIndicator(),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Condition Chip only
                          if (child.condition != null &&
                              child.condition!.isNotEmpty)
                            _buildConditionChip(),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Additional Information
                if (child.schoolInfo != null && child.schoolInfo!.isNotEmpty ||
                    child.childIdentifier != null &&
                        child.childIdentifier!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (child.childIdentifier != null &&
                            child.childIdentifier!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.badge_rounded,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'ID: ${child.childIdentifier!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (child.schoolInfo != null &&
                            child.schoolInfo!.isNotEmpty) ...[
                          if (child.childIdentifier != null &&
                              child.childIdentifier!.isNotEmpty)
                            const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.school_rounded,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  child.schoolInfo!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Footer Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      // المعلومات في سطر واحد
                      Row(
                        children: [
                          // Last Session Info
                          Expanded(
                            child: _buildInfoItem(
                              Icons.calendar_today_rounded,
                              _lastSessionText,
                              color: AppColors.primary,
                            ),
                          ),

                          // Institution Info
                          if (child.currentInstitutionName != null &&
                              child.currentInstitutionName!.isNotEmpty)
                            Expanded(
                              child: _buildInfoItem(
                                Icons.medical_services_rounded,
                                child.currentInstitutionName!,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // الأزرار في سطر منفصل
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // View Button
                          _buildActionButton(
                            icon: Icons.remove_red_eye_rounded,
                            color: AppColors.primary,
                            onPressed: onView,
                            tooltip: 'View Details',
                          ),

                          const SizedBox(width: 8),

                          // Edit Button - Using Light Green
                          _buildActionButton(
                            icon: Icons.edit_rounded,
                            color: const Color(0xFF10B981), // Light Green
                            onPressed: onEdit,
                            tooltip: 'Edit',
                          ),

                          const SizedBox(width: 8),

                          // Delete Button
                          _buildActionButton(
                            icon: Icons.delete_rounded,
                            color: AppColors.error,
                            onPressed: onDelete,
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Symptoms Preview (if available)
                if (child.symptomsDescription != null &&
                    child.symptomsDescription!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: AppColors.warning.withOpacity(0.1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.psychology_alt_rounded,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              child.symptomsDescription!.length > 80
                                  ? '${child.symptomsDescription!.substring(0, 80)}...'
                                  : child.symptomsDescription!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }
}