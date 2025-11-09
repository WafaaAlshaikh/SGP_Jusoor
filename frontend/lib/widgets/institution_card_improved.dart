import 'package:flutter/material.dart';

/// ⭐ Improved Institution Card Widget
/// استخدم هذا بدلاً من _buildInstitutionCard في child_form_dialog.dart
class ImprovedInstitutionCard extends StatelessWidget {
  final Map<String, dynamic> institution;
  final bool isSelected;
  final VoidCallback onTap;

  const ImprovedInstitutionCard({
    Key? key,
    required this.institution,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = institution['name'] ?? 'مؤسسة غير معروفة';
    final city = institution['city'] ?? '';
    final matchScore = institution['match_score'] ?? '0%';
    final specialties = institution['matching_specialties'] ?? [];
    final distance = institution['distance']?.toString();
    final rating = institution['rating'];
    final avgPrice = institution['avg_price'];
    final servicesCount = institution['services_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 6 : 2,
      shadowColor: isSelected 
        ? Color(0xFF7815A0).withOpacity(0.3) 
        : Colors.black.withOpacity(0.1),
      color: isSelected 
        ? Color(0xFF7815A0).withOpacity(0.05) 
        : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Color(0xFF7815A0) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⭐ Header Row
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected 
                          ? [Color(0xFF7815A0), Color(0xFF9C27B0)]
                          : [Colors.grey.shade100, Colors.grey.shade200],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: Color(0xFF7815A0).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ] : [],
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Name & City
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected 
                              ? Color(0xFF7815A0) 
                              : Colors.grey.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (city.isNotEmpty && city != 'null') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined, 
                                size: 14, 
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  city,
                                  style: TextStyle(
                                    fontSize: 13, 
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Selection Badge
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_rounded, 
                        color: Colors.white, 
                        size: 16,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // ⭐ Specialties
              if (specialties.isNotEmpty && specialties is List)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (specialties as List).take(3).map<Widget>((specialty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF7815A0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF7815A0).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        specialty.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7815A0),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              
              if (specialties.isNotEmpty && specialties is List)
                const SizedBox(height: 12),
              
              // ⭐ Stats Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(
                    color: Color(0xFF7815A0).withOpacity(0.2),
                  ) : null,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    // Match Score
                    _buildStatItem(
                      icon: Icons.verified_rounded,
                      label: 'توافق',
                      value: matchScore,
                      color: _getMatchScoreColor(matchScore),
                    ),
                    // Rating
                    if (rating != null)
                      _buildStatItem(
                        icon: Icons.star_rounded,
                        label: 'تقييم',
                        value: rating.toString(),
                        color: Colors.amber.shade700,
                      ),
                    // Price
                    if (avgPrice != null)
                      _buildStatItem(
                        icon: Icons.attach_money_rounded,
                        label: 'سعر',
                        value: '\$${avgPrice}',
                        color: Colors.green.shade600,
                      ),
                    // Distance
                    if (distance != null && distance != 'null')
                      _buildStatItem(
                        icon: Icons.social_distance_rounded,
                        label: 'مسافة',
                        value: distance,
                        color: Colors.blue.shade600,
                      ),
                    // Services
                    if (servicesCount > 0)
                      _buildStatItem(
                        icon: Icons.medical_services_rounded,
                        label: 'خدمات',
                        value: servicesCount.toString(),
                        color: Colors.purple.shade600,
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMatchScoreColor(String score) {
    final numScore = double.tryParse(score.toString().replaceAll('%', '')) ?? 0;
    if (numScore >= 80) return Colors.green.shade600;
    if (numScore >= 60) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}
