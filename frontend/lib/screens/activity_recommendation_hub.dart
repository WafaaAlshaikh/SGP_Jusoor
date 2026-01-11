import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/child_model.dart';
import '../models/activity_recommendation.dart';
import '../theme/app_colors.dart';

class ActivityRecommendationHub extends StatefulWidget {
  @override
  _ActivityRecommendationHubState createState() =>
      _ActivityRecommendationHubState();
}

class _ActivityRecommendationHubState extends State<ActivityRecommendationHub> {
  // State variables
  List<Child> _children = [];
  Child? _selectedChild;
  File? _selectedDocument;
  String? _documentName;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  List<ActivityRecommendation> _recommendations = [];
  String _analysisStatus = 'idle';
  String? _analysisId;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  // جلب قائمة الأطفال

  Future<void> _loadChildren() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        _showError('Please login first');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('🔄 Loading children with token: ${token.substring(0, 20)}...');

      // ✅ التصحيح الرئيسي: استخدام named parameters بشكل صحيح
      final response = await ApiService.getChildren(
        token: token,
        page: 1,
        limit: 100,
      );

      print('📦 API Response: $response');

      if (response['data'] != null) {
        final childrenData = response['data'] as List;

        print('👶 Found ${childrenData.length} children');

        if (childrenData.isEmpty) {
          _showError('No children found. Please add a child first.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _children = childrenData.map((c) {
            print('🔄 Parsing child: $c');
            return Child.fromJson(c);
          }).toList();

          if (_children.isNotEmpty) {
            _selectedChild = _children.first;
            print('✅ Selected first child: ${_selectedChild!.fullName}');
          }

          _isLoading = false;
        });

        // تحميل التوصيات السابقة بعد اختيار الطفل
        if (_selectedChild != null) {
          _loadPreviousRecommendations();
        }
      } else {
        throw Exception('Invalid response format: no data field');
      }
    } catch (e) {
      print('❌ Error loading children: $e');
      _showError('Failed to load children: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

// ✅ تصحيح دالة _loadPreviousRecommendations أيضاً
  Future<void> _loadPreviousRecommendations() async {
  if (_selectedChild == null) return;
  
  try {
    print('📥 Loading activities for child ${_selectedChild!.id}');
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    
    final response = await ApiService.getActivityRecommendations(
      token, 
      _selectedChild!.id.toString()
    );
    
    print('📊 Activities API Response:');
    print('   - Success: ${response['success']}');
    print('   - Has data: ${response['data'] != null}');
    print('   - Data type: ${response['data']?.runtimeType}');
    
    if (response['success'] == true && response['data'] != null) {
      final recommendationsData = response['data'] as List;
      print('   - Found ${recommendationsData.length} activities');
      
      for (int i = 0; i < recommendationsData.length; i++) {
        print('   Activity $i: ${recommendationsData[i]['id']} - ${recommendationsData[i]['title_ar']}');
      }
      
      setState(() {
        _recommendations = recommendationsData.map((r) => ActivityRecommendation.fromJson(r)).toList();
      });
    } else {
      print('⚠️ No activities found or API error');
      _showError('لا توجد أنشطة مسجلة لهذا الطفل');
    }
  } catch (e) {
    print('❌ Error loading activities: $e');
  }
}

  // اختيار ملف
  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'txt'],
    );

    if (result != null) {
      setState(() {
        _selectedDocument = File(result.files.single.path!);
        _documentName = result.files.single.name;
      });
    }
  }

  // رفع المستند
  Future<void> _uploadDocument() async {
    if (_selectedChild == null || _selectedDocument == null) {
      _showError('Please select a child and a document first');
      return;
    }

    setState(() {
      _isLoading = true;
      _analysisStatus = 'uploading';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      print('📤 Uploading document for child: ${_selectedChild!.id}');
      print('📄 File: ${_selectedDocument!.path}');

      // ✅ التصحيح: تحويل child_id إلى String بشكل صحيح
      final response = await ApiService.uploadActivityDocument(
          token,
          _selectedChild!.id
              .toString(), // ✅ هنا المشكلة - كان بيمرر int بدل String
          _selectedDocument!);

      print('✅ Upload response: $response');

      if (response['success'] == true) {
        setState(() {
          _analysisId =
              response['analysis_id']?.toString(); // ✅ تأكد من تحويله لـ String
          _analysisStatus = 'uploaded';
        });
        _showSuccess('Document uploaded successfully! Ready for analysis.');
      } else {
        _showError(response['message'] ?? 'Upload failed');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      _showError('Upload error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // تحليل المستند
  // In ActivityRecommendationHub - update the _analyzeDocument method

Future<void> _analyzeDocument() async {
  if (_selectedChild == null) {
    _showError('Please select a child first');
    return;
  }

  setState(() {
    _isAnalyzing = true;
    _analysisStatus = 'analyzing';
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    print('🔍 Analyzing document for child: ${_selectedChild!.id}');
    print('📋 Analysis ID: $_analysisId');

    final response = await ApiService.analyzeForActivities(
      token, 
      _selectedChild!.id.toString(),
      analysisId: _analysisId
    );

    print('✅ Analysis response: $response');

    if (response['success'] == true) {
      setState(() {
        _analysisResult = response;
        _analysisStatus = 'completed';

        // ✅ Check if activities have real IDs
        if (response['recommendations'] != null) {
          final recs = response['recommendations'] as List;
          _recommendations = recs
              .map((r) {
                try {
                  final activity = ActivityRecommendation.fromJson(r);
                  
                  // ✅ Verify that the activity has a real ID
                  if (activity.id == 0 || activity.id == null) {
                    print('⚠️ Activity has no valid ID: ${r['title_ar']}');
                    // You might want to skip or mark these activities
                  }
                  
                  return activity;
                } catch (e) {
                  print('❌ Error parsing recommendation: $e');
                  return null;
                }
              })
              .whereType<ActivityRecommendation>()
              .toList();
        }
      });
      
      // ✅ Filter out activities without valid IDs
      _recommendations = _recommendations.where((a) => a.id != null && a.id > 0).toList();
      
      _showSuccess(
        'Analysis completed! Found ${_recommendations.length} activities.'
      );
    } else {
      _showError(response['message'] ?? 'Analysis failed');
    }
  } catch (e) {
    print('❌ Analysis error: $e');
    _showError('Analysis error: $e');
  } finally {
    setState(() {
      _isAnalyzing = false;
    });
  }
}

  // تحليل سريع (بدون مستند)
  Future<void> _quickAnalysis() async {
    if (_selectedChild == null) {
      _showError('Please select a child first');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisStatus = 'analyzing';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      print('⚡ Quick analysis for child: ${_selectedChild!.id}');

      // ✅ تأكد من تحويل ID لـ String
      final response = await ApiService.quickActivityAnalysis(
          token, _selectedChild!.id.toString() // ✅ String
          );

      print('✅ Quick analysis response: $response');

      if (response['success'] == true) {
        setState(() {
          _analysisResult = response;
          _analysisStatus = 'completed';

          if (response['recommendations'] != null) {
            final recs = response['recommendations'] as List;
            _recommendations = recs
                .map((r) {
                  try {
                    return ActivityRecommendation.fromJson(r);
                  } catch (e) {
                    print('❌ Error parsing recommendation: $e');
                    return null;
                  }
                })
                .whereType<ActivityRecommendation>()
                .toList();
          }
        });
        _showSuccess(
            'Quick analysis completed! Found ${_recommendations.length} activities.');
      } else {
        _showError(response['message'] ?? 'Analysis failed');
      }
    } catch (e) {
      print('❌ Quick analysis error: $e');
      _showError('Quick analysis error: ${e.toString()}');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // ✅ تصحيح: استخدام copyWith لتحديث النشاط
  // In ActivityRecommendationHub - update the _updateActivityStatus method

Future<void> _updateActivityStatus(
    ActivityRecommendation activity, String status) async {
  if (_selectedChild == null) {
    _showError('No child selected');
    return;
  }

  // ✅ Validate that the activity has a real ID
  if (activity.id == null || activity.id <= 0) {
    _showError('Cannot update activity: Invalid activity ID');
    return;
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    print('🔄 Updating activity ${activity.id} to status: $status');

    await ApiService.updateActivityStatus(
      token,
      _selectedChild!.id.toString(),
      activity.id.toString(), // ✅ Now this is a real database ID
      status
    );

    // Update the list
    setState(() {
      final index = _recommendations.indexWhere((a) => a.id == activity.id);
      if (index != -1) {
        _recommendations[index] = activity.copyWith(
          status: status,
          completedAt: status == 'completed' ? DateTime.now() : null,
        );
      }
    });

    _showSuccess('Activity updated: $status');
  } catch (e) {
    print('❌ Error updating activity: $e');
    _showError('Failed to update: ${e.toString()}');
  }
}

  // عرض رسائل
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      duration: Duration(seconds: 3),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.success,
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🎮 Activity & Games Hub'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
      icon: Icon(Icons.refresh),
      onPressed: () {
        if (_selectedChild != null) {
          _loadPreviousRecommendations();
        }
      },
    ),
          if (_recommendations.isNotEmpty)
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
            ),
        ],
      ),
      body: _isLoading && _children.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // قسم اختيار الطفل
                  _buildChildSelection(),
                  SizedBox(height: 20),

                  // قسم رفع المستند
                  _buildDocumentUpload(),
                  SizedBox(height: 20),

                  // قسم التحليل
                  if (_analysisStatus != 'idle') _buildAnalysisSection(),
                  SizedBox(height: 20),

                  // عرض النتائج
                  if (_analysisResult != null) _buildAnalysisResults(),

                  // عرض التوصيات
                  if (_recommendations.isNotEmpty)
                    _buildActivityRecommendations(),

                  // رسالة إذا لم توجد توصيات
                  if (_recommendations.isEmpty &&
                      _analysisStatus == 'completed')
                    _buildNoRecommendations(),

                  if (_recommendations.isEmpty &&
                      _analysisStatus == 'idle' &&
                      _children.isNotEmpty)
                    _buildWelcomeMessage(),
                ],
              ),
            ),
    );
  }

  Widget _buildChildSelection() {
  return Card(
    elevation: 2,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Child',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12),
          
          // ✅ عرض loading state بشكل أفضل
          if (_isLoading)
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 8),
                  Text(
                    'Loading children...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            )
          else if (_children.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.child_care, size: 48, color: AppColors.textLight),
                  SizedBox(height: 8),
                  Text(
                    'No children found',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Navigate to add child page
                      Navigator.pushNamed(context, '/add-child');
                    },
                    child: Text('Add a child'),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<Child>(
              value: _selectedChild,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              hint: Text('Select a child'),
              items: _children.map((Child child) {
                return DropdownMenuItem<Child>(
                  value: child,
                  child: Row(
                    children: [
                      // صورة الطفل (اختياري)
                      if (child.photo.isNotEmpty && child.photo.startsWith('http'))
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(child.photo),
                        )
                      else
                        CircleAvatar(
                          radius: 16,
                          child: Text(
                            child.fullName[0].toUpperCase(),
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              child.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Text(
                            //   '${child.age} years old',
                            //   style: TextStyle(
                            //     fontSize: 12,
                            //     color: Colors.grey,
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (Child? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedChild = newValue;
                    _recommendations = [];
                    _analysisResult = null;
                    _analysisStatus = 'idle';
                  });
                  
                  print('✅ Child selected: ${newValue.fullName}');
                  _loadPreviousRecommendations();
                }
              },
            ),
        ],
      ),
    ),
  );
}
  Widget _buildDocumentUpload() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Assessment Document',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Upload medical reports, assessment documents, or therapy notes for personalized activity recommendations',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.upload_file),
                    label:
                        Text(_documentName ?? 'Choose File (PDF, Image, Doc)'),
                    onPressed: _pickDocument,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                if (_selectedDocument != null)
                  IconButton(
                    icon: Icon(Icons.delete, color: AppColors.error),
                    onPressed: () {
                      setState(() {
                        _selectedDocument = null;
                        _documentName = null;
                      });
                    },
                  ),
              ],
            ),
            SizedBox(height: 12),
            if (_selectedDocument != null)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.cloud_upload),
                          label: Text('Upload & Analyze'),
                          onPressed: _isLoading ? null : _uploadDocument,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
              ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.bolt),
                    label: Text('Quick Analysis (No Document)'),
                    onPressed: _isAnalyzing ? null : _quickAnalysis,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading || _isAnalyzing)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    SizedBox(width: 12),
                    Text(
                      _isLoading ? 'Uploading...' : 'Analyzing...',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _getStatusDescription(),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_analysisStatus == 'uploaded')
                  ElevatedButton(
                    onPressed: _isAnalyzing ? null : _analyzeDocument,
                    child: Text('Start Analysis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_analysisStatus) {
      case 'uploading':
        return Icons.cloud_upload;
      case 'uploaded':
        return Icons.task_alt;
      case 'analyzing':
        return Icons.psychology;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor() {
    switch (_analysisStatus) {
      case 'completed':
        return AppColors.success;
      case 'uploaded':
        return AppColors.info;
      case 'analyzing':
        return AppColors.warning;
      default:
        return AppColors.textGray;
    }
  }

  String _getStatusTitle() {
    switch (_analysisStatus) {
      case 'uploading':
        return 'Uploading Document';
      case 'uploaded':
        return 'Document Ready for Analysis';
      case 'analyzing':
        return 'Analyzing with AI';
      case 'completed':
        return 'Analysis Complete';
      default:
        return 'Ready';
    }
  }

  String _getStatusDescription() {
    switch (_analysisStatus) {
      case 'uploading':
        return 'Please wait while we upload your document...';
      case 'uploaded':
        return 'Click "Start Analysis" to generate personalized activities';
      case 'analyzing':
        return 'AI is analyzing the document and generating activity recommendations';
      case 'completed':
        return 'Found ${_recommendations.length} personalized activities';
      default:
        return 'Upload a document to get started';
    }
  }

  Widget _buildAnalysisResults() {
    if (_analysisResult == null) return SizedBox();

    final analysis = _analysisResult!['analysis'] as Map<String, dynamic>?;
    if (analysis == null) return SizedBox();

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Results',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            if (analysis['primary_condition'] != null)
              _buildAnalysisItem(
                'Primary Condition',
                '${analysis['primary_condition']['name_ar']} / ${analysis['primary_condition']['name_en']}',
                Icons.medical_services,
              ),
            if (analysis['child_age'] != null)
              _buildAnalysisItem(
                'Child Age',
                '${analysis['child_age']} years',
                Icons.cake,
              ),
            if (analysis['severity_level'] != null)
              _buildAnalysisItem(
                'Severity Level',
                analysis['severity_level'],
                Icons.assessment,
              ),
            SizedBox(height: 8),
            Divider(),
            SizedBox(height: 8),
            Text(
              'Focus Areas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (analysis['recommended_focus_areas'] as List? ?? [])
                  .take(5)
                  .map((area) => Chip(
                        label: Text(area.toString()),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(String title, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recommended Activities (${_recommendations.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.filter_list, size: 16),
                label: Text('Filter'),
                onPressed: _showFilterDialog,
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _recommendations.length,
          separatorBuilder: (context, index) => SizedBox(height: 12),
          itemBuilder: (context, index) {
            final activity = _recommendations[index];
            return _buildActivityCard(activity);
          },
        ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityRecommendation activity) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getActivityTypeColor(activity.activityType)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActivityTypeIcon(activity.activityType),
                    color: _getActivityTypeColor(activity.activityType),
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.titleAr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        activity.titleEn,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        activity.activityTypeDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getActivityTypeColor(activity.activityType),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(activity.status),
              ],
            ),

            SizedBox(height: 12),

            Text(
              activity.descriptionAr,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 12),

            // معلومات إضافية
            Wrap(
              spacing: 12,
              children: [
                if (activity.durationMinutes > 0)
                  _buildInfoChip(
                    Icons.timer,
                    '${activity.durationMinutes} min',
                  ),
                if (activity.difficultyLevel.isNotEmpty)
                  _buildInfoChip(
                    Icons.speed,
                    activity.difficultyDisplay,
                  ),
                if (activity.materialsAr.isNotEmpty)
                  _buildInfoChip(
                    Icons.build,
                    'Materials',
                  ),
              ],
            ),

            SizedBox(height: 12),

            // المهارات المستهدفة
            if (activity.targetSkillsAr.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Skills:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    activity.targetSkillsAr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

            SizedBox(height: 12),

            // أزرار الإجراءات
            if (activity.status != 'completed')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.play_arrow, size: 16),
                      label: Text('Start Activity'),
                      onPressed: () =>
                          _updateActivityStatus(activity, 'in_progress'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.check, size: 16),
                      label: Text('Mark Complete'),
                      onPressed: () =>
                          _updateActivityStatus(activity, 'completed'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),

            if (activity.status == 'completed')
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.success, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Completed ${activity.completionDateDisplayEn}',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
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

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'suggested':
        backgroundColor = AppColors.info.withOpacity(0.1);
        textColor = AppColors.info;
        label = 'Suggested';
        break;
      case 'in_progress':
        backgroundColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        label = 'In Progress';
        break;
      case 'completed':
        backgroundColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        label = 'Completed';
        break;
      default:
        backgroundColor = AppColors.textLight.withOpacity(0.1);
        textColor = AppColors.textGray;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textGray),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Color _getActivityTypeColor(String type) {
    switch (type) {
      case 'motor_skills':
        return Colors.blue;
      case 'social_skills':
        return Colors.green;
      case 'cognitive_skills':
        return Colors.orange;
      case 'communication_skills':
        return Colors.purple;
      case 'sensory_activities':
        return Colors.pink;
      case 'daily_living_skills':
        return Colors.teal;
      default:
        return AppColors.primary;
    }
  }

  IconData _getActivityTypeIcon(String type) {
    switch (type) {
      case 'motor_skills':
        return Icons.directions_run;
      case 'social_skills':
        return Icons.people;
      case 'cognitive_skills':
        return Icons.psychology;
      case 'communication_skills':
        return Icons.chat;
      case 'sensory_activities':
        return Icons.brush;
      case 'daily_living_skills':
        return Icons.home;
      default:
        return Icons.gamepad;
    }
  }

  Widget _buildNoRecommendations() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.gamepad, size: 48, color: AppColors.textLight),
            SizedBox(height: 16),
            Text(
              'No Activities Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Upload a document or try quick analysis to get personalized activity recommendations for your child.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.upload_file),
              label: Text('Upload Document'),
              onPressed: _pickDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Welcome to Activity Hub!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Get personalized activity recommendations for your child based on their medical reports and assessment documents.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            Column(
              children: [
                ListTile(
                  leading: Icon(Icons.upload_file, color: AppColors.primary),
                  title: Text('Upload Medical Report'),
                  subtitle: Text('For personalized recommendations'),
                ),
                ListTile(
                  leading: Icon(Icons.bolt, color: AppColors.primary),
                  title: Text('Quick Analysis'),
                  subtitle: Text('Based on child\'s basic information'),
                ),
                ListTile(
                  leading: Icon(Icons.history, color: AppColors.primary),
                  title: Text('View Previous Activities'),
                  subtitle: Text('Check activities suggested earlier'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter Activities'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // يمكن إضافة فلاتر هنا
                Text('Filter options coming soon...'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
