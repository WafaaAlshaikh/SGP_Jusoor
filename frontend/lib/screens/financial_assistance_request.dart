// lib/screens/financial_assistance_request.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../models/institution_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class FinancialAssistanceRequestScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const FinancialAssistanceRequestScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<FinancialAssistanceRequestScreen> createState() => 
      _FinancialAssistanceRequestScreenState();
}

class _FinancialAssistanceRequestScreenState 
    extends State<FinancialAssistanceRequestScreen> {
  int _selectedInstitutionId = 0;
  int _requestedSessions = 8;
  String _urgencyReason = '';
  List<File> _documentFiles = [];
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = false;
  bool _loadingInstitutions = false;
  List<Institution> _institutions = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    setState(() { _loadingInstitutions = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // جلب المؤسسات المسجلة للطفل
      final response = await ApiService.getChildren(
  token: token,  // ⬅️ استخدم named parameter
);
      final child = (response['data'] as List).firstWhere(
        (c) => c['id'] == widget.childId,
        orElse: () => null,
      );

      if (child != null && child['current_institution_id'] != null) {
        _selectedInstitutionId = child['current_institution_id'];
      }
    } catch (e) {
      print('Error loading institutions: $e');
    } finally {
      setState(() { _loadingInstitutions = false; });
    }
  }

  Future<void> _pickDocument() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() async {
        _documentFiles.add(file);
        _documents.add({
          'type': _getFileType(file.path),
          'file_data': await _encodeFile(file),
          'name': file.path.split('/').last,
          'size': await file.length(),
        });
      });
    }
  }

  String _getFileType(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return 'image';
    if (['pdf'].contains(ext)) return 'pdf';
    if (['doc', 'docx'].contains(ext)) return 'document';
    return 'other';
  }

  Future<String> _encodeFile(File file) async {
    final bytes = await file.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  void _removeDocument(int index) {
    setState(() {
      _documentFiles.removeAt(index);
      _documents.removeAt(index);
    });
  }

  // تعديل دالة _submitRequest():
Future<void> _submitRequest() async {
  if (_selectedInstitutionId == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please select an institution'),
        backgroundColor: AppColors.warning,
      ),
    );
    return;
  }

  setState(() { _isLoading = true; });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    // الحصول على تقييم الأب الحالي أولاً
    final profileResponse = await ApiService.getParentFinancialProfile(token);
    final hasAssessment = profileResponse['success'] == true && 
                         (profileResponse['data']['financial_score'] ?? 0) > 0;

    // تحديد نوع التقييم
    final assessmentType = hasAssessment ? 'general' : 'specific';

    final response = await ApiService.requestFinancialAssistance(
      token,
      childId: widget.childId,
      institutionId: _selectedInstitutionId,
      requestedSessionsCount: _requestedSessions,
      urgencyReason: _urgencyReason,
      documents: _documents,
      // يمكن إضافة هذه الحقول لاحقاً إذا تم دعمها في الـ API:
      // assessment_type: assessmentType,
      // use_existing_assessment: hasAssessment,
    );

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request submitted successfully!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      
      await Future.delayed(Duration(seconds: 2));
      Navigator.pop(context, true);
    } else {
      throw Exception(response['message'] ?? 'Request failed');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: AppColors.error,
      ),
    );
  } finally {
    setState(() { _isLoading = false; });
  }
}

  Widget _buildInstitutionSelector() {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Institution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Where will ${widget.childName} receive therapy?',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.school, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedInstitutionId == 0
                          ? 'Select Institution'
                          : 'Institution #$_selectedInstitutionId',
                      style: TextStyle(
                        color: _selectedInstitutionId == 0 
                            ? AppColors.textLight 
                            : AppColors.textDark,
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    onSelected: (value) {
                      setState(() {
                        _selectedInstitutionId = value;
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 1,
                        child: Text('Main Therapy Center'),
                      ),
                      PopupMenuItem(
                        value: 2,
                        child: Text('City Rehabilitation Center'),
                      ),
                      PopupMenuItem(
                        value: 3,
                        child: Text('Special Needs Academy'),
                      ),
                    ],
                    child: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsSelector() {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Number of Sessions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Recommended: 8 sessions per month',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            Slider(
              value: _requestedSessions.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '$_requestedSessions sessions',
              onChanged: (value) {
                setState(() {
                  _requestedSessions = value.toInt();
                });
              },
              activeColor: AppColors.primary,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 session', style: TextStyle(fontSize: 12)),
                Text('20 sessions', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencySection() {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Urgency Reason (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Explain why this request is urgent',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'E.g., Financial hardship, urgent medical need...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.accent3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (value) => _urgencyReason = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Supporting Documents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Upload documents to support your request (income proof, ID, etc.)',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            _documentFiles.isEmpty
                ? Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent3,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.folder_open, size: 48, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Text(
                          'No documents uploaded',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _documentFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return ListTile(
                        leading: Icon(Icons.insert_drive_file, color: AppColors.primary),
                        title: Text(
                          file.path.split('/').last,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => _removeDocument(index),
                        ),
                      );
                    }).toList(),
                  ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickDocument,
              icon: Icon(Icons.upload_file),
              label: Text('Upload Document'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info),
              SizedBox(width: 8),
              Text(
                'What Happens Next?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '1. Request submitted for review\n'
            '2. Institution evaluates your financial situation\n'
            '3. Decision within 3-7 business days\n'
            '4. You\'ll receive a notification with the decision',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Assistance Request'),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(20),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.attach_money, color: Colors.white, size: 24),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Financial Assistance Request',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'For ${widget.childName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form Sections
                  _buildInstitutionSelector(),
                  _buildSessionsSelector(),
                  _buildUrgencySection(),
                  _buildDocumentsSection(),
                  _buildInfoCard(),

                  SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitRequest,
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.send),
                      label: Text(
                        _isLoading ? 'Submitting...' : 'Submit Request',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}