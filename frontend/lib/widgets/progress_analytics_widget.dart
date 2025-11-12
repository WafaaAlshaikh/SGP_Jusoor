import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';

class ProgressAnalyticsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> evaluations;
  final String childName;

  const ProgressAnalyticsWidget({
    Key? key,
    required this.evaluations,
    required this.childName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (evaluations.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 20),
          _buildStatsSummary(),
          SizedBox(height: 25),
          _buildProgressChart(),
          SizedBox(height: 20),
          _buildTrendIndicator(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.trending_up,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progress Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                childName,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary() {
    final stats = _calculateStats();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Average',
            '${stats['average']?.toStringAsFixed(1)}%',
            Icons.analytics,
            AppColors.primary,
          ),
          _buildStatItem(
            'Highest',
            '${stats['highest']?.toStringAsFixed(0)}%',
            Icons.arrow_upward,
            Colors.green,
          ),
          _buildStatItem(
            'Latest',
            '${stats['latest']?.toStringAsFixed(0)}%',
            Icons.access_time,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChart() {
    final chartData = _prepareChartData();
    
    return Container(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[200]!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= chartData.length) return Text('');
                  final eval = chartData[value.toInt()];
                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      eval['label'],
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (chartData.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: chartData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value['score']);
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.5),
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppColors.primary,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator() {
    final trend = _calculateTrend();
    final isPositive = trend >= 0;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isPositive ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_flat,
            color: isPositive ? Colors.green : Colors.orange,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? 'Great Progress! 🎉' : 'Keep Going! 💪',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                Text(
                  isPositive
                      ? 'Progress improved by ${trend.abs().toStringAsFixed(1)}% from previous evaluation'
                      : 'Progress is steady. Continue with current therapy plan',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 60,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Evaluation Data Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Progress analytics will appear here once evaluations are added',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Map<String, double> _calculateStats() {
    if (evaluations.isEmpty) {
      return {'average': 0, 'highest': 0, 'latest': 0};
    }

    double total = 0;
    double highest = 0;
    double latest = 0;

    for (var i = 0; i < evaluations.length; i++) {
      final score = _getNumericScore(evaluations[i]['progress_score']);
      total += score;
      if (score > highest) highest = score;
      if (i == evaluations.length - 1) latest = score;
    }

    return {
      'average': total / evaluations.length,
      'highest': highest,
      'latest': latest,
    };
  }

  List<Map<String, dynamic>> _prepareChartData() {
    return evaluations.asMap().entries.map((entry) {
      final index = entry.key;
      final eval = entry.value;
      
      return {
        'label': 'E${index + 1}',
        'score': _getNumericScore(eval['progress_score']),
      };
    }).toList();
  }

  double _calculateTrend() {
    if (evaluations.length < 2) return 0;
    
    final latest = _getNumericScore(evaluations.last['progress_score']);
    final previous = _getNumericScore(evaluations[evaluations.length - 2]['progress_score']);
    
    return latest - previous;
  }

  double _getNumericScore(dynamic score) {
    if (score == null) return 0;
    if (score is num) return score.toDouble();
    
    String scoreStr = score.toString().toLowerCase();
    if (scoreStr.contains('excellent') || scoreStr.contains('ممتاز')) return 90;
    if (scoreStr.contains('very good') || scoreStr.contains('جيد جدا')) return 80;
    if (scoreStr.contains('good') || scoreStr.contains('جيد')) return 70;
    if (scoreStr.contains('fair') || scoreStr.contains('مقبول')) return 60;
    if (scoreStr.contains('poor') || scoreStr.contains('ضعيف')) return 40;
    
    try {
      return double.parse(scoreStr.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      return 0;
    }
  }
}
