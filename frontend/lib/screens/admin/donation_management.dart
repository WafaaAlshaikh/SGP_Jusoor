// lib/screens/admin/donation_management.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DonationManagement extends StatefulWidget {
  @override
  _DonationManagementState createState() => _DonationManagementState();
}

class _DonationManagementState extends State<DonationManagement> {
  List<Map<String, dynamic>> _donations = [];
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _monthlyStats = [];
  bool _isLoading = true;
  DateTimeRange? _dateRange;
  String? _institutionFilter;

  int _currentPage = 1;
  int _totalPages = 1;

  final List<Map<String, String>> _institutions = [];

  @override
  void initState() {
    super.initState();
    _loadDonations();
    _loadSummary();
    _loadMonthlyStats();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/admin/institutions/pending?page=1&limit=100'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final institutions = data['data']['institutions'] ?? [];

        setState(() {
          _institutions.clear();
          for (var inst in institutions) {
            _institutions.add({
              'id': inst['institution_id'].toString(),
              'name': inst['name'],
            });
          }
        });
      }
    } catch (e) {
      print('Error loading institutions: $e');
    }
  }

  Future<void> _loadDonations({int page = 1}) async {
  try {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final Map<String, String> queryParams = {
      'page': page.toString(),
      'limit': '20',
    };

    if (_dateRange != null) {
      queryParams['start_date'] = _dateRange!.start.toIso8601String();
      queryParams['end_date'] = _dateRange!.end.toIso8601String();
    }
    if (_institutionFilter != null && _institutionFilter!.isNotEmpty) {
      queryParams['institution_id'] = _institutionFilter!;
    }

    print('🌐 Loading donations with params: $queryParams');

    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/api/admin/donations').replace(
        queryParameters: queryParams,
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Donations response received');

      // تحويل جميع المبالغ من String إلى double
      final donations = (data['data']['donations'] as List?)
              ?.map<Map<String, dynamic>>((donation) {
            final d = (donation as Map).cast<String, dynamic>();

            final institution = d['Institution'];
            if (institution is Map) {
              d['Institution'] = (institution as Map).cast<String, dynamic>();
            }

            return {
              ...d,
              'amount': _parseDonationTotal(d['amount']),
            };
          }).toList() ??
          [];

      setState(() {
        _donations = donations;
        _currentPage = data['data']['page'] ?? 1;
        _totalPages = data['data']['totalPages'] ?? 1;
        _isLoading = false;
      });

      print('📊 Loaded ${_donations.length} donations');
    } else {
      print('❌ Failed to load donations: ${response.statusCode}');
      setState(() => _isLoading = false);
    }
  } catch (e) {
    print('❌ Error loading donations: $e');
    setState(() => _isLoading = false);
  }
}
  Future<void> _loadSummary() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    
    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/api/admin/donations?limit=1'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('📈 Summary raw data: ${data['data']['summary']}');
      
      if (data['data'] != null && data['data']['summary'] != null) {
        final summary = data['data']['summary'];
        
        // تحويل القيم من String إلى double
        setState(() {
          _summary = {
            'total_amount': _parseDonationTotal(summary['total_amount']),
            'total_count': summary['total_count'] is String 
                ? int.tryParse(summary['total_count']) ?? 0
                : summary['total_count'] ?? 0,
            'average_donation': _parseDonationTotal(summary['average_donation']),
          };
        });
        
        print('✅ Parsed summary: $_summary');
      }
    }
  } catch (e) {
    print('❌ Error loading summary: $e');
  }
}

  // في _loadMonthlyStats() غير:
Future<void> _loadMonthlyStats() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    
    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/api/admin/detailed-stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Monthly stats raw data: $data'); // للتصحيح
      
      if (data['success'] == true && data['data'] != null) {
        final monthlyData = data['data']['monthly_donations'] ?? [];
        
        // تحويل البيانات - هنا بيت القصيد
        final processedData = (monthlyData as List).map<Map<String, dynamic>>((item) {
          return {
            'month': item['month']?.toString() ?? '',
            'total': _parseDonationTotal(item['total']), // تحويل String إلى double
          };
        }).toList();
        
        print('📊 Processed monthly data: $processedData');
        
        setState(() {
          _monthlyStats = processedData;
        });
      }
    }
  } catch (e) {
    print('❌ Error loading monthly stats: $e');
  }
}

// دالة خاصة لتحويل قيم التبرعات
double _parseDonationTotal(dynamic value) {
  if (value == null) return 0.0;
  
  print('🔍 Parsing donation value: $value (type: ${value.runtimeType})');
  
  if (value is int) {
    return value.toDouble();
  } else if (value is double) {
    return value;
  } else if (value is String) {
    // إزالة أي فواصل أو رموز غير مرغوبة
    String cleaned = value.replaceAll(',', '').trim();
    try {
      return double.parse(cleaned);
    } catch (e) {
      print('⚠️ Failed to parse string "$cleaned": $e');
      return 0.0;
    }
  }
  
  print('⚠️ Unknown value type: ${value.runtimeType}');
  return 0.0;
}

  Widget _buildDonationCard(Map<String, dynamic> donation) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${donation['amount']?.toStringAsFixed(2) ?? '0.00'} JOD',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    _getPaymentMethodText(donation['payment_method'] ?? 'unknown'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _getPaymentMethodColor(donation['payment_method'] ?? 'unknown'),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            _buildDetailRow('المؤسسة:', donation['Institution']?['name'] ?? 'غير محدد'),
            _buildDetailRow('التاريخ:', _formatDate(donation['date'])),
            _buildDetailRow('حالة الدفع:', _getPaymentStatusText(donation['payment_status'] ?? 'pending')),
            
            if (donation['donor_name'] != null)
              _buildDetailRow('المتبرع:', donation['donor_name']),
            
            if (donation['campaign_name'] != null)
              _buildDetailRow('الحملة:', donation['campaign_name']),
            
            SizedBox(height: 8),
            
            if (donation['notes'] != null && donation['notes'].isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ملاحظات: ${donation['notes']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
  // تأكد من أن القيم هي double
  final totalAmount = _summary['total_amount'] is double 
      ? _summary['total_amount'] 
      : _parseDonationTotal(_summary['total_amount']);
  
  final averageDonation = _summary['average_donation'] is double
      ? _summary['average_donation']
      : _parseDonationTotal(_summary['average_donation']);
  
  final totalCount = _summary['total_count']?.toString() ?? '0';

  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.attach_money, color: Colors.green),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي التبرعات',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${totalAmount.toStringAsFixed(2)} JOD',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'عدد التبرعات',
                totalCount,
                Icons.list,
                Colors.blue,
              ),
              _buildSummaryItem(
                'المتوسط',
                '${averageDonation.toStringAsFixed(2)} JOD',
                Icons.analytics,
                Colors.orange,
              ),
              _buildSummaryItem(
                'آخر تبرع',
                _formatRecentDate(),
                Icons.update,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMonthlyChart() {
  if (_monthlyStats.isEmpty || !(_monthlyStats is List)) {
    return SizedBox();
  }
  
  // تأكد أن _monthlyStats هي List
  final List<dynamic> monthlyData = _monthlyStats as List;
  if (monthlyData.isEmpty) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Text(
          'لا توجد بيانات شهرية متاحة',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
  
  // تحويل البيانات لـ BarChart
  final List<BarChartGroupData> barGroups = List.generate(
    monthlyData.length,
    (index) {
      final item = monthlyData[index];
      // تأكد من أن القيمة رقمية
      double value;
      try {
        final total = item['total'];
        if (total is int) {
          value = total.toDouble();
        } else if (total is double) {
          value = total;
        } else if (total is String) {
          value = double.parse(total);
        } else {
          value = 0.0;
        }
      } catch (e) {
        value = 0.0;
      }
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Colors.blue,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    },
  );
  
  // إيجاد القيمة القصوى للمحور الرأسي
  double maxValue = 0;
  for (var item in monthlyData) {
    try {
      final total = item['total'];
      double val = 0;
      if (total is int) {
        val = total.toDouble();
      } else if (total is double) {
        val = total;
      } else if (total is String) {
        val = double.tryParse(total) ?? 0;
      }
      if (val > maxValue) maxValue = val;
    } catch (e) {
      continue;
    }
  }
  
  // إنشاء تسميات المحور السيني
  final List<String> labels = monthlyData.map((item) {
    final month = item['month']?.toString() ?? '';
    if (month.length >= 7) {
      final year = month.substring(0, 4);
      final monthNum = month.substring(5, 7);
      return '$monthNum/$year';
    }
    return month;
  }).toList();
  
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'التبرعات الشهرية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue > 0 ? maxValue / 5 : 100,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        }
                        return Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final index = group.x.toInt();
                      if (index < labels.length) {
                        final month = labels[index];
                        final amount = rod.toY;
                        return BarTooltipItem(
                          '$month\n${amount.toStringAsFixed(2)} JOD',
                          TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return BarTooltipItem('', TextStyle());
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  double _calculateInterval(List<dynamic> data) {
    if (data.isEmpty) return 100;
    
    final maxValue = data.fold<double>(0, (max, item) {
      final value = double.parse(item['total']?.toString() ?? '0');
      return value > max ? value : max;
    });
    
    if (maxValue <= 0) return 100;
    
    // تقسيم القيمة القصوى إلى 5-10 أقسام
    final interval = maxValue / 5;
    return interval < 1 ? 1 : interval;
  }

  String _formatDate(String? date) {
    if (date == null) return 'غير محدد';
    try {
      final parsed = DateTime.parse(date).toLocal();
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return date;
    }
  }

  String _formatRecentDate() {
    if (_donations.isEmpty) return 'لا يوجد';
    try {
      final lastDonation = _donations[0];
      final date = lastDonation['date'];
      if (date == null) return 'غير معروف';
      
      final parsed = DateTime.parse(date).toLocal();
      final now = DateTime.now();
      final difference = now.difference(parsed);
      
      if (difference.inDays > 0) {
        return 'قبل ${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return 'قبل ${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return 'قبل ${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      return 'غير معروف';
    }
  }

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'credit_card': return 'بطاقة ائتمان';
      case 'bank_transfer': return 'تحويل بنكي';
      case 'cash': return 'نقدي';
      case 'stripe': return 'Stripe';
      case 'paypal': return 'PayPal';
      default: return method;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'credit_card': return Colors.blue;
      case 'bank_transfer': return Colors.green;
      case 'cash': return Colors.orange;
      case 'stripe': return Colors.purple;
      case 'paypal': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _getPaymentStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return 'مكتمل';
      case 'pending': return 'قيد الانتظار';
      case 'failed': return 'فشل';
      case 'refunded': return 'تم الاسترجاع';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'failed': return Colors.red;
      case 'refunded': return Colors.purple;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(minWidth: 80),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('إدارة التبرعات'),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list),
          onPressed: _showFiltersDialog,
          tooltip: 'تصفية',
        ),
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: () {
            _loadDonations();
            _loadSummary();
            _loadMonthlyStats();
          },
          tooltip: 'تحديث',
        ),
      ],
    ),
    body: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل بيانات التبرعات...'),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Summary Card
                _buildSummaryCard(),
                
                SizedBox(height: 20),
                
                // Monthly Chart
                _buildMonthlyChart(),
                
                SizedBox(height: 20),
                
                // Donations List Header
                Row(
                  children: [
                    Icon(Icons.list, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'آخر التبرعات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    Spacer(),
                    Text(
                      'الإجمالي: ${_donations.length} تبرع',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // Donations List
                _donations.isEmpty
                    ? Container(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.money_off,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد تبرعات',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'لم يتم تسجيل أي تبرعات في الفترة المحددة',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: _donations.map((donation) {
                          return _buildDonationCard(donation);
                        }).toList(),
                      ),
                
                // Pagination
                if (_totalPages > 1)
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios),
                          onPressed: _currentPage > 1
                              ? () => _loadDonations(page: _currentPage - 1)
                              : null,
                          color: _currentPage > 1 ? Colors.blue : Colors.grey,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'صفحة $_currentPage من $_totalPages',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios),
                          onPressed: _currentPage < _totalPages
                              ? () => _loadDonations(page: _currentPage + 1)
                              : null,
                          color: _currentPage < _totalPages ? Colors.blue : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                
                SizedBox(height: 40),
              ],
            ),
          ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        _exportDonationsReport();
      },
      icon: Icon(Icons.download),
      label: Text('تصدير التقرير'),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    ),
  );
}
  void _showFiltersDialog() {
    final institutionController = TextEditingController(text: _institutionFilter);
    String? selectedInstitution;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.filter_list, color: Colors.blue),
            SizedBox(width: 8),
            Text('تصفية التبرعات'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Institution Filter
              DropdownButtonFormField<String>(
                value: _institutionFilter,
                decoration: InputDecoration(
                  labelText: 'المؤسسة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('جميع المؤسسات'),
                  ),
                  ..._institutions.map((inst) {
                    return DropdownMenuItem(
                      value: inst['id'],
                      child: Text(inst['name']!),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  selectedInstitution = value;
                },
              ),
              
              SizedBox(height: 16),
              
              // Date Range
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRange ??
                        DateTimeRange(
                          start: DateTime.now().subtract(Duration(days: 30)),
                          end: DateTime.now(),
                        ),
                  );
                  if (picked != null) {
                    setState(() => _dateRange = picked);
                  }
                },
                icon: Icon(Icons.date_range),
                label: Text('اختيار نطاق تاريخي'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              
              SizedBox(height: 8),
              
              if (_dateRange != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_dateRange!.start.toLocal().toString().substring(0, 10)} - ${_dateRange!.end.toLocal().toString().substring(0, 10)}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() => _dateRange = null);
                          Navigator.pop(context);
                          _showFiltersDialog();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _institutionFilter = null;
                _dateRange = null;
              });
              _loadDonations();
              Navigator.pop(context);
            },
            child: Text('إلغاء الفلاتر'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _institutionFilter = selectedInstitution;
              });
              _loadDonations();
              Navigator.pop(context);
            },
            child: Text('تطبيق الفلاتر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _exportDonationsReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تصدير تقرير التبرعات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('تصدير كـ PDF'),
              subtitle: Text('تقرير مفصل بصيغة PDF'),
              onTap: () {
                Navigator.pop(context);
                _generatePDFReport();
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.table_chart, color: Colors.green),
              title: Text('تصدير كـ Excel'),
              subtitle: Text('بيانات قابلة للتحليل في Excel'),
              onTap: () {
                Navigator.pop(context);
                _generateExcelReport();
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.summarize, color: Colors.blue),
              title: Text('ملخص سريع'),
              subtitle: Text('مشاركة الملخص فقط'),
              onTap: () {
                Navigator.pop(context);
                _shareQuickSummary();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _generatePDFReport() {
    // TODO: Implement PDF generation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جاري إنشاء تقرير PDF...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _generateExcelReport() {
    // TODO: Implement Excel generation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جاري إنشاء ملف Excel...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareQuickSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ملخص التبرعات'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إجمالي التبرعات: ${_summary['total_amount']?.toStringAsFixed(2) ?? '0.00'} JOD'),
              Text('عدد التبرعات: ${_summary['total_count'] ?? '0'}'),
              Text('متوسط التبرع: ${_summary['average_donation']?.toStringAsFixed(2) ?? '0.00'} JOD'),
              if (_dateRange != null)
                Text('الفترة: ${_dateRange!.start.toLocal().toString().substring(0, 10)} - ${_dateRange!.end.toLocal().toString().substring(0, 10)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              // Share the summary
              Navigator.pop(context);
            },
            child: Text('مشاركة'),
          ),
        ],
      ),
    );
  }
}