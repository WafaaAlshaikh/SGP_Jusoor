import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_service.dart';

class ChildTeamRoomScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ChildTeamRoomScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildTeamRoomScreen> createState() => _ChildTeamRoomScreenState();
}

class _ChildTeamRoomScreenState extends State<ChildTeamRoomScreen> {
  Map<String, dynamic>? _teamData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    try {
      final response = await ManagerService.getChildTeamOverview(widget.childId);
      if (response['success'] == true) {
        setState(() {
          _teamData = response['data'];
        });
      } else {
        print('Error loading team data: ${response['message']}');
        _showErrorSnackBar('Failed to load team data');
      }
    } catch (e) {
      print('Error loading team data: $e');
      _showErrorSnackBar('Network error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('فريق ${widget.childName}'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTeamData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _teamData == null
              ? Center(child: Text('لا توجد بيانات للفريق'))
              : _buildTeamContent(),
    );
  }

  Widget _buildTeamContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معلومات الفريق
          _buildTeamInfo(),
          SizedBox(height: 20),
          
          // أعضاء الفريق
          _buildTeamMembers(),
          SizedBox(height: 20),
          
          // النشاطات الحديثة
          _buildRecentActivities(),
        ],
      ),
    );
  }

  Widget _buildTeamInfo() {
    final teamInfo = _teamData!['team_info'];
    final childInfo = _teamData!['child_info'];
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'معلومات الفريق',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow('نوع الفريق', teamInfo['team_type'] == 'multidisciplinary' ? 'متعدد التخصصات' : 'متخصص'),
            _buildInfoRow('حالة الفريق', _getStatusText(teamInfo['status'])),
            _buildInfoRow('تاريخ الإنشاء', _formatDate(teamInfo['created_at'])),
            _buildInfoRow('عمر الطفل', '${childInfo['age']} سنوات'),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMembers() {
    final members = _teamData!['team_members'];
    if (members == null || members.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('لا يوجد أعضاء في الفريق بعد')),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'أعضاء الفريق (${members.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...members.map((member) => _buildTeamMemberCard(member)).toList(),
      ],
    );
  }

  Widget _buildTeamMemberCard(Map<String, dynamic> member) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // صورة الأخصائي
            CircleAvatar(
              radius: 25,
              backgroundImage: member['profile_picture'] != null && member['profile_picture'].isNotEmpty
                  ? NetworkImage(member['profile_picture'])
                  : null,
              child: member['profile_picture'] == null || member['profile_picture'].isEmpty
                  ? Icon(Icons.person, color: AppColors.textWhite)
                  : null,
            ),
            SizedBox(width: 12),
            
            // معلومات الأخصائي
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member['name'] ?? 'غير معروف',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(member['specialization'] ?? 'غير محدد'),
                  Text(
                    _getRoleText(member['role']),
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                  Text(
                    'تم التعيين: ${_formatDate(member['assigned_date'])}',
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
            ),
            
            // حالة العضوية
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getMemberStatusColor(member['status']),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getMemberStatusText(member['status']),
                style: TextStyle(color: AppColors.textWhite, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    final activities = _teamData!['recent_activities'];
    if (activities == null || activities.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('لا توجد نشاطات حديثة')),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'النشاطات الحديثة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...activities.map((activity) => _buildActivityItem(activity)).toList(),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _getActivityIcon(activity['type']),
        title: Text(activity['title'] ?? 'بدون عنوان'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(activity['description'] ?? 'لا يوجد وصف'),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 12, color: AppColors.textGray),
                SizedBox(width: 4),
                Text(
                  activity['specialist'] ?? 'النظام',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
                Spacer(),
                Icon(Icons.schedule, size: 12, color: AppColors.textGray),
                SizedBox(width: 4),
                Text(
                  _formatTime(activity['timestamp']),
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
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
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textGray),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  // دوال مساعدة
  Icon _getActivityIcon(String type) {
    switch (type) {
      case 'evaluation':
        return Icon(Icons.assessment, color: AppColors.info);
      case 'session':
        return Icon(Icons.event, color: AppColors.success);
      case 'note':
        return Icon(Icons.note, color: AppColors.warning);
      case 'recommendation':
        return Icon(Icons.lightbulb, color: AppColors.primary);
      default:
        return Icon(Icons.info, color: AppColors.textGray);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active': return 'نشط';
      case 'inactive': return 'غير نشط';
      case 'completed': return 'مكتمل';
      default: return status;
    }
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'initial_assessor': return 'مقيم أولي';
      case 'speech_specialist': return 'أخصائي نطق';
      case 'behavioral_specialist': return 'أخصائي سلوك';
      case 'occupational_specialist': return 'أخصائي وظيفي';
      default: return role;
    }
  }

  String _getMemberStatusText(String status) {
    switch (status) {
      case 'active': return 'نشط';
      case 'inactive': return 'غير نشط';
      case 'transferred': return 'منقول';
      default: return status;
    }
  }

  Color _getMemberStatusColor(String status) {
    switch (status) {
      case 'active': return AppColors.success;
      case 'inactive': return AppColors.error;
      case 'transferred': return AppColors.warning;
      default: return AppColors.textGray;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'غير محدد';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'تاريخ غير صالح';
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return 'غير محدد';
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'وقت غير صالح';
    }
  }
}