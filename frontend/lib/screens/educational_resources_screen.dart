import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/ollama_service.dart'; // أضف هذا الاستيراد

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

  @override
  void initState() {
    super.initState();
    _initializeOllama();
    _loadDemoResources();
    speech = stt.SpeechToText();
    loadFavorites();
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

    print('🔄 Sending message to Ollama...');
    final response = await OllamaService.sendMessage(text);

    setState(() {
      if (response['success'] == true) {
        chatMessages.add({
          'role': 'ai',
          'text': response['response'] ?? 'No response'
        });
        print('✅ Message sent successfully');
      } else {
        chatMessages.add({
          'role': 'ai',
          'text': '❌ Error: ${response['error']}'
        });
        print('❌ Error: ${response['error']}');
      }
      isSending = false;
    });
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

  // تحميل البيانات التجريبية
  void _loadDemoResources() {
    setState(() {
      resources = demoResources;
      isLoading = false;
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
    setState(() {
      if (favoriteLinks.contains(link)) {
        favoriteLinks.remove(link);
      } else {
        favoriteLinks.add(link);
      }
    });
    await prefs.setStringList('favorites', favoriteLinks);
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

  Widget _buildSideSection({required String title, required IconData icon, required List items}) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, offset: Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal),
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
                        style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.w500),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('🎓 Educational Resources - AI Powered'),
        backgroundColor: Colors.teal,
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(isListening ? Icons.mic_off : Icons.mic),
            onPressed: () {
              if (isListening) stopListening();
              else startListening();
            },
          )
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ✅ إشعار نجاح الاتصال
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOllamaConnected ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOllamaConnected ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOllamaConnected ? Icons.check_circle : Icons.warning,
                    color: isOllamaConnected ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOllamaConnected
                              ? '✅ متصل بـ Ollama AI بنجاح'
                              : '⚠️ نظام Ollama غير متوفر',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOllamaConnected ? Colors.green[800] : Colors.orange[800]
                          ),
                        ),
                        Text(
                          isOllamaConnected
                              ? 'مساعد الذكاء الاصطناعي المحلي جاهز للإجابة'
                              : 'جاري استخدام النظام الاحتياطي - تحقق من تشغيل الخادم',
                          style: TextStyle(
                              fontSize: 12,
                              color: isOllamaConnected ? Colors.green[700] : Colors.orange[700]
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ⭐ المفضلة الذكية - الجزء المصحح
            if (favoriteLinks.isNotEmpty) ...[
              const Text("⭐ المفضلة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: favoriteLinks.map((link) {
                    final resource = _findFavoriteResource(link);
                    if (resource == null) return SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () => launchUrl(Uri.parse(resource['link'])),
                        child: Container(
                          width: 180,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, offset: Offset(0,3))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  resource['title'] ?? 'No Title',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis
                              ),
                              SizedBox(height: 4),
                              Text(
                                  resource['description'] ?? 'No Description',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700])
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 🔍 البحث
            TextField(
              decoration: InputDecoration(
                hintText: 'Search resources...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
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
                      selectedColor: Colors.teal,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: Colors.white,
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
                      fillColor: Colors.white,
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
                      fillColor: Colors.white,
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, offset: Offset(0, 3))],
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
                                          Text(rec['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              r['type'] == 'video'
                                  ? Icons.video_library
                                  : r['type'] == 'pdf'
                                  ? Icons.picture_as_pdf
                                  : Icons.article,
                              color: Colors.teal,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(r['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            if (newResource) Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(8)), child: Text('🆕 New', style: TextStyle(fontSize: 12))),
                            if (trending) Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)), child: Text('🔥 Trending', style: TextStyle(fontSize: 12))),
                            IconButton(
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey),
                              onPressed: () => toggleFavorite(r['link']),
                            ),
                            IconButton(
                              icon: Icon(Icons.download, color: Colors.teal),
                              onPressed: () => launchUrl(Uri.parse(r['link'])),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(r['description'], style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('📅 ${r['date'] ?? 'Unknown'}', style: const TextStyle(fontSize: 12)),
                            Row(
                              children: List.generate(5, (index) {
                                int currentRating = r['rating'] ?? 0;
                                return IconButton(
                                  icon: Icon(index < currentRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      r['rating'] = index + 1;
                                    });
                                  },
                                );
                              }),
                            ),
                          ],
                        )
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
        backgroundColor: Colors.teal,
        onPressed: () => setState(() => isChatOpen = !isChatOpen),
        child: Icon(isChatOpen ? Icons.close : Icons.chat_bubble),
      ),

      // 💬 واجهة الشات المنبثقة
      bottomSheet: isChatOpen
          ? Container(
        height: 420,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text('🤖 مساعد التعليم الخاص', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        color: isUser ? Colors.teal : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg['text']!, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
                    ),
                  );
                },
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                "نصائح لفرط الحركة",
                "تمارين للنطق في المنزل",
                "كيف أتعامل مع الطفل التوحدي",
                "أنشطة لتحسين التركيز"
              ].map((q) => ActionChip(
                label: Text(q),
                onPressed: () {
                  chatController.text = q;
                  sendMessage();
                },
                backgroundColor: Colors.teal[50],
              )).toList(),
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
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.teal),
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