import 'package:flutter/material.dart';
import '../services/manager_api.dart';
import '../theme/app_colors.dart';

class ManagerApproveSessionTypesScreen extends StatefulWidget {
  const ManagerApproveSessionTypesScreen({Key? key}) : super(key: key);

  @override
  State<ManagerApproveSessionTypesScreen> createState() =>
      _ManagerApproveSessionTypesScreenState();
}

class _ManagerApproveSessionTypesScreenState
    extends State<ManagerApproveSessionTypesScreen> {
  List<dynamic> pendingSessionTypes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingSessionTypes();
  }

  Future<void> _loadPendingSessionTypes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ManagerService.getPendingSessionTypes();
      if (response['success'] == true) {
        setState(() {
          pendingSessionTypes = response['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'فشل في جلب أنواع الجلسات';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'خطأ في جلب أنواع الجلسات: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _approveSessionType(int sessionTypeId) async {
    try {
      final response = await ManagerService.approveSessionType(sessionTypeId);
      if (response['success'] == true) {
        _showSuccess('تمت الموافقة على نوع الجلسة بنجاح');
        _loadPendingSessionTypes();
      } else {
        _showError(response['message'] ?? 'فشل في الموافقة');
      }
    } catch (e) {
      _showError('خطأ: ${e.toString()}');
    }
  }

  Future<void> _rejectSessionType(int sessionTypeId) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض نوع الجلسة'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض (اختياري)',
            hintText: 'أدخل سبب الرفض...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final response = await ManagerService.rejectSessionType(
          sessionTypeId,
          reason: result.isEmpty ? null : result,
        );
        if (response['success'] == true) {
          _showSuccess('تم رفض نوع الجلسة بنجاح');
          _loadPendingSessionTypes();
        } else {
          _showError(response['message'] ?? 'فشل في الرفض');
        }
      } catch (e) {
        _showError('خطأ: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'الموافقة على أنواع الجلسات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPendingSessionTypes,
        color: AppColors.primary,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPendingSessionTypes,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : pendingSessionTypes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: AppColors.success,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لا توجد طلبات معلقة',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pendingSessionTypes.length,
                        itemBuilder: (context, index) {
                          final sessionType = pendingSessionTypes[index];
                          return _buildSessionTypeCard(sessionType);
                        },
                      ),
      ),
    );
  }

  Widget _buildSessionTypeCard(Map<String, dynamic> sessionType) {
    final sessionTypeId = sessionType['session_type_id'] as int;
    final name = sessionType['name'] ?? '';
    final duration = sessionType['duration'] ?? 0;
    final price = sessionType['price'] ?? 0;
    final category = sessionType['category'] ?? '';
    final specialist = sessionType['created_by_specialist'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'معلق',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('المدة', '$duration دقيقة'),
            _buildInfoRow('السعر', '$price دينار'),
            _buildInfoRow('الفئة', category),
            if (specialist != null)
              _buildInfoRow(
                'طلب من',
                specialist['full_name'] ?? 'غير معروف',
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectSessionType(sessionTypeId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'رفض',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveSessionType(sessionTypeId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'موافقة',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

