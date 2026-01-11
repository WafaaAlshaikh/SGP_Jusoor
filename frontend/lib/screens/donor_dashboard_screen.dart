import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/equipment_donation_screen.dart';
import 'package:frontend/screens/equipment_campaigns_screen.dart';
import '../theme/app_colors.dart';
import 'browse_centers_screen.dart';
import 'donation_screen.dart';
import 'reports_list_screen.dart';
import '../services/api_service.dart';
import '../services/reports_service.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen> {

  bool _isLoadingImpact = false;
  String? _impactError;
  Map<String, dynamic>? _impactV2;
  List<Map<String, dynamic>> _impactFeedItems = [];
  int _impactFeedPage = 1;
  bool _impactFeedHasMore = false;
  String _authToken = '';
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserImpact();
    _loadUserData();
  }

  Future<void> _loadUserImpact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ?? '').trim();
      _authToken = token;

      if (token.isEmpty) {
        setState(() {
          _impactV2 = null;
          _impactFeedItems = [];
          _isLoadingImpact = false;
        });
        return;
      }

      setState(() {
        _isLoadingImpact = true;
        _impactError = null;
      });

      final v2 = await ApiService.getDonationImpactV2(token);
      final feed = await ApiService.getDonorImpactFeed(token, page: 1, limit: 6);

      final v2Data = (v2['data'] is Map)
          ? Map<String, dynamic>.from(v2['data'] as Map)
          : <String, dynamic>{};
      final feedData = (feed['data'] is Map)
          ? Map<String, dynamic>.from(feed['data'] as Map)
          : <String, dynamic>{};
      final items = (feedData['items'] is List)
          ? (feedData['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      final pagination = (feedData['pagination'] is Map)
          ? Map<String, dynamic>.from(feedData['pagination'] as Map)
          : <String, dynamic>{};
      final totalPages = (pagination['totalPages'] is int)
          ? pagination['totalPages'] as int
          : int.tryParse('${pagination['totalPages'] ?? ''}') ?? 1;
      final page = (pagination['page'] is int)
          ? pagination['page'] as int
          : int.tryParse('${pagination['page'] ?? ''}') ?? 1;

      setState(() {
        _impactV2 = v2Data;
        _impactFeedItems = items;
        _impactFeedPage = page;
        _impactFeedHasMore = page < totalPages;
        _isLoadingImpact = false;
      });
    } catch (e) {
      setState(() {
        _impactV2 = null;
        _impactFeedItems = [];
        _impactFeedPage = 1;
        _impactFeedHasMore = false;
        _impactError = 'Failed to load impact';
        _isLoadingImpact = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ?? '').trim();
      
      if (token.isEmpty) {
        setState(() {
          _userData = null;
        });
        return;
      }
      
      // استدعاء API جديد لجلب بيانات المستخدم
      final response = await ApiService.getDonorProfile(token);
      
      if (response['success'] == true) {
        final data = (response['data'] is Map)
            ? Map<String, dynamic>.from(response['data'] as Map)
            : <String, dynamic>{};
        
        setState(() {
          _userData = data;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userData = null;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else {
      dt = DateTime.tryParse(value.toString());
    }
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _extractImpactMediaUrl(Map<String, dynamic> p) {
    final cover = (p['cover_url'] ?? '').toString().trim();
    if (cover.isNotEmpty) return cover;
    final media = p['media_urls'];
    if (media is List && media.isNotEmpty) {
      return (media.first ?? '').toString().trim();
    }
    if (media is String) return media.trim();
    return '';
  }

  bool _isDirectVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.mp4') || u.endsWith('.webm') || u.endsWith('.mov') || u.endsWith('.mkv');
  }

  bool _isLikelyVideoLink(String url) {
    final u = url.toLowerCase();
    if (_isDirectVideoUrl(u)) return true;
    return u.contains('youtube.com') || u.contains('youtu.be') || u.contains('vimeo.com');
  }

  Future<void> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore
    }
  }

  Widget _buildImpactMediaPreview(Map<String, dynamic> p) {
    final url = _extractImpactMediaUrl(p);
    if (url.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(child: Icon(Icons.photo, color: Colors.grey)),
      );
    }

    final fullUrl = ApiService.buildFileUrl(url);

    if (_isDirectVideoUrl(fullUrl)) {
      return SizedBox(
        height: 70,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _InlineVideoPreview(url: fullUrl),
        ),
      );
    }

    if (_isLikelyVideoLink(fullUrl)) {
      return GestureDetector(
        onTap: () => _openExternalUrl(fullUrl),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        fullUrl,
        height: 70,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          );
        },
      ),
    );
  }

  Widget _buildImpactSection() {
    if (_authToken.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.grey),
                const SizedBox(width: 10),
                const Text(
                  'Your Impact',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Login to track your donation impact',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final moneyImpact = (_impactV2?['money_impact'] is Map)
        ? Map<String, dynamic>.from(_impactV2!['money_impact'] as Map)
        : <String, dynamic>{};
    final equipmentImpact = (_impactV2?['equipment_impact'] is Map)
        ? Map<String, dynamic>.from(_impactV2!['equipment_impact'] as Map)
        : <String, dynamic>{};

    final moneyTimeline = (moneyImpact['timeline'] is List)
        ? (moneyImpact['timeline'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : <Map<String, dynamic>>[];
    final equipmentTimeline = (equipmentImpact['timeline'] is List)
        ? (equipmentImpact['timeline'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : <Map<String, dynamic>>[];

    final combinedTimeline = [
      ...moneyTimeline.map((e) => {...e, 'timeline_type': 'money'}),
      ...equipmentTimeline.map((e) => {...e, 'timeline_type': 'equipment'})
    ]..sort((a, b) {
        final ad = DateTime.tryParse('${a['date'] ?? a['created_at'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
        final bd = DateTime.tryParse('${b['date'] ?? b['created_at'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
        return bd.compareTo(ad);
      });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Your Impact',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (_isLoadingImpact)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _loadUserImpact,
                  icon: const Icon(Icons.refresh, size: 20),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if ((_impactError ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _impactError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 12),

          // Money Impact Stats
          const Text(
            'Money Donations',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _impactKpiTile(
                  title: 'Donated',
                  value: '${_toDouble(moneyImpact['totalDonationsAmount']).toStringAsFixed(0)} JOD',
                  icon: Icons.attach_money,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _impactKpiTile(
                  title: 'Allocated',
                  value: '${_toDouble(moneyImpact['totalAllocatedAmount']).toStringAsFixed(0)} JOD',
                  icon: Icons.receipt_long,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _impactKpiTile(
                  title: 'Sessions',
                  value: _toInt(moneyImpact['sessionsSupportedCount']).toString(),
                  icon: Icons.event_available,
                  color: AppColors.accent3,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _impactKpiTile(
                  title: 'Children',
                  value: _toInt(moneyImpact['childrenSupportedCount']).toString(),
                  icon: Icons.child_care,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Equipment Impact Stats
          const Text(
            'Equipment Donations',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _impactKpiTile(
                  title: 'Donated',
                  value: _toInt(equipmentImpact['total_count']).toString(),
                  icon: Icons.medical_services,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _impactKpiTile(
                  title: 'Allocated',
                  value: _toInt(equipmentImpact['allocated_count']).toString(),
                  icon: Icons.inventory_2,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _impactKpiTile(
                  title: 'Needs Supported',
                  value: _toInt(equipmentImpact['needs_supported_count']).toString(),
                  icon: Icons.assignment_turned_in,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _impactKpiTile(
                  title: 'Children',
                  value: _toInt(equipmentImpact['children_supported_count']).toString(),
                  icon: Icons.family_restroom,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Recent Activity
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (combinedTimeline.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No impact activity yet. Start donating to see your impact.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Column(
              children: combinedTimeline.take(4).map((e) {
                final type = (e['timeline_type'] ?? '').toString();
                final title = type == 'money'
                    ? 'Donation allocated'
                    : (e['event_type']?.toString() == 'equipment_allocated'
                        ? 'Equipment allocated'
                        : e['event_type']?.toString() == 'inventory_added'
                            ? 'Equipment added to inventory'
                            : 'Equipment donation');
                final date = _formatDate(e['date'] ?? e['created_at']);
                final subtitle = type == 'money'
                    ? (e['child_name'] != null
                        ? 'Child: ${e['child_name']}'
                        : (e['session_type'] != null ? 'Session: ${e['session_type']}' : ''))
                    : (e['equipment_name'] != null
                        ? 'Item: ${e['equipment_name']}'
                        : '');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: type == 'money'
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.purple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          type == 'money' ? Icons.attach_money : Icons.medical_services,
                          size: 16,
                          color: type == 'money' ? AppColors.primary : Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (subtitle.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subtitle,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        date,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          if (_impactFeedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Latest Stories',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _impactFeedItems.length,
                itemBuilder: (context, index) {
                  final p = _impactFeedItems[index];
                  final title = (p['title'] ?? '').toString();
                  final content = (p['content'] ?? '').toString();
                  final inst = (p['institution'] is Map)
                      ? Map<String, dynamic>.from(p['institution'] as Map)
                      : null;
                  final instName = (inst?['name'] ?? '').toString();
                  final date = _formatDate(p['published_at'] ?? p['created_at']);

                  // داخل Container الذي عرضه 240
return Container(
  width: 240,
  child: Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // الصورة بارتفاع محدود
          SizedBox(
            height: 80,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImpactMediaPreview(p),
            ),
          ),
          const SizedBox(height: 10),
          
          // النصوص فقط بدون توسع
          Text(
            title.isEmpty ? 'Update' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          
          Text(
            content.isNotEmpty ? content : 'New impact update.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  instName.isEmpty ? 'Institution' : instName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              Text(
                date,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
                },
              ),
            ),
          ],

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DonationScreen()),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See All Institutions'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _simpleLogout(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _simpleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

 Widget _buildProfileHeader() {
  final topPadding = MediaQuery.of(context).padding.top;
  final screenHeight = MediaQuery.of(context).size.height;
  
  return SizedBox(
    height: screenHeight * 0.5, // استخدم نسبة من ارتفاع الشاشة بدلاً من قيمة ثابتة
    child: Stack(
      children: [
        // الخلفية المنحنية - تبدأ من بداية الصفحة
        Positioned.fill(
          child: ClipPath(
            clipper: CurvedBackgroundClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.accent1,
                  ],
                ),
              ),
            ),
          ),
        ),

        // المحتوى - استخدم SingleChildScrollView لتفادي الـ overflow
        Positioned.fill(
          top: 40 + topPadding,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80), // مساحة للـ stats card
            physics: const NeverScrollableScrollPhysics(), // منع التمرير داخل هذا الجزء
            child: Column(
              mainAxisSize: MainAxisSize.min, // مهم لمنع التمدد الزائد
              children: [
                // صورة
                // Container(
                //   padding: const EdgeInsets.all(4),
                //   decoration: const BoxDecoration(
                //     color: Colors.white,
                //     shape: BoxShape.circle,
                //   ),
                //   child: CircleAvatar(
                //     radius: 42,
                //     backgroundColor: Colors.white,
                //     backgroundImage: _authToken.isNotEmpty
                //         ? const AssetImage('assets/images/jusoor_logo.png')
                //         : const AssetImage('assets/images/jusoor_logo.png') as ImageProvider,
                //   ),
                // ),

                // صورة donor عادية بدون دائرة
Container(
  // width: 120, // عرض الصورة حسب الحجم اللي بدك إياه
  // height: 120, // ارتفاع الصورة
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(8), // اختياري: حواف مدوّرة خفيفة
    // color: Colors.white.withOpacity(0.1), // خلفية خفيفة إذا بدك
  ),
  child: Image.asset(
    'assets/images/donors.png', // اسم الصورة اللي رفعتها
    fit: BoxFit.cover, // تغطية كامل الـ Container
  ),
),


                const SizedBox(height: 5),

                // Text(
                //   _authToken.isNotEmpty ? 'Jusoor Donor' : 'Guest User',
                //   style: const TextStyle(
                //     color: Colors.white,
                //     fontSize: 18,
                //     fontWeight: FontWeight.w800,
                //   ),
                // ),

                // const SizedBox(height: 4),

                // Text(
                //   _authToken.isNotEmpty ? 'Making impact every day' : 'Login to start donating',
                //   style: TextStyle(
                //     color: Colors.white.withOpacity(0.85),
                //     fontSize: 13,
                //   ),
                // ),

                // const SizedBox(height: 30),

                const SizedBox(height: 14),
                
                // زر للتبرع السريع إذا كان المستخدم مسجلاً
                if (_authToken.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BrowseCentersScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.volunteer_activism, size: 18),
                      label: const Text('Make a Donation', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Circle info icons على طرف الـ curve
Positioned(
  bottom: 60, // 👈 تحكمي بالارتفاع (زيدي/قللي حسب الذوق)
  left: 0,
  right: 0,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _buildCircleInfoItem(
        icon: Icons.email_outlined,
        value: _userData?['email'] ?? 'Email',
      ),
      _buildCircleInfoItem(
        icon: Icons.phone_outlined,
        value: _userData?['phone'] ?? 'Phone',
      ),
      _buildCircleInfoItem(
        icon: Icons.location_on_outlined,
        value: _userData?['city'] ?? 'Location',
      ),
    ],
  ),
),


      ],
    ),
  );
}

 Widget _buildUserInfoItem({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: value != 'Not available' ? Colors.white : Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCircleInfoItem({
  required IconData icon,
  required String value,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(40),
    child: Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 90,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildMotivationCard() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 24),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.favorite,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
  child: Text(
    "Your support can bring hope, joy, and a brighter future to children with special needs. Every donation, big or small, makes a real difference in their lives! ✨💖",
    style: TextStyle(
      fontFamily: 'Arial',   // أو 'Roboto'
      fontSize: 14,          // أكبر شوية للراحة
      fontWeight: FontWeight.w600,
      height: 1.5,           // زيادة المسافة بين الأسطر
      color: Colors.black87, // لون مناسب للنصوص الطويلة
    ),
  ),
),

      ],
    ),
  );
}

Widget _buildYourImpactSection() {
  // استخدام نفس البيانات من _impactV2
  final moneyImpact = (_impactV2?['money_impact'] is Map)
      ? Map<String, dynamic>.from(_impactV2!['money_impact'] as Map)
      : <String, dynamic>{};
  final equipmentImpact = (_impactV2?['equipment_impact'] is Map)
      ? Map<String, dynamic>.from(_impactV2!['equipment_impact'] as Map)
      : <String, dynamic>{};

  // حساب الإجماليات
  final totalDonations = _toDouble(moneyImpact['totalDonationsAmount']) + _toDouble(moneyImpact['totalAllocatedAmount']);
  final totalChildren = _toInt(moneyImpact['childrenSupportedCount']) + _toInt(equipmentImpact['children_supported_count']);
  final totalEquipment = _toInt(equipmentImpact['total_count']);
  final totalFamilies = _toInt(moneyImpact['familiesSupportedCount'] ?? 0) + _toInt(equipmentImpact['families_supported_count'] ?? 0);

  // حساب timeline (نفس الكود من _buildImpactSection)
  final moneyTimeline = (moneyImpact['timeline'] is List)
      ? (moneyImpact['timeline'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
      : <Map<String, dynamic>>[];
  final equipmentTimeline = (equipmentImpact['timeline'] is List)
      ? (equipmentImpact['timeline'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
      : <Map<String, dynamic>>[];

  final combinedTimeline = [
    ...moneyTimeline.map((e) => {...e, 'timeline_type': 'money'}),
    ...equipmentTimeline.map((e) => {...e, 'timeline_type': 'equipment'})
  ]..sort((a, b) {
      final ad = DateTime.tryParse('${a['date'] ?? a['created_at'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
      final bd = DateTime.tryParse('${b['date'] ?? b['created_at'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
      return bd.compareTo(ad);
    });

  // حساب نسبة التقدم (هدف افتراضي 100 عائلة)
  final goalProgress = totalFamilies / 100.0;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header مع زر التحديث
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.03),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Your Impact',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_isLoadingImpact)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_authToken.isNotEmpty)
                IconButton(
                  onPressed: _loadUserImpact,
                  icon: Icon(Icons.refresh, size: 20, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),

        if (_authToken.isEmpty)
          // حالة المستخدم غير المسجل
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 50,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Login to track your impact',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sign In to Continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else
          // محتوى للمستخدم المسجل
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أرقام التأثير
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _impactItem(
                      icon: Icons.attach_money,
                      value: '${totalDonations.toStringAsFixed(0)}',
                      label: 'JOD Donated',
                      color: AppColors.primary,
                    ),
                    _impactItem(
                      icon: Icons.groups,
                      value: totalFamilies.toString(),
                      label: 'Families',
                      color: Colors.green,
                    ),
                    _impactItem(
                      icon: Icons.inventory_2,
                      value: totalEquipment.toString(),
                      label: 'Items',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),

              // شريط التقدم
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              //   decoration: BoxDecoration(
              //     color: AppColors.primary.withOpacity(0.03),
              //     border: Border(
              //       top: BorderSide(color: Colors.grey.withOpacity(0.1)),
              //       bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
              //     ),
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         // children: [
              //         //   Text(
              //         //     'Impact Goal: Help 100 families',
              //         //     style: TextStyle(
              //         //       fontSize: 13,
              //         //       color: Colors.grey[700],
              //         //       fontWeight: FontWeight.w600,
              //         //     ),
              //         //   ),
              //         //   Text(
              //         //     '${(goalProgress * 100).toStringAsFixed(1)}%',
              //         //     style: TextStyle(
              //         //       fontSize: 14,
              //         //       color: AppColors.primary,
              //         //       fontWeight: FontWeight.w800,
              //         //     ),
              //         //   ),
              //         // ],
              //       ),
              //       const SizedBox(height: 8),
              //       ClipRRect(
              //         borderRadius: BorderRadius.circular(10),
              //         child: LinearProgressIndicator(
              //           value: goalProgress.clamp(0.0, 1.0),
              //           minHeight: 10,
              //           backgroundColor: Colors.grey[200],
              //           valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       Text(
              //         _getProgressMessage(goalProgress),
              //         style: TextStyle(
              //           fontSize: 12,
              //           color: Colors.grey[600],
              //           fontStyle: FontStyle.italic,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

              // Recent Activity
              if (combinedTimeline.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: combinedTimeline.take(3).map((e) {
                          final type = (e['timeline_type'] ?? '').toString();
                          final title = type == 'money'
                              ? 'Donation allocated'
                              : (e['event_type']?.toString() == 'equipment_allocated'
                                  ? 'Equipment allocated'
                                  : e['event_type']?.toString() == 'inventory_added'
                                      ? 'Equipment added to inventory'
                                      : 'Equipment donation');
                          final date = _formatDate(e['date'] ?? e['created_at']);
                          final subtitle = type == 'money'
                              ? (e['child_name'] != null
                                  ? 'Child: ${e['child_name']}'
                                  : (e['session_type'] != null
                                      ? 'Session: ${e['session_type']}'
                                      : ''))
                              : (e['equipment_name'] != null
                                  ? 'Item: ${e['equipment_name']}'
                                  : '');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: type == 'money'
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.purple.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    type == 'money' ? Icons.attach_money : Icons.medical_services,
                                    size: 18,
                                    color: type == 'money' ? AppColors.primary : Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (subtitle.trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            subtitle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

              // Latest Stories
              if (_impactFeedItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.article,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Latest Stories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _impactFeedItems.length,
                          itemBuilder: (context, index) {
                            final p = _impactFeedItems[index];
                            final title = (p['title'] ?? '').toString();
                            final content = (p['content'] ?? '').toString();
                            final inst = (p['institution'] is Map)
                                ? Map<String, dynamic>.from(p['institution'] as Map)
                                : null;
                            final instName = (inst?['name'] ?? '').toString();
                            final date = _formatDate(p['published_at'] ?? p['created_at']);

                            return Container(
  width: 280, // 👈 زيد العرض شوي
  height: 200, // 👈 حدد ارتفاع ثابت للبطاقة
  margin: EdgeInsets.only(
    right: index == _impactFeedItems.length - 1 ? 0 : 16,
  ),
  child: Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media Preview - ارتفاع ثابت
        SizedBox(
          height: 90, // 👈 زيد ارتفاع الصورة/الفيديو
          width: double.infinity,
          child: _buildImpactMediaPreview(p),
        ),
        
        // المحتوى النصي مع مساحة محددة
        Expanded( // 👈 استخدم Expanded للجزء النصي
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // 👈 وزع المساحة
              children: [
                // العنوان
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.newspaper,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Impact Update' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // المحتوى
                Expanded( // 👈 محتوى قابل للتوسع
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      content.isNotEmpty ? content : 'New impact story from our community.',
                      maxLines: 3, // 👈 رجع 3 أسطر
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12.0,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                
                // المعلومات السفلية
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        instName.isEmpty ? 'Institution' : instName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 10.0,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // Empty States
              if (combinedTimeline.isEmpty && _impactFeedItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_emotions_outlined,
                        size: 50,
                        color: Colors.grey.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Start donating to see your impact!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your first donation will appear here',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

// دالة مساعدة للرسائل التحفيزية
String _getProgressMessage(double progress) {
  if (progress == 0) return 'Start your impact journey today! 🚀';
  if (progress < 0.3) return 'Every donation starts with a single step 💙';
  if (progress < 0.7) return 'You\'re making amazing progress! Keep going 🌟';
  if (progress < 1) return 'Almost there! You\'re changing lives ✨';
  return 'Goal achieved! You\'re a true hero! 🎉';
}

Widget _impactItem({
  required IconData icon,
  required String value,
  required String label,
  required Color color,
}) {
  return Container(
    width: 95,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Donor Dashboard'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Donations'),
                  content: const Text(
                    'Your donations help support children\'s therapy sessions. '
                    'You can donate to specific campaigns or to the general fund. '
                    'All donations are processed securely through Stripe.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        children: [
          // Header الجديد
          _buildProfileHeader(),

          const SizedBox(height: 15),


          _buildMotivationCard(),
          const SizedBox(height: 24),

          // Impact Section
          // _buildImpactSection(),

          // const SizedBox(height: 24),

          _buildYourImpactSection(),

const SizedBox(height: 24),

          // Dashboard Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intro Card
                // Container(
                //   padding: const EdgeInsets.all(16),
                //   decoration: BoxDecoration(
                //     gradient: LinearGradient(
                //       colors: [
                //         AppColors.primary.withOpacity(0.12),
                //         AppColors.accent1.withOpacity(0.45),
                //     ],
                //     ),
                //     borderRadius: BorderRadius.circular(18),
                //   ),
                //   child: const Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(
                //         'Support Families, Change Lives',
                //         style: TextStyle(
                //           fontSize: 18,
                //           fontWeight: FontWeight.w800,
                //         ),
                //       ),
                //       SizedBox(height: 6),
                //       Text(
                //         'Browse institutions and donate to impactful programs.',
                //       ),
                //     ],
                //   ),
                // ),

                const SizedBox(height: 22),

                // Action Cards
                _ActionCard(
                  icon: Icons.apartment,
                  title: 'Browse Institutions',
                  subtitle: 'Explore institutions and reviews',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BrowseCentersScreen()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                _ActionCard(
                  icon: Icons.flag_outlined,
                  title: 'All Reports',
                  subtitle: 'Browse all community reports',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportsListScreen(
                          scope: ReportsScope.user,
                          title: 'All Reports',
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                _ActionCard(
                  icon: Icons.volunteer_activism,
                  title: 'Equipment Campaigns',
                  subtitle: 'View active equipment campaigns',
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EquipmentCampaignsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Logout
                InkWell(
                  onTap: () => _showLogoutDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 12),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineVideoPreview extends StatefulWidget {
  final String url;

  const _InlineVideoPreview({required this.url});

  @override
  State<_InlineVideoPreview> createState() => _InlineVideoPreviewState();
}

class _InlineVideoPreviewState extends State<_InlineVideoPreview> {
  VideoPlayerController? _controller;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final uri = Uri.parse(widget.url);
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controller = null;
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Container(
        color: Colors.black.withOpacity(0.08),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black.withOpacity(0.08),
        child: const Center(child: Icon(Icons.play_arrow, color: Colors.white)),
      );
    }

    final isPlaying = _controller!.value.isPlaying;

    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        setState(() {
          if (isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clipper للمنحدر (نص دائرة)
class CurvedBackgroundClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {

    final path = Path();

    path.moveTo(0, 0);
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width / 2,
      size.height * 0.9,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Card Component
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }
}