// services/external_apis_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ExternalAPIsService {
  static const String _geminiApiKey = 'AIzaSyDBnknHvkGNM18a4yTAQNiAj-mO14gGQ2M';

  // 🔥 Gemini AI API
  static Future<Map<String, dynamic>> getGeminiAIResponse(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "أنت مساعد متخصص في التعليم الخاص وأطفال التوحد وفرط الحركة. أجب باللغة العربية. $prompt"}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'response': data['candidates'][0]['content']['parts'][0]['text'],
        };
      } else {
        return {
          'success': false,
          'error': 'API Error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 🔍 البحث في PubMed API
  static Future<List<dynamic>> searchPubMedArticles(String query) async {
    try {
      final response = await http.get(
        Uri.parse('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=${Uri.encodeComponent(query)}&retmode=json&retmax=3'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<String> articleIds = List<String>.from(data['esearchresult']['idlist'] ?? []);

        List<dynamic> articles = [];
        for (String id in articleIds.take(2)) {
          articles.add({
            'title': 'Research Article $id',
            'description': 'Scientific research about $query',
            'type': 'Research',
            'link': 'https://pubmed.ncbi.nlm.nih.gov/$id/',
            'source': 'PubMed',
            'condition': query.contains('autism') ? 'ASD' : 'ADHD',
          });
        }
        return articles;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 🎬 فيديوهات تعليمية (محاكاة)
  static Future<List<dynamic>> getEducationalVideos(String topic) async {
    // محاكاة البيانات حتى تضيف YouTube API Key
    await Future.delayed(Duration(seconds: 1));

    return [
      {
        'title': 'فيديو تعليمي عن $topic',
        'description': 'فيديو مفيد عن $topic للأطفال',
        'type': 'Video',
        'link': 'https://youtube.com/watch?v=example',
        'source': 'YouTube',
        'condition': topic.contains('autism') ? 'ASD' : 'ADHD',
      }
    ];
  }

  // 📚 موارد عربية متخصصة
  static Future<List<dynamic>> getSpecialEducationResources(String condition) async {
    await Future.delayed(Duration(seconds: 1));

    return [
      {
        'title': 'دليل التعامل مع $condition',
        'description': 'موارد عربية متخصصة في $condition',
        'type': 'Article',
        'link': 'https://example.com/$condition',
        'source': 'موقع متخصص',
        'condition': condition,
      }
    ];
  }
}