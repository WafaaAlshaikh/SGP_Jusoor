import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/activity_recommendation_hub.dart';
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

  // Additional filters
  String selectedAge = 'All Ages';
  String selectedSkill = 'All Skills';
  final List<String> ages = ['All Ages', '3-5', '6-9', '10-13', '14+'];
  final List<String> skills = ['All Skills', 'Speech', 'Behavior', 'Focus'];

  // Chat AI with Gemini
  List<Map<String, String>> chatMessages = [];
  final TextEditingController chatController = TextEditingController();
  bool isSending = false;
  bool isChatOpen = false;
  late GenerativeModel model;
  late ChatSession chat;
  bool isOllamaConnected = false;
  String connectionStatus = 'Checking...';

  // Speech recognition removed

  // Children data
  List<dynamic> childrenData = [];
  bool isLoadingChildren = true;
  String childrenDiagnosis = '';

  // Demo resources data
  final List<Map<String, dynamic>> demoResources = [
    {
      'title': 'Speech Exercises for Children',
      'description': 'Practical activities to improve speech and language skills',
      'type': 'Article',
      'link': 'https://example.com/speech-therapy',
      'age_group': '3-5',
      'skill_type': 'Speech',
      'date': '2024-01-15',
      'views': 150,
      'rating': 4
    },
    {
      'title': 'Focus and Attention Activities',
      'description': 'Games to improve attention and focus in children',
      'type': 'Video',
      'link': 'https://youtube.com/focus-activities',
      'age_group': '6-9',
      'skill_type': 'Focus',
      'date': '2024-01-10',
      'views': 200,
      'rating': 5
    },
    {
      'title': 'Autism Support Strategies',
      'description': 'Practical tips for parents and educators',
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
    _loadAIResources();
    loadFavorites();
  }

  Future<void> _loadResourcesWithAI() async {
    setState(() {
      isLoading = true;
      isLoadingAIResources = true;
    });

    try {
      final aiResources = await EducationalResourcesService.getAllResources(useAI: true);

      setState(() {
        resources = aiResources;
        isLoading = false;
        isLoadingAIResources = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${aiResources.length} AI-powered resources'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI not available. Using trusted resources.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      _loadAIResources();
    }
  }

  void _initializeOllama() async {
    final health = await OllamaService.healthCheck();

    setState(() {
      isOllamaConnected = health['success'] ?? false;
      connectionStatus = health['success'] == true
          ? 'Connected to Ollama'
          : 'Ollama not available';
    });
  }

  Future<void> sendMessage() async {
    final text = chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      chatMessages.add({'role': 'user', 'text': text});
      chatController.clear();
      isSending = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      List<String> diagnoses = [];
      if (childrenData.isNotEmpty) {
        for (var child in childrenData) {
          final diagnosis = child['diagnosis'] as String?;
          if (diagnosis != null && !diagnoses.contains(diagnosis)) {
            diagnoses.add(diagnosis);
          }
        }
      }

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
        } else {
          throw Exception(data['message'] ?? 'Failed to get response');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }

    } catch (e) {
      setState(() {
        chatMessages.add({
          'role': 'ai',
          'text': 'Sorry, I encountered an error. Please try again.'
        });
        isSending = false;
      });
    }
  }

  Future<void> _loadAIResources() async {
    setState(() {
      isLoading = true;
      isLoadingAIResources = true;
    });

    try {
      final trustedResources = await EducationalResourcesService.getAllResources(useAI: false);

      setState(() {
        resources = trustedResources;
        isLoading = false;
        isLoadingAIResources = false;
      });
    } catch (e) {
      _loadDemoResources();
    }
  }

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
                wasAdded ? 'Added to favorites' : 'Removed from favorites',
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

  Map<String, dynamic>? _findFavoriteResource(String link) {
    try {
      return resources.firstWhere(
            (r) => r['link'] == link,
      );
    } catch (e) {
      return null;
    }
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

  Widget _buildResourceCard(Map<String, dynamic> resource) {
    final isFav = favoriteLinks.contains(resource['link']);
    final dateAdded = DateTime.tryParse(resource['date'] ?? '') ?? DateTime.now();
    final trending = isTrending(resource['views'] ?? 0);
    final newResource = isNewResource(dateAdded);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await launchUrl(Uri.parse(resource['link']));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type icon and favorite button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTypeColor(resource['type']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTypeIcon(resource['type']),
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
                          resource['title'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: AppColors.textDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (resource['source'] != null)
                              _buildInfoChip(
                                icon: Icons.verified,
                                label: resource['source'],
                                color: Colors.blue[700]!,
                              ),
                            if (resource['ai_generated'] == true)
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
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : AppColors.textGray,
                    ),
                    onPressed: () => toggleFavorite(resource['link']),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Description
              Text(
                resource['description'],
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),

              // Info tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag(
                    icon: Icons.category_outlined,
                    label: resource['skill_type'] ?? 'General',
                    color: AppColors.primary,
                  ),
                  _buildTag(
                    icon: Icons.child_care,
                    label: resource['age_group'] ?? 'All Ages',
                    color: AppColors.primaryDark,
                  ),
                  _buildTag(
                    icon: Icons.remove_red_eye_outlined,
                    label: '${resource['views'] ?? 0} views',
                    color: AppColors.textDark,
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Footer with rating and action button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      int currentRating = resource['rating'] ?? 0;
                      return Icon(
                        index < currentRating ? Icons.star : Icons.star_border,
                        color: Colors.amber[700],
                        size: 18,
                      );
                    }),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(resource['link'])),
                    icon: Icon(Icons.open_in_new, size: 16),
                    label: Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 1,
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
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Video': return AppColors.accent1;
      case 'PDF': return AppColors.accent2;
      case 'Article': return AppColors.accent3;
      default: return AppColors.accent4;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Video': return Icons.play_circle_outline;
      case 'PDF': return Icons.picture_as_pdf;
      case 'Article': return Icons.article_outlined;
      default: return Icons.library_books;
    }
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
        title: const Text(
          'Educational Resources',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Favorites button with badge
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.favorite_outline, color: Colors.white),
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
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Resources',
            onPressed: _loadAIResources,
          ),
        ],
      ),

      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      )
          : Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildActivityHubCard(),  // ✅ الآن داخل child
      SizedBox(height: 20),     // ✅ الآن داخل child
      // Text(
      //   'Trusted Educational Resources',
      //   style: TextStyle(
      //     fontSize: 18,
      //     fontWeight: FontWeight.w600,
      //     color: AppColors.textDark,
      //   ),
      // ),
      // SizedBox(height: 4),
      // Text(
      //   'Evidence-based resources from trusted sources',
      //   style: TextStyle(
      //     fontSize: 14,
      //     color: AppColors.textGray,
      //   ),
      // ),
    ],
  ),
),

          // Search and Filters Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search resources...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 1),
                    ),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
                SizedBox(height: 12),

                // Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: typeOptions.map((type) {
                      final isSelected = selectedType == type;
                      return Container(
                        margin: EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (_) => setState(() => selectedType = type),
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: AppColors.surface,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 12),

                // Additional Filters
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          labelText: 'Age Group',
                          labelStyle: TextStyle(color: AppColors.textGray),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: selectedAge,
                        items: ages.map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a, style: TextStyle(fontSize: 14)),
                        )).toList(),
                        onChanged: (v) => setState(() => selectedAge = v ?? 'All Ages'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          labelText: 'Skill Type',
                          labelStyle: TextStyle(color: AppColors.textGray),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: selectedSkill,
                        items: skills.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: TextStyle(fontSize: 14)),
                        )).toList(),
                        onChanged: (v) => setState(() => selectedSkill = v ?? 'All Skills'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Resources List
          Expanded(
            child: filteredResources.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: AppColors.textLight,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No resources found',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters or search terms',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredResources.length,
              itemBuilder: (context, index) {
                return _buildResourceCard(filteredResources[index]);
              },
            ),
          ),
        ],
      ),

      // Floating Chat Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => setState(() => isChatOpen = !isChatOpen),
        child: Icon(
          isChatOpen ? Icons.close : Icons.chat_bubble_outline,
          color: Colors.white,
        ),
      ),

      // Chat Interface
      bottomSheet: isChatOpen
          ? Container(
        height: 400,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withOpacity(0.1),
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Educational Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => setState(() => isChatOpen = false),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: chatMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = chatMessages[i];
                  final isUser = msg['role'] == 'user';
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.accent1,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                          ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser ? AppColors.primary : AppColors.accent1,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              msg['text']!,
                              style: TextStyle(
                                color: isUser ? Colors.white : AppColors.textDark,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Quick Questions
            Container(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  "Early signs of autism?",
                  "Improve speech at home?",
                  "ADHD behavior tips",
                  "Motor skills activities",
                ].map((q) => Container(
                  margin: EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(q, style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      chatController.text = q;
                      sendMessage();
                    },
                    backgroundColor: AppColors.accent2,
                  ),
                )).toList(),
              ),
            ),

            // Input Area
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.accent3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: chatController,
                      decoration: InputDecoration(
                        hintText: 'Ask about special education...',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: isSending
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(Icons.send, color: Colors.white),
                      onPressed: isSending ? null : sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          : null,
    );
  }

  Widget _buildActivityHubCard() {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ActivityRecommendationHub()),
      );
    },
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.videogame_asset, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎮 Activity & Games Hub',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Get AI-based activity recommendations from medical reports',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
        ],
      ),
    ),
  );
}

}