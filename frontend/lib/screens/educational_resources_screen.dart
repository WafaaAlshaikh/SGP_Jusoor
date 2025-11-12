import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/ollama_service.dart';
import '../services/educational_resources_service.dart';
import '../theme/app_colors.dart';
import 'favorites_screen.dart';

class EducationalResourcesScreen extends StatefulWidget {
  const EducationalResourcesScreen({super.key});

  @override
  State<EducationalResourcesScreen> createState() => _EducationalResourcesScreenState();
}

class _EducationalResourcesScreenState extends State<EducationalResourcesScreen> {
  List<dynamic> resources = [];
  List<String> favoriteLinks = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedType = 'All';
  List<String> typeOptions = ['All', 'Article', 'Video', 'PDF'];

  // فلترة إضافية
  String selectedAge = 'All Ages';
  String selectedSkill = 'All Skills';
  final List<String> ages = ['All Ages', '3-5', '6-9', '10-13', '14+'];
  final List<String> skills = ['All Skills', 'Speech', 'Behavior', 'Focus'];

  // Chat AI مع Gemini - معدل
  List<Map<String, String>> chatMessages = [];
  final TextEditingController chatController = TextEditingController();
  bool isSending = false;
  bool isChatOpen = false;
  late GenerativeModel model;
  late ChatSession chat;
  bool isOllamaConnected = false;
  String connectionStatus = 'Checking...';

  // البحث الصوتي
  late stt.SpeechToText speech;
  bool isListening = false;

  // بيانات الأطفال
  List<dynamic> childrenData = [];
  bool isLoadingChildren = true;
  String childrenDiagnosis = '';

  // بيانات الموارد
  final List<Map<String, dynamic>> demoResources = [
    {
      'title': 'تمارين النطق للأطفال',
      'description': 'أنشطة عملية لتحسين مهارات النطق والكلام',
      'type': 'Article',
      'link': 'https://example.com/speech-therapy',
      'age_group': '3-5',
      'skill_type': 'Speech',
      'date': '2024-01-15',
      'views': 150,
      'rating': 4
    },
    {
      'title': 'أنشطة التركيز والانتباه',
      'description': 'ألعاب لتحسين الانتباه والتركيز لدى الأطفال',
      'type': 'Video',
      'link': 'https://youtube.com/focus-activities',
      'age_group': '6-9',
      'skill_type': 'Focus',
      'date': '2024-01-10',
      'views': 200,
      'rating': 5
    },
    {
      'title': 'استراتيجيات التعامل مع التوحد',
      'description': 'نصائح عملية للآباء والمعلمين',
      'type': 'PDF',
      'link': 'https://example.com/autism-guide.pdf',
      'age_group': 'All Ages',
      'skill_type': 'Behavior',
      'date': '2024-01-05',
      'views': 300,
      'rating': 4
    },
  ];

  // AI-generated resources flag
  bool isLoadingAIResources = false;

  @override
  void initState() {
    super.initState();
    _initializeOllama();
    _loadAIResources(); // تحميل الموارد الموثوقة
    speech = stt.SpeechToText();
    loadFavorites();
  }
  
  // تحميل الموارد مع خيار استخدام AI
  Future<void> _loadResourcesWithAI() async {
    setState(() {
      isLoading = true;
      isLoadingAIResources = true;
    });

    try {
      print('🔄 Fetching AI-powered resources from backend...');
      
      final aiResources = await EducationalResourcesService.getAllResources(useAI: true);
      
      setState(() {
        resources = aiResources;
        isLoading = false;
        isLoadingAIResources = false;
      });
      
      print('✅ Loaded ${aiResources.length} AI resources');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Loaded ${aiResources.length} AI-powered resources'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error loading AI resources: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ AI not available. Using trusted resources.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      _loadAIResources();
    }
  }

  // 🔥 تهيئة Gemini AI - مع API Key الجديد
// بدل الكود القديم:
  void _initializeOllama() async {
    print('🔍 Checking Ollama connection...');

    final health = await OllamaService.healthCheck();

    setState(() {
      isOllamaConnected = health['success'] ?? false;
      connectionStatus = health['success'] == true
          ? '✅ Connected to Ollama'
          : '❌ Ollama not available';
    });

    if (health['success'] == true) {
      print('✅ Ollama is ready!');
    } else {
      print('❌ Ollama connection failed: ${health['error']}');
    }
  }

// إلى هذا الكود البسيط:

  // 🔥 دالة إرسال الرسالة مع أولاما
  Future<void> sendMessage() async {
    final text = chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      chatMessages.add({'role': 'user', 'text': text});
      chatController.clear();
      isSending = true;
    });

    try {
      print('💬 Sending educational chat message: "$text"');
      
      // Get user's token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Collect unique diagnoses from children
      List<String> diagnoses = [];
      if (childrenData.isNotEmpty) {
        for (var child in childrenData) {
          final diagnosis = child['diagnosis'] as String?;
          if (diagnosis != null && !diagnoses.contains(diagnosis)) {
            diagnoses.add(diagnosis);
          }
        }
      }

      print('📋 User diagnoses: ${diagnoses.join(', ')}');

      // Call educational chat API
      final url = Uri.parse('http://10.0.2.2:5000/api/ai/educational-chat');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': text,
          'diagnoses': diagnoses,
        }),
      ).timeout(Duration(seconds: 30));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          setState(() {
            chatMessages.add({
              'role': 'ai',
              'text': data['response'] ?? 'No response'
            });
            isSending = false;
          });
          print('✅ Chat response received');
        } else {
          throw Exception(data['message'] ?? 'Failed to get response');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }

    } catch (e) {
      print('❌ Chat error: $e');
      setState(() {
        chatMessages.add({
          'role': 'ai',
          'text': '❌ Sorry, I encountered an error. Please try again.'
        });
        isSending = false;
      });
    }
  }

  // 🔥 عرض تفاصيل الخطأ
  void _showErrorDetails(dynamic error, String question) {
    String errorMessage = '';

    if (error.toString().contains('API_KEY_INVALID') ||
        error.toString().contains('403') ||
        error.toString().contains('PERMISSION_DENIED')) {
      errorMessage = '''
🔐 **مشكلة في تصريحات API Key:**

• تأكد من تفعيل Gemini API في Google Cloud Console
• تحقق من أن المشروع مرتبط بحساب الفوترة
• قد تحتاج إلى الانتظار بضع دقائق حتى يتم تفعيل المفتاح

💡 **الحلول:**
1. اذهب إلى [Google Cloud Console](https://console.cloud.google.com/)
2. ابحث عن "Gemini API" في المكتبة
3. انقر على "Enable" لتفعيل الخدمة
4. انتظر 2-3 دقائق ثم جرب مرة أخرى''';
    }
    else if (error.toString().contains('quota') || error.toString().contains('429')) {
      errorMessage = '''
📊 **تم تجاوز الحد المسموح:**

• الخطة المجانية: 60 طلب/دقيقة
• جرب بعد دقيقة واحدة
• الإجابة الحالية:''';
      _showOfflineResponse(question);
      return;
    }
    else if (error.toString().contains('network') || error.toString().contains('timeout')) {
      errorMessage = '''
🌐 **مشكلة في الشبكة:**

• تحقق من اتصال الإنترنت
• جرب استخدام شبكة مختلفة
• الإجابة الحالية:''';
      _showOfflineResponse(question);
      return;
    }
    else {
      errorMessage = '''
⚠️ **خطأ في الاتصال:**

$error

💡 **جاري استخدام النظام المحلي...**''';
    }

    setState(() {
      chatMessages.add({'role': 'ai', 'text': errorMessage});
      _showOfflineResponse(question);
    });
  }

  // 🔥 نظام ردود محلي (احتياطي)
  void _showOfflineResponse(String question) {
    final lowerQuestion = question.toLowerCase();
    String response = '';

    if (lowerQuestion.contains('نطق') || lowerQuestion.contains('كلام')) {
      response = '''
🗣️ **تمارين النطق المنزلية - برنامج متكامل:**

• **المرحلة الأولى: الإحماء (5 دقائق)**
  - تمارين التنفس: نفخ البالونات، نفخ الريش
  - تحريك الفك: فتح وإغلاق الفم ببطء
  - تمرين الشفاه: تقبيل الهواء، الابتسام

• **المرحلة الثانية: الأصوات الأساسية (10 دقائق)**
  - أصوات الشفاه: "با، بو، بي" - كرر 10 مرات
  - أصوات اللسان: "تا، تو، تي" - كرر 10 مرات  
  - أصوات الحلق: "ها، هو، هي" - كرر 10 مرات

• **المرحلة الثالثة: الكلمات البسيطة (10 دقائق)**
  - "باب، بيت، باص"
  - "مام، منزل، ماء"
  - "توت، تين، تاج"

🎯 **نصيحة:** اجعل التمارين لعبة مسلية وامنح مكافآت صغيرة''';
    }
    else if (lowerQuestion.contains('حركة') || lowerQuestion.contains('تركيز')) {
      response = '''
🎯 **استراتيجيات تحسين التركيز والانتباه:**

• **تهيئة البيئة:**
  - مكان هادئ خالي من المشتتات
  - إضاءة مناسبة وتهوية جيدة
  - ترتيب الأدوات بشكل منظم

• **تقنيات التركيز:**
  - تقنية بومودورو: 25 دقيقة عمل → 5 دقائق راحة
  - استخدام المؤقتات المرئية (ساعة رملية)
  - تقسيم المهام الكبيرة إلى مهام صغيرة

• **أنشطة تدريبية يومية:**
  - ألعاب الذاكرة (10 دقائق)
  - تركيب Puzzles مناسبة للعمر
  - البحث عن الاختلافات بين الصور
  - تلوين الماندالا والرسومات

📈 **متابعة التقدم:** سجل إنجازات الطفل واحتفل بها''';
    }
    else if (lowerQuestion.contains('توحد')) {
      response = '''
🌟 **دليل شامل لدعم أطفال التوحد:**

• **استراتيجيات التواصل:**
  - استخدام لغة بسيطة ومباشرة
  - الاستعانة بالصور والرموز (PECS)
  - إعطاء وقت كافٍ للاستجابة
  - تعزيز المحاولات الناجحة

• **الروتين والتنبؤ:**
  - جدول مرئي للأنشطة اليومية
  - التحضير المسبق لأي تغييرات
  - أوقات ثابتة للوجبات والنوم
  - مساحة هادئة للتراجع عند الحاجة

• **الأنشطة المناسبة:**
  - الأنشطة الحسية (الرمل، الماء، المعجون)
  - الألعاب التركيبية والمكعبات
  - الأنشطة الرياضية المنظمة
  - الموسيقى الهادئة والأناشيد

🤝 **تذكر:** كل طفل فريد ويحتاج إلى خطة فردية تناسب احتياجاته''';
    }
    else {
      response = '''
🤖 **مساعد التعليم الخاص - الذكاء الاصطناعي**

✅ **تم الاتصال بنجاح باستخدام API Key الجديد!**

📚 **مجالات الخبرة:**
• 🗣️ اضطرابات النطق والكلام
• 🧠 صعوبات التعلم والتركيز  
• 🌟 التوحد وطيف التوحد
• 🏃 الأنشطة الحركية والحسية
• 📊 التقييم والتشخيص
• 🎯 استراتيجيات التعلم الفردية

💡 **كيف يمكنني مساعدتك؟**
- اطلب نصائح عملية
- اسأل عن أنشطة محددة
- استفسر عن استراتيجيات التعامل
- اطلب برامج تدريبية منزلية''';
    }

    setState(() {
      chatMessages.add({
        'role': 'ai',
        'text': response
      });
    });
  }

  // 🤖 تحميل الموارد من مصادر موثوقة حسب حالة الأطفال
  Future<void> _loadAIResources() async {
    setState(() {
      isLoading = true;
      isLoadingAIResources = true;
    });

    try {
      print('🔄 Fetching trusted educational resources based on children data...');
      
      // Use trusted resources directly (useAI: false)
      // This loads instantly from fallback sources based on diagnosis
      final trustedResources = await EducationalResourcesService.getAllResources(useAI: false);
      
      setState(() {
        resources = trustedResources;
        isLoading = false;
        isLoadingAIResources = false;
      });
      
      print('✅ Loaded ${trustedResources.length} trusted resources');
    } catch (e) {
      print('❌ Error loading resources: $e');
      // Fallback to demo resources
      _loadDemoResources();
    }
  }

  // تحميل البيانات التجريبية (احتياطي)
  void _loadDemoResources() {
    setState(() {
      resources = demoResources;
      isLoading = false;
      isLoadingAIResources = false;
    });
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteLinks = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> toggleFavorite(String link) async {
    final prefs = await SharedPreferences.getInstance();
    bool wasAdded = false;
    
    setState(() {
      if (favoriteLinks.contains(link)) {
        favoriteLinks.remove(link);
        wasAdded = false;
      } else {
        favoriteLinks.add(link);
        wasAdded = true;
      }
    });
    
    await prefs.setStringList('favorites', favoriteLinks);
    
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                wasAdded ? Icons.favorite : Icons.favorite_border,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                wasAdded 
                  ? 'Added to favorites ❤️' 
                  : 'Removed from favorites',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: wasAdded ? AppColors.primary : AppColors.textGray,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // 🔧 الدالة المصححة للعثور على الموارد المفضلة
  Map<String, dynamic>? _findFavoriteResource(String link) {
    try {
      return resources.firstWhere(
            (r) => r['link'] == link,
      );
    } catch (e) {
      return null;
    }
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() => isListening = true);
      speech.listen(
        onResult: (result) {
          setState(() {
            searchQuery = result.recognizedWords;
          });
        },
      );
    }
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  bool isNewResource(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    return diff <= 7;
  }

  bool isTrending(int views) => views >= 100;

  List<dynamic> getRecommended(String type) {
    return resources
        .where((r) => r['type'].toString().toLowerCase() == type.toLowerCase())
        .take(3)
        .toList();
  }

  // Helper: Build info chip (for badges)
  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Build info tag (for metadata)
  Widget _buildTag({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideSection({required String title, required IconData icon, required List items}) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 5, offset: Offset(0,3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, idx) {
                  final item = items[idx];
                  return InkWell(
                    onTap: () async {
                      if (item['link'] != null) {
                        await launchUrl(Uri.parse(item['link']));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        item['title'],
                        style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredResources = resources.where((r) {
      final matchesType = selectedType == 'All'
          ? true
          : r['type'].toString().toLowerCase() == selectedType.toLowerCase();
      final matchesSearch = r['title']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase()) ||
          r['description']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
      final matchesAge = selectedAge == 'All Ages' ? true : r['age_group'] == selectedAge;
      final matchesSkill = selectedSkill == 'All Skills' ? true : r['skill_type'] == selectedSkill;
      return matchesType && matchesSearch && matchesAge && matchesSkill;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🎓 Educational Resources'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        elevation: 2,
        actions: [
          // Favorites button with badge
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.favorite),
                tooltip: 'My Favorites',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FavoritesScreen(
                        allResources: resources,
                      ),
                    ),
                  ).then((_) {
                    // Reload favorites when returning
                    loadFavorites();
                  });
                },
              ),
              if (favoriteLinks.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${favoriteLinks.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.menu),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'trusted') {
                _loadAIResources();
              } else if (value == 'ai') {
                _loadResourcesWithAI();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'trusted',
                child: Row(
                  children: [
                    Icon(Icons.verified, color: AppColors.accent1, size: 20),
                    SizedBox(width: 8),
                    Text('Trusted Resources'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ai',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.accent2, size: 20),
                    SizedBox(width: 8),
                    Text('AI-Powered (Groq)'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh Resources',
            onPressed: _loadAIResources,
          ),
          IconButton(
            icon: Icon(isListening ? Icons.mic_off : Icons.mic),
            tooltip: 'Voice Search',
            onPressed: () {
              if (isListening) stopListening();
              else startListening();
            },
          )
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ✅ إشعار حالة الموارد
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📚 Trusted Educational Resources',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark
                          ),
                        ),
                        Text(
                          'From CDC, ASHA, Autism Speaks & more • ${resources.length} resources loaded',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: AppColors.primary),
                    iconSize: 20,
                    tooltip: 'About Sources',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(Icons.verified, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Trusted Sources'),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Resources from:'),
                                SizedBox(height: 8),
                                Text('• CDC (Centers for Disease Control)'),
                                Text('• ASHA (American Speech-Language-Hearing)'),
                                Text('• Autism Speaks'),
                                Text('• National Down Syndrome Society'),
                                Text('• CHADD (ADHD organization)'),
                                Text('• Understood.org'),
                                SizedBox(height: 12),
                                Text(
                                  'All resources are evidence-based and from reliable English-language sources.',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 🔍 البحث
            TextField(
              decoration: InputDecoration(
                hintText: 'Search resources...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
            const SizedBox(height: 10),

            // ---- Tabs / Chips للفئات ----
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: typeOptions.map((type) {
                  final isSelected = selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (_) => setState(() => selectedType = type),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: AppColors.surface,
                      elevation: 3,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // ---- فلترة إضافية ----
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      labelText: 'Child Age Group',
                    ),
                    value: selectedAge,
                    items: ages.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                    onChanged: (v) => setState(() => selectedAge = v ?? 'All Ages'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      labelText: 'Skill Type',
                    ),
                    value: selectedSkill,
                    items: skills.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => selectedSkill = v ?? 'All Skills'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 🧩 قائمة الموارد
            ...filteredResources.map((r) {
              final isFav = favoriteLinks.contains(r['link']);
              final dateAdded = DateTime.tryParse(r['date'] ?? '') ?? DateTime.now();
              final trending = isTrending(r['views'] ?? 0);
              final newResource = isNewResource(dateAdded);

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () async {
                    await launchUrl(Uri.parse(r['link']));
                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (context) => Container(
                        padding: EdgeInsets.all(16),
                        height: 260,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("قد يعجبك أيضًا...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: getRecommended(r['type']).map((rec) => Container(
                                  width: 180,
                                  margin: EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 5, offset: Offset(0, 3))],
                                  ),
                                  child: InkWell(
                                    onTap: () => launchUrl(Uri.parse(rec['link'])),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(rec['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                                          SizedBox(height: 4),
                                          Text(rec['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                                        ],
                                      ),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with type icon and badges
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.accent1,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                r['type'] == 'Video'
                                    ? Icons.play_circle_outline
                                    : r['type'] == 'PDF'
                                    ? Icons.picture_as_pdf
                                    : Icons.article_outlined,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['title'],
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      height: 1.3,
                                      color: AppColors.textDark,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (r['source'] != null)
                                        _buildInfoChip(
                                          icon: Icons.verified,
                                          label: r['source'],
                                          color: Colors.blue[700]!,
                                        ),
                                      if (r['ai_generated'] == true)
                                        _buildInfoChip(
                                          icon: Icons.auto_awesome,
                                          label: 'AI',
                                          color: Colors.purple[700]!,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.red : AppColors.textGray,
                                  ),
                                  onPressed: () => toggleFavorite(r['link']),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Description
                        Text(
                          r['description'],
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        
                        // Info tags
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildTag(
                              icon: Icons.category_outlined,
                              label: r['skill_type'] ?? 'General',
                              color: AppColors.primary,
                            ),
                            _buildTag(
                              icon: Icons.child_care,
                              label: r['age_group'] ?? 'All Ages',
                              color: AppColors.primaryDark,
                            ),
                            _buildTag(
                              icon: Icons.remove_red_eye_outlined,
                              label: '${r['views'] ?? 0} views',
                              color: AppColors.textDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Footer with rating and action button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                int currentRating = r['rating'] ?? 0;
                                return Icon(
                                  index < currentRating ? Icons.star : Icons.star_border,
                                  color: Colors.amber[700],
                                  size: 18,
                                );
                              }),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => launchUrl(Uri.parse(r['link'])),
                              icon: Icon(Icons.open_in_new, size: 16),
                              label: Text('View Resource'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 10),

            // ---- أقسام جانبية ----
            Container(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _buildSideSection(
                    title: '⭐ Recommended',
                    icon: Icons.star,
                    items: resources.take(3).toList(),
                  ),
                  const SizedBox(width: 10),
                  _buildSideSection(
                    title: '🧩 Activities',
                    icon: Icons.extension,
                    items: [
                      {'title': 'لعبة تحسين التركيز', 'link': 'https://example.com/activity1'},
                      {'title': 'نشاط نطق للأطفال', 'link': 'https://example.com/activity2'},
                      {'title': 'تمارين سلوكية ممتعة', 'link': 'https://example.com/activity3'},
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),

      // 💬 زر الشات العائم
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => setState(() => isChatOpen = !isChatOpen),
        child: Icon(isChatOpen ? Icons.close : Icons.chat_bubble, color: Colors.white),
      ),

      // 💬 واجهة الشات المنبثقة
      bottomSheet: isChatOpen
          ? Container(
        height: 420,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [BoxShadow(blurRadius: 10, color: AppColors.primary.withOpacity(0.2))],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text('🤖 مساعد التعليم الخاص', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: chatMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = chatMessages[i];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.primary : AppColors.accent1,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg['text']!, style: TextStyle(color: isUser ? Colors.white : AppColors.textDark)),
                    ),
                  );
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 8,
                children: [
                  "What are early signs of autism?",
                  "How to improve speech at home?",
                  "Tips for managing ADHD behavior",
                  "Activities for motor skills development",
                  "How to support a child with learning disabilities?",
                  "Best communication strategies for non-verbal children"
                ].map((q) => ActionChip(
                  label: Text(q, style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    chatController.text = q;
                    sendMessage();
                  },
                  backgroundColor: AppColors.accent1,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                )).toList(),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatController,
                    decoration: const InputDecoration(
                      hintText: 'اسأل عن التعليم الخاص...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  icon: isSending
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : Icon(Icons.send, color: AppColors.primary),
                  onPressed: isSending ? null : sendMessage,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      )
          : null,
    );
  }
}