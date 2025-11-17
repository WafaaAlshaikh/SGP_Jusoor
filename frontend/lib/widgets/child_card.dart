import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/child_model.dart';

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

  Color _registrationStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return _successColor;
      case 'Pending':
        return _warningColor;
      case 'Not Registered':
      default:
        return _textSecondary;
    }
  }

  IconData _registrationStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.verified_rounded;
      case 'Pending':
        return Icons.pending_rounded;
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
    return 'No sessions';
  }

  Color _conditionColor(String? condition) {
    final c = (condition ?? '').toLowerCase();
    if (c.contains('asd') || c.contains('autism')) return Colors.blue.shade600;
    if (c.contains('adhd')) return Colors.orange.shade600;
    if (c.contains('down')) return Colors.purple.shade600;
    if (c.contains('speech')) return Colors.teal.shade600;
    return _textSecondary;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return '?';

    final parts = trimmedName.split(' ').where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) return '?';

    // إذا كان هناك جزء واحد فقط
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }

    // إذا كان هناك أكثر من جزء، خذ الحرف الأول من الجزء الأول والأخير
    final firstPart = parts[0];
    final lastPart = parts[parts.length - 1];

    if (firstPart.isEmpty && lastPart.isEmpty) return '?';
    if (firstPart.isEmpty) return lastPart[0].toUpperCase();
    if (lastPart.isEmpty) return firstPart[0].toUpperCase();

    return '${firstPart[0]}${lastPart[0]}'.toUpperCase();
  }

  IconData _getConditionIcon(String? condition) {
    final c = (condition ?? '').toLowerCase();
    if (c.contains('asd') || c.contains('autism')) return Icons.psychology_rounded;
    if (c.contains('adhd')) return Icons.bolt_rounded;
    if (c.contains('down')) return Icons.favorite_rounded;
    if (c.contains('speech')) return Icons.record_voice_over_rounded;
    return Icons.medical_services_rounded;
  }

  Widget _buildAIIndicator() {
    if (!child.hasAiAnalysis) return const SizedBox();

    return Tooltip(
      message: child.aiAnalysisSummary,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _secondaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _secondaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology, size: 10, color: _secondaryColor),
            const SizedBox(width: 2),
            Text(
              'AI',
              style: TextStyle(
                fontSize: 10,
                color: _secondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsPreview() {
    if (child.symptomsDescription == null || child.symptomsDescription!.isEmpty) {
      return const SizedBox();
    }

    final symptoms = child.symptomsDescription!;
    final preview = symptoms.length > 50 ? '${symptoms.substring(0, 50)}...' : symptoms;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _warningColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, size: 12, color: _warningColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              preview,
              style: TextStyle(
                fontSize: 10,
                color: _warningColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (child.childIdentifier != null && child.childIdentifier!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'ID: ${child.childIdentifier!}',
              style: TextStyle(fontSize: 11, color: _textSecondary),
            ),
          ),
        if (child.schoolInfo != null && child.schoolInfo!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'School: ${child.schoolInfo!}',
              style: TextStyle(fontSize: 11, color: _textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar({required String name, required String image, double radius = 25}) {
    // إذا كانت الصورة غير صالحة، استخدم الحروف الأولى
    if (image.isEmpty || image.contains('base64') || !image.startsWith('http')) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: _conditionColor(child.condition).withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _getInitials(name),
            style: TextStyle(
              fontSize: radius * 0.6,
              fontWeight: FontWeight.bold,
              color: _conditionColor(child.condition),
            ),
          ),
        ),
      );
    }

    // إذا كانت الصورة صالحة، استخدم NetworkImage مع error handling
    return ClipOval(
      child: Image.network(
        image,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: _conditionColor(child.condition).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(name),
                style: TextStyle(
                  fontSize: radius * 0.6,
                  fontWeight: FontWeight.bold,
                  color: _conditionColor(child.condition),
                ),
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: _backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: _primaryColor,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _surfaceColor,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar Section
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _conditionColor(child.condition).withOpacity(0.1),
                        image: child.photo.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(child.photo),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: child.photo.isEmpty
                          ? Center(
                        child: Text(
                          _getInitials(child.fullName),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _conditionColor(child.condition),
                          ),
                        ),
                      )
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _registrationStatusIcon(child.registrationStatus),
                          color: _registrationStatusColor(child.registrationStatus),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Content Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Age Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              child.fullName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (child.age != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${child.age}y',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          _buildAIIndicator(),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Condition and Status Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Condition Chip
                          if (child.condition != null && child.condition!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _conditionColor(child.condition).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _conditionColor(child.condition).withOpacity(0.3),
                                ),
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
                                  Text(
                                    child.condition!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _conditionColor(child.condition),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Registration Status Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _registrationStatusColor(child.registrationStatus).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _registrationStatusColor(child.registrationStatus).withOpacity(0.3),
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
                                    fontSize: 11,
                                    color: _registrationStatusColor(child.registrationStatus),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Symptoms Preview
                      _buildSymptomsPreview(),

                      const SizedBox(height: 8),

                      // Additional Info
                      _buildAdditionalInfo(),

                      // Last Session and Institution
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: _textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _lastSessionText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),

                          if (child.currentInstitutionName != null && child.currentInstitutionName!.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.school_rounded,
                              size: 12,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                child.currentInstitutionName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Action Buttons
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _backgroundColor,
                  ),
                  child: Column(
                    children: [
                      // View Button
                      IconButton(
                        onPressed: onView,
                        icon: Icon(
                          Icons.visibility_rounded,
                          color: _primaryColor,
                          size: 20,
                        ),
                        tooltip: 'View Details',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),

                      // Edit Button
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(
                          Icons.edit_rounded,
                          color: _warningColor,
                          size: 20,
                        ),
                        tooltip: 'Edit',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),

                      // Delete Button
                      IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_rounded,
                          color: _errorColor,
                          size: 20,
                        ),
                        tooltip: 'Delete',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}