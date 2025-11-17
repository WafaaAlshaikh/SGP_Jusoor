import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/parent_api.dart';
import '../theme/app_colors.dart';

class ParentApproveSessionsScreen extends StatefulWidget {
  const ParentApproveSessionsScreen({Key? key}) : super(key: key);

  @override
  State<ParentApproveSessionsScreen> createState() =>
      _ParentApproveSessionsScreenState();
}

class _ParentApproveSessionsScreenState
    extends State<ParentApproveSessionsScreen> {
  List<dynamic> pendingSessions = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingSessions();
  }

  Future<void> _loadPendingSessions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ParentService.getNewPendingSessions();
      if (response['success'] == true) {
        setState(() {
          pendingSessions = response['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'فشل في جلب الجلسات';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'خطأ في جلب الجلسات: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _handleApproval(int sessionId, bool approve) async {
    try {
      final response = await ParentService.approveNewSession(sessionId, approve);
      if (response['success'] == true) {
        _showSuccess(
          approve ? 'تمت الموافقة على الجلسة بنجاح' : 'تم رفض الجلسة',
        );
        _loadPendingSessions();
      } else {
        _showError(response['message'] ?? 'فشل في معالجة الطلب');
      }
    } catch (e) {
      _showError('خطأ: ${e.toString()}');
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
          'الموافقة على الجلسات',
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
        onRefresh: _loadPendingSessions,
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
                          onPressed: _loadPendingSessions,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : pendingSessions.isEmpty
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
                              'لا توجد جلسات معلقة',
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
                        itemCount: pendingSessions.length,
                        itemBuilder: (context, index) {
                          final session = pendingSessions[index];
                          return _buildSessionCard(session);
                        },
                      ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final sessionId = session['session_id'] as int;
    final child = session['child'];
    final specialist = session['specialist'];
    final institution = session['institution'];
    final sessionType = session['SessionType'];
    final date = session['date'] ?? '';
    final time = session['time'] ?? '';

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
                if (child != null && child['photo'] != null)
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(child['photo']),
                  )
                else
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.child_care),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child != null ? child['full_name'] ?? 'غير معروف' : 'غير معروف',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (specialist != null)
                        Text(
                          'المختص: ${specialist['full_name'] ?? 'غير معروف'}',
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                          ),
                        ),
                    ],
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
                    'بانتظار الموافقة',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sessionType != null) _buildInfoRow('نوع الجلسة', sessionType['name'] ?? ''),
            if (sessionType != null)
              _buildInfoRow('المدة', '${sessionType['duration'] ?? 0} دقيقة'),
            if (sessionType != null)
              _buildInfoRow('السعر', '${sessionType['price'] ?? 0} دينار'),
            if (institution != null)
              _buildInfoRow('المؤسسة', institution['name'] ?? ''),
            _buildInfoRow('التاريخ', date),
            _buildInfoRow('الوقت', time),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApproval(sessionId, false),
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
                    onPressed: () => _handleApproval(sessionId, true),
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
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

