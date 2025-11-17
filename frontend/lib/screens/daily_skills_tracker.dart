import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

class DailySkillsTracker extends StatefulWidget {
  final String? childId;
  final String? childName;

  const DailySkillsTracker({super.key, this.childId, this.childName});

  @override
  State<DailySkillsTracker> createState() => _DailySkillsTrackerState();
}

class _DailySkillsTrackerState extends State<DailySkillsTracker> {
  // بيانات التطبيق
  List<SkillCategory> _categories = [];
  Map<String, SkillRecord> _todayRecords = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String _selectedChildId = '';

  // نظام الألوان
  final Color _primaryColor = AppColors.primary;
  final Color _successColor = Color(0xFF4CAF50);
  final Color _warningColor = Color(0xFFFF9800);
  final Color _infoColor = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    // تحديد الطفل (إذا لم يتم تحديده، نأخذ الأول)
    _selectedChildId = widget.childId ?? await _getFirstChildId();

    // تحميل البيانات
    await _loadCategories();
    await _loadTodayRecords();

    setState(() => _isLoading = false);
  }

  Future<String> _getFirstChildId() async {
    // في التطبيق الحقيقي، نأخذ من قائمة الأطفال
    return 'child_1'; // قيمة افتراضية للاختبار
  }

  Future<void> _loadCategories() async {
    // بيانات تجريبية للمهارات
    setState(() {
      _categories = [
        SkillCategory(
          id: 'communication',
          name: 'المهارات التواصلية',
          icon: Icons.chat,
          color: _infoColor,
          skills: [
            Skill('respond_name', 'الاستجابة للاسم', 'يستجيب عند مناداته باسمه'),
            Skill('eye_contact', 'التواصل البصري', 'يحافظ على التواصل البصري'),
            Skill('pointing', 'الإشارة', 'يشير إلى الأشياء التي يريدها'),
            Skill('simple_words', 'كلمات بسيطة', 'ينطق كلمات مثل "ماما"، "بابا"'),
          ],
        ),
        SkillCategory(
          id: 'social',
          name: 'المهارات الاجتماعية',
          icon: Icons.people,
          color: Colors.green,
          skills: [
            Skill('sharing', 'المشاركة', 'يشارك الألعاب مع الآخرين'),
            Skill('turn_taking', 'انتظار الدور', 'ينتظر دوره في اللعب'),
            Skill('imitating', 'التقليد', 'يقلد أفعال الآخرين'),
            Skill('smiling', 'الابتسام', 'يبتسم رداً على الابتسام'),
          ],
        ),
        SkillCategory(
          id: 'self_care',
          name: 'العناية الذاتية',
          icon: Icons.self_improvement,
          color: Colors.orange,
          skills: [
            Skill('eating', 'تناول الطعام', 'يأكل بشكل مستقل'),
            Skill('drinking', 'الشرب', 'يشرب من الكوب'),
            Skill('dressing', 'ارتداء الملابس', 'يرتدي ملابسه بمساعدة'),
          ],
        ),
        SkillCategory(
          id: 'motor',
          name: 'المهارات الحركية',
          icon: Icons.directions_run,
          color: Colors.purple,
          skills: [
            Skill('walking', 'المشي', 'يمشي بشكل مستقر'),
            Skill('climbing', 'التسلق', 'يتسلق الأثاث بأمان'),
            Skill('throwing', 'رمي الكرة', 'يرمي الكرة باتجاه معين'),
          ],
        ),
      ];
    });
  }

  Future<void> _loadTodayRecords() async {
    // في التطبيق الحقيقي، نحمّل من الـ API
    // هنا نستخدم بيانات تجريبية
    setState(() {
      _todayRecords = {
        'respond_name': SkillRecord(level: SkillLevel.withHelp, attempts: 3, notes: 'تحسن ملحوظ اليوم'),
        'eye_contact': SkillRecord(level: SkillLevel.independent, attempts: 5, notes: 'أداء ممتاز'),
        'walking': SkillRecord(level: SkillLevel.mastered, attempts: 10, notes: 'يتحرك بثقة'),
      };
    });
  }

  Future<void> _recordSkill(String skillId, SkillLevel level) async {
    setState(() {
      _todayRecords[skillId] = SkillRecord(
        level: level,
        attempts: (_todayRecords[skillId]?.attempts ?? 0) + 1,
        notes: _todayRecords[skillId]?.notes,
        timestamp: DateTime.now(),
      );
    });

    // في التطبيق الحقيقي، نحفظ في الـ API
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      await ApiService.recordSkillProgress(
        token: token,
        childId: _selectedChildId,
        skillId: skillId,
        level: level.index,
        attempts: _todayRecords[skillId]!.attempts,
        notes: _todayRecords[skillId]!.notes,
      );

      _showSuccessSnackbar('تم تسجيل التقدم بنجاح!');
    } catch (e) {
      _showErrorSnackbar('خطأ في الحفظ: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSkillDetails(Skill skill) {
    final record = _todayRecords[skill.id];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // المقبض
            Container(
              margin: EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // المحتوى
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.emoji_objects, color: _primaryColor),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skill.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              skill.description,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // حالة اليوم
                  Text(
                    'تقييم اليوم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),

                  if (record != null) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getLevelColor(record.level).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getLevelColor(record.level).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getLevelIcon(record.level),
                            color: _getLevelColor(record.level),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getLevelText(record.level),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getLevelColor(record.level),
                                  ),
                                ),
                                Text(
                                  '${record.attempts} محاولة',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (record.notes != null && record.notes!.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'ملاحظات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(record.notes!),
                    ],
                  ] else ...[
                    Text(
                      'لم يتم التسجيل اليوم',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],

                  SizedBox(height: 20),

                  // أزرار التسجيل
                  Text(
                    'تسجيل التقدم',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SkillLevel.values.map((level) {
                      return ActionChip(
                        label: Text(
                          _getLevelText(level),
                          style: TextStyle(
                            color: _getLevelColor(level),
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          _recordSkill(skill.id, level);
                          Navigator.pop(context);
                        },
                        backgroundColor: _getLevelColor(level).withOpacity(0.1),
                        avatar: Icon(
                          _getLevelIcon(level),
                          color: _getLevelColor(level),
                          size: 16,
                        ),
                      );
                    }).toList(),
                  ),

                  Spacer(),

                  // زر الإغلاق
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('إغلاق'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(SkillLevel level) {
    switch (level) {
      case SkillLevel.notAttempted:
        return Colors.grey;
      case SkillLevel.struggling:
        return Colors.red;
      case SkillLevel.withHelp:
        return _warningColor;
      case SkillLevel.independent:
        return _infoColor;
      case SkillLevel.mastered:
        return _successColor;
    }
  }

  IconData _getLevelIcon(SkillLevel level) {
    switch (level) {
      case SkillLevel.notAttempted:
        return Icons.hourglass_empty;
      case SkillLevel.struggling:
        return Icons.sentiment_dissatisfied;
      case SkillLevel.withHelp:
        return Icons.help;
      case SkillLevel.independent:
        return Icons.sentiment_satisfied;
      case SkillLevel.mastered:
        return Icons.emoji_events;
    }
  }

  String _getLevelText(SkillLevel level) {
    switch (level) {
      case SkillLevel.notAttempted:
        return 'لم يحاول';
      case SkillLevel.struggling:
        return 'يواجه صعوبة';
      case SkillLevel.withHelp:
        return 'بمساعدة';
      case SkillLevel.independent:
        return 'مستقل';
      case SkillLevel.mastered:
        return 'أتقنها';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'تتبع المهارات اليومية',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () {
              // للانتقال لشاشة الإحصائيات (يمكن تطويرها لاحقاً)
              _showStatistics();
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primaryColor),
          SizedBox(height: 16),
          Text('جاري تحميل المهارات...'),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // بطاقة اليوم والتاريخ
        _buildDateCard(),

        // الإحصائيات السريعة
        _buildQuickStats(),

        // قائمة المهارات
        Expanded(
          child: _buildSkillsList(),
        ),
      ],
    );
  }

  Widget _buildDateCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تتبع المهارات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_todayRecords.length} مهارة',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final masteredCount = _todayRecords.values.where((r) => r.level == SkillLevel.mastered).length;
    final independentCount = _todayRecords.values.where((r) => r.level == SkillLevel.independent).length;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.emoji_events, 'المتقنة', '$masteredCount', _successColor),
          _buildStatItem(Icons.check_circle, 'المستقلة', '$independentCount', _infoColor),
          _buildStatItem(Icons.track_changes, 'المسجلة', '${_todayRecords.length}', _primaryColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String title, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, categoryIndex) {
        final category = _categories[categoryIndex];
        return _buildCategorySection(category);
      },
    );
  }

  Widget _buildCategorySection(SkillCategory category) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس القسم
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                Text(
                  '${category.skills.length}',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // قائمة المهارات
            ...category.skills.map((skill) {
              final record = _todayRecords[skill.id];
              return _buildSkillItem(skill, record, category.color);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillItem(Skill skill, SkillRecord? record, Color categoryColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: record != null
                ? _getLevelColor(record.level).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            record != null ? _getLevelIcon(record.level) : Icons.circle_outlined,
            color: record != null ? _getLevelColor(record.level) : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          skill.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          skill.description,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: record != null
            ? Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getLevelColor(record.level).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getLevelColor(record.level).withOpacity(0.3),
            ),
          ),
          child: Text(
            _getLevelText(record.level),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getLevelColor(record.level),
            ),
          ),
        )
            : null,
        onTap: () => _showSkillDetails(skill),
      ),
    );
  }

  void _showStatistics() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('شاشة الإحصائيات قريباً! 🚀'),
        backgroundColor: _primaryColor,
      ),
    );
  }
}

// ========== النماذج (Models) ==========

class SkillCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<Skill> skills;

  SkillCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.skills,
  });
}

class Skill {
  final String id;
  final String name;
  final String description;

  Skill(this.id, this.name, this.description);
}

class SkillRecord {
  final SkillLevel level;
  final int attempts;
  final String? notes;
  final DateTime? timestamp;

  SkillRecord({
    required this.level,
    required this.attempts,
    this.notes,
    this.timestamp,
  });
}

enum SkillLevel {
  notAttempted,    // لم يتم المحاولة
  struggling,      // يواجه صعوبة
  withHelp,        // بمساعدة
  independent,     // مستقل
  mastered         // أتقن المهارة
}