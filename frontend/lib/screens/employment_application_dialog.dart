import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

class EmploymentApplicationDialog extends StatefulWidget {
  final List<dynamic> institutions;

  const EmploymentApplicationDialog({
    Key? key,
    required this.institutions,
  }) : super(key: key);

  @override
  State<EmploymentApplicationDialog> createState() => _EmploymentApplicationDialogState();
}

class _EmploymentApplicationDialogState extends State<EmploymentApplicationDialog> {
  final List<int> _selectedInstitutions = [];
  File? _cvFile;
  bool _isSubmitting = false;
  String? _cvFileName;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _yearsExperienceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Apply for Employment',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textGray),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              'Submit your CV to apply for specialist positions',
              style: TextStyle(color: AppColors.textGray, fontSize: 14),
            ),
            
            const SizedBox(height: 24),
            
            // CV Upload Section
            _buildCVUploadSection(),
            
            const SizedBox(height: 20),
            
            // Personal Information (filled from AI analysis)
            _buildPersonalInfoSection(),
            
            const SizedBox(height: 20),
            
            // Institutions Selection
            _buildInstitutionsSelection(),
            
            const SizedBox(height: 30),
            
            // Submit Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCVUploadSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Your CV (Required)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Supported formats: PDF, DOC, DOCX, JPG, PNG',
            style: TextStyle(fontSize: 13, color: AppColors.textGray),
          ),
          const SizedBox(height: 16),
          
          if (_cvFile == null)
            ElevatedButton.icon(
              onPressed: _pickCVFile,
              icon: Icon(Icons.upload_file, size: 20),
              label: Text('Select CV File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.file_present, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cvFileName!,
                          style: TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${(_cvFile!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _cvFile = null;
                        _cvFileName = null;
                        _clearExtractedInfo();
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.autorenew, color: AppColors.primary),
                    onPressed: _pickCVFile,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100] ?? Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Text(
                'Information extracted from CV',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _specializationController,
                  decoration: InputDecoration(
                    labelText: 'Specialization',
                    prefixIcon: Icon(Icons.work),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _yearsExperienceController,
                  decoration: InputDecoration(
                    labelText: 'Years Experience',
                    prefixIcon: Icon(Icons.timeline),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          Text(
            'Please verify and edit the extracted information if needed',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Institutions to Apply',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your application will be sent to all selected institutions',
          style: TextStyle(fontSize: 13, color: AppColors.textGray),
        ),
        const SizedBox(height: 12),
        
        Container(
          constraints: BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.institutions.length,
            itemBuilder: (context, index) {
              final inst = widget.institutions[index];
              final isSelected = _selectedInstitutions.contains(inst['institution_id']);
              
              return CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedInstitutions.add(inst['institution_id']);
                    } else {
                      _selectedInstitutions.remove(inst['institution_id']);
                    }
                  });
                },
                title: Text(
                  inst['name']?.toString() ?? 'Unknown',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: inst['city'] != null 
                    ? Text(inst['city'].toString(), style: TextStyle(fontSize: 12))
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting || _cvFile == null || _selectedInstitutions.isEmpty
            ? null
            : _submitApplication,
        icon: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(Icons.send),
        label: Text(_isSubmitting ? 'Submitting...' : 'Submit Application'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _pickCVFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _cvFile = File(result.files.single.path!);
          _cvFileName = result.files.single.name;
        });

        // Analyze CV with AI
        await _analyzeCV();
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }
  static String _buildUrl(String endpoint) {
    if (kIsWeb) {
      return 'http://localhost:5000/api/$endpoint';
    } else {
      return 'http://10.0.2.2:5000/api/$endpoint';
    }
  }

  Future<void> _analyzeCV() async {
    if (_cvFile == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Analyzing CV with AI...'),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(_buildUrl('employment/cv/analyze')),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'cv_file',
          _cvFile!.path,
          filename: _cvFileName,
        ),
      );

      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (jsonResponse['success'] == true) {
        final extractedInfo = jsonResponse['extracted_info'];
        
        setState(() {
          _fullNameController.text = extractedInfo['full_name'] ?? '';
          _emailController.text = extractedInfo['email'] ?? '';
          _phoneController.text = extractedInfo['phone'] ?? '';
          _specializationController.text = extractedInfo['specialization'] ?? '';
          _yearsExperienceController.text = extractedInfo['years_experience']?.toString() ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ CV analyzed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to analyze CV');
      }
    } catch (e) {
      print('CV analysis error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Could not auto-fill information. Please enter manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _clearExtractedInfo() {
    setState(() {
      _fullNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _specializationController.clear();
      _yearsExperienceController.clear();
    });
  }

  Future<void> _submitApplication() async {
    if (_cvFile == null || _selectedInstitutions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please upload CV and select at least one institution')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Prepare request data
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(_buildUrl('employment/apply')),
      );

      request.headers['Authorization'] = 'Bearer $token';
      
      // Add CV file
      request.files.add(
        await http.MultipartFile.fromPath(
          'cv_file',
          _cvFile!.path,
          filename: _cvFileName,
        ),
      );

      // Add form data
      request.fields.addAll({
        'full_name': _fullNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'specialization': _specializationController.text,
        'years_experience': _yearsExperienceController.text,
        'institution_ids': _selectedInstitutions.join(','),
      });

      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (jsonResponse['success'] == true) {
        Navigator.pop(context); // Close dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Application submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Show additional info if available
        if (jsonResponse['temporary_password'] != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Account Created'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your temporary password is:'),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    color: Colors.grey[100],
                    child: Text(
                      jsonResponse['temporary_password'],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Please save this password. You can use it to login and change your password later.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(jsonResponse['message'] ?? 'Submission failed');
      }
    } catch (e) {
      print('Submission error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit application: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _yearsExperienceController.dispose();
    super.dispose();
  }
}