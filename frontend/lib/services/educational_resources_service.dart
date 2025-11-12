import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EducationalResourcesService {
  
  // 🌐 Trusted sources for educational resources
  static const Map<String, List<Map<String, String>>> trustedSources = {
    'Autism Spectrum Disorder': [
      {
        'source': 'Autism Speaks',
        'url': 'https://www.autismspeaks.org',
        'type': 'Organization'
      },
      {
        'source': 'CDC Autism',
        'url': 'https://www.cdc.gov/autism',
        'type': 'Government'
      },
      {
        'source': 'National Autistic Society',
        'url': 'https://www.autism.org.uk',
        'type': 'Organization'
      },
    ],
    'Down Syndrome': [
      {
        'source': 'National Down Syndrome Society',
        'url': 'https://www.ndss.org',
        'type': 'Organization'
      },
      {
        'source': 'Down Syndrome Education International',
        'url': 'https://www.dseinternational.org',
        'type': 'Organization'
      },
    ],
    'ADHD': [
      {
        'source': 'CHADD - Children and Adults with ADHD',
        'url': 'https://chadd.org',
        'type': 'Organization'
      },
      {
        'source': 'CDC ADHD',
        'url': 'https://www.cdc.gov/adhd',
        'type': 'Government'
      },
    ],
    'Speech Delays': [
      {
        'source': 'ASHA - American Speech-Language-Hearing Association',
        'url': 'https://www.asha.org',
        'type': 'Organization'
      },
      {
        'source': 'Speech and Language Kids',
        'url': 'https://www.speechandlanguagekids.com',
        'type': 'Educational'
      },
    ],
    'Learning Disabilities': [
      {
        'source': 'Learning Disabilities Association',
        'url': 'https://ldaamerica.org',
        'type': 'Organization'
      },
      {
        'source': 'Understood.org',
        'url': 'https://www.understood.org',
        'type': 'Educational'
      },
    ],
  };

  /// Get children data for the current parent
  static Future<Map<String, dynamic>> getChildrenData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'children': []};
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/children'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'children': data['data'] ?? [],
        };
      } else {
        return {'success': false, 'children': []};
      }
    } catch (e) {
      print('Error fetching children: $e');
      return {'success': false, 'children': []};
    }
  }

  /// Generate AI-powered educational resources based on child's diagnosis
  static Future<List<Map<String, dynamic>>> generateAIResources({
    required String diagnosis,
    required int childAge,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        print('⚠️ No token, using fallback resources');
        return _getFallbackResources(diagnosis, childAge);
      }

      // Use backend AI service (Groq)
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/ai/educational-resources'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'diagnosis': diagnosis,
          'age': childAge,
        }),
      ).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['resources'] != null) {
          print('✅ Got ${(data['resources'] as List).length} AI resources from backend');
          return _formatBackendResources(data['resources'], diagnosis);
        }
      }
      
      print('⚠️ Backend AI not available, using fallback');
      return _getFallbackResources(diagnosis, childAge);
    } catch (e) {
      print('⚠️ AI request timeout or error: $e - using fallback');
      return _getFallbackResources(diagnosis, childAge);
    }
  }

  /// Format resources from backend
  static List<Map<String, dynamic>> _formatBackendResources(List<dynamic> backendResources, String diagnosis) {
    final sources = trustedSources[diagnosis] ?? [];
    
    return backendResources.map((resource) {
      final source = sources.isNotEmpty ? sources[0] : {
        'source': 'Educational Resource',
        'url': 'https://example.com',
      };
      
      return {
        'title': resource['title'] ?? 'Educational Resource',
        'description': resource['description'] ?? '',
        'type': resource['type'] ?? 'Article',
        'link': resource['link'] ?? '${source['url']}/resources',
        'age_group': resource['age_group'] ?? 'All Ages',
        'skill_type': resource['focus_area'] ?? resource['skill_type'] ?? 'General',
        'date': DateTime.now().toIso8601String().split('T')[0],
        'views': resource['views'] ?? 0,
        'rating': resource['rating'] ?? 5,
        'source': resource['source'] ?? source['source'],
        'ai_generated': true,
      };
    }).toList();
  }

  /// Parse AI response into structured resources
  static List<Map<String, dynamic>> _parseAIResponse(String aiResponse, String diagnosis) {
    try {
      // Try to extract JSON from AI response
      final jsonStart = aiResponse.indexOf('[');
      final jsonEnd = aiResponse.lastIndexOf(']') + 1;
      
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        final jsonString = aiResponse.substring(jsonStart, jsonEnd);
        final List<dynamic> parsedResources = jsonDecode(jsonString);
        
        return parsedResources.map((resource) {
          final sources = trustedSources[diagnosis] ?? [];
          final source = sources.isNotEmpty ? sources[0] : {
            'source': 'Educational Resource',
            'url': 'https://example.com',
          };
          
          return {
            'title': resource['title'] ?? 'Educational Resource',
            'description': resource['description'] ?? '',
            'type': resource['type'] ?? 'Article',
            'link': '${source['url']}/resources',
            'age_group': 'All Ages',
            'skill_type': resource['focus_area'] ?? 'General',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 0,
            'rating': 5,
            'source': source['source'],
            'ai_generated': true,
          };
        }).toList();
      }
    } catch (e) {
      print('Error parsing AI response: $e');
    }
    
    return [];
  }

  /// Normalize diagnosis to match expected format
  static String _normalizeDiagnosis(String diagnosis) {
    final normalized = diagnosis.toLowerCase().trim();
    
    if (normalized.contains('autism') || normalized.contains('asd')) {
      return 'Autism Spectrum Disorder';
    } else if (normalized.contains('down')) {
      return 'Down Syndrome';
    } else if (normalized.contains('adhd') || normalized.contains('attention')) {
      return 'ADHD';
    } else if (normalized.contains('speech') || normalized.contains('language delay')) {
      return 'Speech Delays';
    } else if (normalized.contains('learning')) {
      return 'Learning Disabilities';
    }
    
    // Return original if no match
    print('⚠️ Unknown diagnosis format: $diagnosis - using as is');
    return diagnosis;
  }

  /// Safe access to source by index
  static Map<String, dynamic> _getSource(List<Map<String, dynamic>> sources, int index) {
    if (sources.isEmpty) {
      return {'source': 'Educational Resource', 'url': 'https://www.understood.org'};
    }
    return sources[index % sources.length]; // Use modulo to cycle through sources
  }

  /// Fallback resources when AI is unavailable
  static List<Map<String, dynamic>> _getFallbackResources(String diagnosis, int childAge) {
    try {
      // Normalize diagnosis first
      final normalizedDiagnosis = _normalizeDiagnosis(diagnosis);
      print('🔄 Original diagnosis: "$diagnosis" → Normalized: "$normalizedDiagnosis"');
      
      final sources = trustedSources[normalizedDiagnosis] ?? trustedSources['Learning Disabilities']!;
      print('📚 Found ${sources.length} sources for $normalizedDiagnosis');
      
      final resources = <Map<String, dynamic>>[];
    
    // Create resources based on diagnosis
    switch (normalizedDiagnosis) {
      case 'Autism Spectrum Disorder':
        resources.addAll([
          {
            'title': 'Early Intervention Strategies for Autism',
            'description': 'Evidence-based techniques for supporting children with autism in communication and social skills development.',
            'type': 'Article',
            'link': '${_getSource(sources, 0)['url']}/early-intervention',
            'age_group': childAge < 6 ? '3-5' : childAge < 10 ? '6-9' : '10-13',
            'skill_type': 'Communication',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 250,
            'rating': 5,
            'source': _getSource(sources, 0)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Visual Schedules and Autism Support',
            'description': 'How to create and use visual schedules to help children with autism understand daily routines.',
            'type': 'Video',
            'link': '${_getSource(sources, 1)['url']}/visual-supports',
            'age_group': 'All Ages',
            'skill_type': 'Behavior',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 180,
            'rating': 5,
            'source': _getSource(sources, 1)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Social Skills Training for Children with ASD',
            'description': 'Comprehensive guide to teaching social skills through structured activities and peer interactions.',
            'type': 'PDF',
            'link': '${_getSource(sources, 2)['url']}/social-skills',
            'age_group': childAge < 10 ? '6-9' : '10-13',
            'skill_type': 'Social Skills',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 320,
            'rating': 5,
            'source': _getSource(sources, 2)['source'],
            'ai_generated': false,
          },
        ]);
        break;

      case 'Down Syndrome':
        resources.addAll([
          {
            'title': 'Speech and Language Development in Down Syndrome',
            'description': 'Practical strategies to support communication development in children with Down syndrome.',
            'type': 'Article',
            'link': '${_getSource(sources, 0)['url']}/speech-language',
            'age_group': childAge < 6 ? '3-5' : '6-9',
            'skill_type': 'Speech',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 210,
            'rating': 5,
            'source': _getSource(sources, 0)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Motor Skills Activities for Down Syndrome',
            'description': 'Fun exercises to improve fine and gross motor skills in children with Down syndrome.',
            'type': 'Video',
            'link': '${_getSource(sources, 1)['url']}/motor-skills',
            'age_group': 'All Ages',
            'skill_type': 'Motor Skills',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 190,
            'rating': 5,
            'source': _getSource(sources, 1)['source'],
            'ai_generated': false,
          },
        ]);
        break;

      case 'ADHD':
        resources.addAll([
          {
            'title': 'Managing ADHD at Home: Practical Strategies',
            'description': 'Parent-friendly techniques for creating structure and supporting focus in children with ADHD.',
            'type': 'Article',
            'link': '${_getSource(sources, 0)['url']}/home-strategies',
            'age_group': childAge < 10 ? '6-9' : '10-13',
            'skill_type': 'Focus',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 280,
            'rating': 5,
            'source': _getSource(sources, 0)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Executive Function Skills for Children with ADHD',
            'description': 'Building planning, organization, and time management skills through targeted activities.',
            'type': 'PDF',
            'link': '${_getSource(sources, 1)['url']}/executive-function',
            'age_group': '10-13',
            'skill_type': 'Executive Function',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 195,
            'rating': 4,
            'source': _getSource(sources, 1)['source'],
            'ai_generated': false,
          },
        ]);
        break;

      case 'Speech Delays':
        resources.addAll([
          {
            'title': 'Home Speech Therapy Activities',
            'description': 'ASHA-approved activities to practice speech sounds and language at home with your child.',
            'type': 'Article',
            'link': '${_getSource(sources, 0)['url']}/home-activities',
            'age_group': childAge < 6 ? '3-5' : '6-9',
            'skill_type': 'Speech',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 340,
            'rating': 5,
            'source': _getSource(sources, 0)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Articulation Therapy Techniques',
            'description': 'Evidence-based methods for improving articulation and speech clarity in children.',
            'type': 'Video',
            'link': '${_getSource(sources, 1)['url']}/articulation',
            'age_group': 'All Ages',
            'skill_type': 'Speech',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 260,
            'rating': 5,
            'source': _getSource(sources, 1)['source'],
            'ai_generated': false,
          },
        ]);
        break;

      default:
        // Learning Disabilities and other conditions
        resources.addAll([
          {
            'title': 'Understanding Learning Disabilities',
            'description': 'Comprehensive guide to different types of learning disabilities and how to support children at home and school.',
            'type': 'Article',
            'link': '${_getSource(sources, 0)['url']}/what-is',
            'age_group': childAge < 10 ? '6-9' : '10-13',
            'skill_type': 'Reading',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 280,
            'rating': 5,
            'source': _getSource(sources, 0)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Homework Help Strategies for Learning Disabilities',
            'description': 'Practical tips and techniques to make homework time easier and more productive for children with learning differences.',
            'type': 'Video',
            'link': '${_getSource(sources, 1)['url']}/homework-help',
            'age_group': 'All Ages',
            'skill_type': 'Study Skills',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 220,
            'rating': 5,
            'source': _getSource(sources, 1)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Building Self-Esteem in Children with Learning Disabilities',
            'description': 'How to support your child\'s confidence and help them recognize their strengths.',
            'type': 'Article',
            'link': '${_getSource(sources, 0)['url']}/self-esteem',
            'age_group': childAge < 10 ? '6-9' : '10-13',
            'skill_type': 'Social Skills',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 195,
            'rating': 5,
            'source': _getSource(sources, 0)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Reading Interventions That Work',
            'description': 'Evidence-based reading strategies and interventions for children with dyslexia and reading difficulties.',
            'type': 'PDF',
            'link': '${_getSource(sources, 1)['url']}/reading-help',
            'age_group': childAge < 6 ? '3-5' : '6-9',
            'skill_type': 'Reading',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 310,
            'rating': 5,
            'source': _getSource(sources, 1)['source'],
            'ai_generated': false,
          },
          {
            'title': 'Math Learning Tools and Apps',
            'description': 'Recommended tools, apps, and strategies to help children who struggle with math concepts.',
            'type': 'Article',
            'link': '${_getSource(sources, 0)['url']}/math-tools',
            'age_group': '10-13',
            'skill_type': 'Math',
            'date': DateTime.now().toIso8601String().split('T')[0],
            'views': 175,
            'rating': 4,
            'source': _getSource(sources, 0)['source'],
            'ai_generated': false,
          },
        ]);
    }
    
    print('✅ Generated ${resources.length} fallback resources for $normalizedDiagnosis');
    return resources;
    } catch (e, stackTrace) {
      print('❌ Error in _getFallbackResources: $e');
      print('Stack trace: $stackTrace');
      // Return minimal safe resources
      return [
        {
          'title': 'General Special Education Resources',
          'description': 'Comprehensive guide for parents supporting children with special needs.',
          'type': 'Article',
          'link': 'https://www.understood.org/articles',
          'age_group': 'All Ages',
          'skill_type': 'General',
          'date': DateTime.now().toIso8601String().split('T')[0],
          'views': 200,
          'rating': 4,
          'source': 'Understood.org',
          'ai_generated': false,
        },
      ];
    }
  }

  /// Get all resources combining AI and fallback
  static Future<List<Map<String, dynamic>>> getAllResources({bool useAI = false}) async {
    try {
      print('📚 Starting to fetch educational resources...');
      
      final childrenResult = await getChildrenData().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('⏱️ Children data fetch timeout');
          return {'success': false, 'children': []};
        },
      );
      
      if (childrenResult['success'] == true && 
          childrenResult['children'] is List &&
          (childrenResult['children'] as List).isNotEmpty) {
        
        final children = childrenResult['children'] as List;
        print('✅ Found ${children.length} children');
        
        // Get unique diagnoses
        final Set<String> diagnoses = {};
        int totalAge = 0;
        
        for (var child in children) {
          final diagnosis = child['diagnosis'] ?? 'Learning Disabilities';
          print('👶 Child diagnosis from API: "$diagnosis"');
          diagnoses.add(diagnosis);
          totalAge += (child['age'] ?? 7) as int;
        }
        
        final avgAge = children.isNotEmpty ? (totalAge / children.length).round() : 7;
        
        // Generate resources for unique diagnoses
        final allResources = <Map<String, dynamic>>[];
        
        for (var diagnosis in diagnoses) {
          print('🔄 Getting resources for: $diagnosis');
          
          // Use AI only if explicitly enabled and backend is available
          if (useAI) {
            final resources = await generateAIResources(
              diagnosis: diagnosis,
              childAge: avgAge,
            );
            allResources.addAll(resources);
          } else {
            // Use trusted fallback resources directly
            print('📚 Using trusted fallback resources for: $diagnosis');
            final resources = _getFallbackResources(diagnosis, avgAge);
            allResources.addAll(resources);
          }
        }
        
        print('✅ Total resources loaded: ${allResources.length}');
        return allResources;
      } else {
        print('⚠️ No children data, using general resources');
        return _getFallbackResources('Learning Disabilities', 7);
      }
    } catch (e) {
      print('❌ Error getting resources: $e - using fallback');
      return _getFallbackResources('Learning Disabilities', 7);
    }
  }
}
