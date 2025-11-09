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

  Color _registrationStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green.shade600;
      case 'Pending':
        return Colors.orange.shade600;
      case 'Not Registered':
      default:
        return Colors.grey.shade600;
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
    return Colors.grey.shade600;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
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
    if (!child.hasAiAnalysis) return SizedBox();

    return Tooltip(
      message: child.aiAnalysisSummary,
      child: Container(
        margin: EdgeInsets.only(left: 8),
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology, size: 10, color: Colors.purple),
            SizedBox(width: 2),
            Text(
              'AI',
              style: TextStyle(
                fontSize: 10,
                color: Colors.purple.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // في child_card.dart - إضافة عرض البيانات الجديدة:

  Widget _buildSymptomsPreview() {
    if (child.symptomsDescription == null || child.symptomsDescription!.isEmpty) {
      return SizedBox();
    }

    final symptoms = child.symptomsDescription!;
    final preview = symptoms.length > 50 ? '${symptoms.substring(0, 50)}...' : symptoms;

    return Container(
      margin: EdgeInsets.only(top: 4),
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, size: 12, color: Colors.orange.shade600),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              preview,
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

// إضافة معلومات إضافية في الـ Card
  Widget _buildAdditionalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (child.childIdentifier != null && child.childIdentifier!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'ID: ${child.childIdentifier!}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        if (child.schoolInfo != null && child.schoolInfo!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'School: ${child.schoolInfo!}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }


  // في child_card.dart - تحديث بناء الصورة
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
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
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
                        color: Colors.white,
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

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            child.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (child.age != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${child.age}y',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        _buildAIIndicator(),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _conditionColor(child.condition).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
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
                                child.condition ?? '-',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _conditionColor(child.condition),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _registrationStatusColor(child.registrationStatus).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
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
                    _buildSymptomsPreview(),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _lastSessionText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        if (child.currentInstitutionName != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.school_rounded,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              child.currentInstitutionName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  children: [
                    IconButton(
                      onPressed: onView,
                      icon: Icon(
                        Icons.visibility_rounded,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      tooltip: 'View Details',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_rounded,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      tooltip: 'Edit',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_rounded,
                        color: Colors.red.shade600,
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
    );
  }
}