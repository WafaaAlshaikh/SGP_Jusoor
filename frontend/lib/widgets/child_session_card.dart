// lib/widgets/child_session_card.dart
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../utils/app_colors.dart';

class ChildSessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;

  const ChildSessionCard({
    super.key,
    required this.session,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status and date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusChip(session.displayStatus),
                    Text(
                      '${session.date} • ${session.time}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Session type
                Text(
                  session.sessionType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Specialist
                _buildDetailRow(
                  icon: Icons.person,
                  text: 'Specialist: ${session.specialistName}',
                ),

                // Institution
                _buildDetailRow(
                  icon: Icons.local_hospital,
                  text: 'Institution: ${session.institutionName}',
                ),

                // Location
                _buildDetailRow(
                  icon: Icons.location_on,
                  text: session.sessionLocation,
                ),

                const SizedBox(height: 8),

                // Duration and Price
                Row(
                  children: [
                    _buildDetailChip(Icons.timer, '${session.duration} min'),
                    const SizedBox(width: 8),
                    if (session.sessionTypePrice > 0)
                      _buildDetailChip(
                        Icons.attach_money,
                        '\$${session.sessionTypePrice.toStringAsFixed(2)}',
                      ),
                  ],
                ),

                // Rating for completed sessions
                if (session.displayStatus == 'completed' && session.rating != null) ...[
                  const SizedBox(height: 8),
                  _buildRatingRow(session.rating!),
                ],
              ],
            ),
          ),
        ),
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

  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(double rating) {
    return Row(
      children: [
        const Icon(Icons.star, size: 14, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          '$rating/5',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          return Icon(
            Icons.star,
            size: 14,
            color: index < rating.floor() ? Colors.amber : Colors.grey[300],
          );
        }),
      ],
    );
  }
}