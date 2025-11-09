// lib/screens/manage_children/widgets/child_summary_stats.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class ChildSummaryStats extends StatefulWidget {
  final List<dynamic> childrenList;

  const ChildSummaryStats({super.key, required this.childrenList});

  @override
  State<ChildSummaryStats> createState() => _ChildSummaryStatsState();
}

class _ChildSummaryStatsState extends State<ChildSummaryStats> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final stats = await ApiService.getChildStatistics(token);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalChildren = _stats['totalChildren'] ?? 0;
    final activeChildren = _stats['activeChildren'] ?? 0;
    final boys = _stats['byGender']?['Male'] ?? 0;
    final girls = _stats['byGender']?['Female'] ?? 0;

    if (_isLoading) {
      return _buildLoadingCard();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Colors.grey.shade500,
                  size: 18,
                ),
                onPressed: _fetchStats,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats Grid
          Row(
            children: [
              // Total Children
              Expanded(
                child: _buildStatItem(
                  totalChildren.toString(),
                  'Total',
                  Icons.people_alt_outlined,
                  Theme.of(context).primaryColor,
                ),
              ),

              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),

              // Active Children
              Expanded(
                child: _buildStatItem(
                  activeChildren.toString(),
                  'Active',
                  Icons.check_circle_outline_rounded,
                  Colors.green.shade600,
                ),
              ),

              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),

              // Boys
              Expanded(
                child: _buildStatItem(
                  boys.toString(),
                  'Boys',
                  Icons.face_outlined,
                  Colors.blue.shade600,
                ),
              ),

              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),

              // Girls
              Expanded(
                child: _buildStatItem(
                  girls.toString(),
                  'Girls',
                  Icons.face_3_outlined,
                  Colors.pink.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}