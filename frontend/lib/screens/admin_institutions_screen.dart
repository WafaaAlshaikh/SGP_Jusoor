import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/admin_model.dart';

class AdminInstitutionsScreen extends StatefulWidget {
  const AdminInstitutionsScreen({super.key});

  @override
  State<AdminInstitutionsScreen> createState() => _AdminInstitutionsScreenState();
}

class _AdminInstitutionsScreenState extends State<AdminInstitutionsScreen> {
  List<Institution> _institutions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 1;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'يرجى تسجيل الدخول مرة أخرى';
          _isLoading = false;
        });
        return;
      }

      final response = await ApiService.getAdminInstitutions(
        token: token,
        page: _currentPage,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (response['success'] == true) {
        final institutionsData = response['data'] as List;
        setState(() {
          _institutions = institutionsData.map((inst) => Institution.fromJson(inst)).toList();
          _totalPages = response['pagination']?['totalPages'] ?? 1;
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load institutions');
      }
    } catch (e) {
      print('❌ Error loading institutions: $e');
      setState(() {
        _errorMessage = 'فشل في تحميل المؤسسات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveInstitution(int institutionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final success = await ApiService.approveInstitution(token, institutionId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الموافقة على المؤسسة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInstitutions();
      } else {
        throw Exception('Failed to approve institution');
      }
    } catch (e) {
      print('❌ Error approving institution: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في الموافقة على المؤسسة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRejectDialog(int institutionId, String institutionName) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('رفض المؤسسة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سبب رفض $institutionName:'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'أدخل سبب الرفض...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('يرجى إدخال سبب الرفض')),
                );
                return;
              }

              Navigator.pop(context);
              await _rejectInstitution(institutionId, reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('رفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectInstitution(int institutionId, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final success = await ApiService.rejectInstitution(token, institutionId, reason);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رفض المؤسسة بنجاح'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadInstitutions();
      } else {
        throw Exception('Failed to reject institution');
      }
    } catch (e) {
      print('❌ Error rejecting institution: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في رفض المؤسسة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInstitutionCard(Institution institution) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    institution.name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusBadge(institution.approvalStatus),
              ],
            ),
            SizedBox(height: 8),
            if (institution.description != null)
              Text(
                institution.description!,
                style: TextStyle(color: Colors.grey[600]),
              ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('${institution.city} - ${institution.region ?? ""}'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                SizedBox(width: 4),
                Text('التقييم: ${institution.rating ?? "غير متوفر"}'),
              ],
            ),
            SizedBox(height: 12),
            if (institution.approvalStatus == 'Pending') _buildPendingActions(institution),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'Approved':
        color = Colors.green;
        text = 'مفعلة';
        break;
      case 'Pending':
        color = Colors.orange;
        text = 'بانتظار المراجعة';
        break;
      case 'Rejected':
        color = Colors.red;
        text = 'مرفوضة';
        break;
      case 'Suspended':
        color = Colors.grey;
        text = 'موقوفة';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPendingActions(Institution institution) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _approveInstitution(institution.institutionId),
            icon: Icon(Icons.check, size: 18),
            label: Text('موافقة'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRejectDialog(institution.institutionId, institution.name),
            icon: Icon(Icons.close, size: 18),
            label: Text('رفض'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة المؤسسات'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInstitutions,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن مؤسسة...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                Future.delayed(Duration(milliseconds: 500), () {
                  if (_searchQuery == value) {
                    _currentPage = 1;
                    _loadInstitutions();
                  }
                });
              },
            ),
          ),

          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري تحميل المؤسسات...'),
                  ],
                ),
              ),
            )
          else if (_errorMessage.isNotEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 64),
                    SizedBox(height: 16),
                    Text(_errorMessage, textAlign: TextAlign.center),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadInstitutions,
                      child: Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          else if (_institutions.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('لا توجد مؤسسات'),
                      SizedBox(height: 8),
                      Text(
                        'سيظهر هنا المؤسسات المسجلة في النظام',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'إجمالي المؤسسات: ${_institutions.length}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'الصفحة $_currentPage من $_totalPages',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        itemCount: _institutions.length,
                        itemBuilder: (context, index) {
                          return _buildInstitutionCard(_institutions[index]);
                        },
                      ),
                    ),

                    if (_totalPages > 1) _buildPagination(),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: _currentPage > 1 ? () {
              setState(() => _currentPage--);
              _loadInstitutions();
            } : null,
          ),
          Text('الصفحة $_currentPage من $_totalPages'),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios),
            onPressed: _currentPage < _totalPages ? () {
              setState(() => _currentPage++);
              _loadInstitutions();
            } : null,
          ),
        ],
      ),
    );
  }
}