
// lib/screens/manage_children/widgets/child_form_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/child_model.dart';
import '../../../services/api_service.dart';
import '../../../screens/map_screen.dart';
import '../theme/app_colors.dart';
enum ChildFormStep { basicInfo, medicalInfo, selectInstitution, confirmation }

class ChildFormDialog extends StatefulWidget {
  final Child? child;
  final Map<String, dynamic>? screeningData;

  const ChildFormDialog({
    super.key,
    this.child,
    this.screeningData,
  });

  @override
  State<ChildFormDialog> createState() => _ChildFormDialogState();
}

class _ChildFormDialogState extends State<ChildFormDialog> {
  final _formKey = GlobalKey<FormState>();
  ChildFormStep _currentStep = ChildFormStep.basicInfo;
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSmartSearching = false;
  List<dynamic> _smartSearchResults = [];

  // Child basic data
  late String _fullName;
  late String _dateOfBirth;
  String _gender = 'Male';
  String _photo = '';
  String _childIdentifier = '';
  String _schoolInfo = '';
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _dateController = TextEditingController();

  // Location data
  String _city = '';
  String _address = '';
  double? _locationLat;
  double? _locationLng;

  // Medical data
  int? _selectedDiagnosisId;
  String _suspectedCondition = '';
  String _symptomsDescription = '';
  String _medicalHistory = '';
  String _previousServices = '';
  String _additionalNotes = '';

  // AI analysis
  Map<String, dynamic>? _aiAnalysisResult;
  List<dynamic> _recommendedInstitutions = [];
  bool _isAnalyzing = false;

  // Institution selection
  int? _selectedInstitutionId;
  String _registrationNotes = '';
  bool _consentGiven = false;

  // Filter states
  bool _showAdvancedFilters = false;
  double _minRating = 0.0;
  double _maxPrice = 1000.0;
  bool _filterByMatchingServices = false;
  List<String> _activeFilters = [];

  // Loading state
  bool _isLoading = false;
  String? _childId;

  List<Map<String, dynamic>> _diagnoses = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _currentStep = ChildFormStep.basicInfo;
    _loadDiagnoses();
    _processScreeningData();
  }

  void _processScreeningData() {
    if (widget.screeningData == null) return;

    print('🎯 Processing screening data in Child Form');
    final screeningData = widget.screeningData!;

    if (screeningData['suspected_condition'] != null) {
      _suspectedCondition = screeningData['suspected_condition'].toString();
    }

    if (screeningData['symptoms_description'] != null) {
      _symptomsDescription = screeningData['symptoms_description'].toString();
    }

    if (screeningData['recommended_institutions'] != null) {
      _recommendedInstitutions = screeningData['recommended_institutions'];
      print('   - Loaded ${_recommendedInstitutions.length} recommended institutions from screening');
    }
  }

  void _initializeForm() {
    if (widget.child != null) {
      _fullName = widget.child!.fullName;
      _dateOfBirth = widget.child!.dateOfBirth;
      _gender = widget.child!.gender;
      _photo = widget.child!.photo;
      _childIdentifier = widget.child!.childIdentifier ?? '';
      _schoolInfo = widget.child!.schoolInfo ?? '';
      _medicalHistory = widget.child!.medicalHistory;
      _selectedDiagnosisId = widget.child!.diagnosisId;
      _suspectedCondition = widget.child!.suspectedCondition ?? '';
      _symptomsDescription = widget.child!.symptomsDescription ?? '';
      _previousServices = widget.child!.previousServices ?? '';
      _additionalNotes = widget.child!.additionalNotes ?? '';
    } else {
      _fullName = '';
      _dateOfBirth = '';
      _gender = 'Male';
      _photo = '';
      _childIdentifier = '';
      _schoolInfo = '';
      _medicalHistory = '';
      _suspectedCondition = '';
      _symptomsDescription = '';
      _previousServices = '';
      _additionalNotes = '';
    }
    _dateController.text = _dateOfBirth;
  }

  Future<void> _loadDiagnoses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('No token available');
      }

      final data = await ApiService.getDiagnoses(token);
      setState(() {
        _diagnoses = data;
      });

      print('Loaded ${_diagnoses.length} diagnoses');
    } catch (e) {
      print('Error loading diagnoses: $e');
      final defaultDiagnoses = [
        {'diagnosis_id': 1, 'name': 'Autism Spectrum Disorder'},
        {'diagnosis_id': 2, 'name': 'Attention Deficit Hyperactivity Disorder (ADHD)'},
        {'diagnosis_id': 3, 'name': 'Down Syndrome'},
        {'diagnosis_id': 4, 'name': 'Speech and Language Delay'},
      ];
      setState(() {
        _diagnoses = defaultDiagnoses;
      });
      print('Using default diagnoses list (${_diagnoses.length} items)');
    }
  }

  Future<void> _performSmartSearch(String query) async {
    if (query.length < 3) {
      setState(() {
        _isSmartSearching = false;
        _smartSearchResults = [];
      });
      return;
    }

    setState(() => _isSmartSearching = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final result = await ApiService.searchBySymptoms(token, query, null);

      if (result['success'] == true) {
        setState(() {
          _smartSearchResults = result['symptoms_analysis']?['suggested_conditions'] ?? [];
        });

        _autoFillFromSearchResults(result);
      }
    } catch (e) {
      print('Smart search error: $e');
    } finally {
      setState(() => _isSmartSearching = false);
    }
  }

  void _autoFillFromSearchResults(Map<String, dynamic> result) {
    final conditions = result['symptoms_analysis']?['suggested_conditions'] ?? [];
    if (conditions.isNotEmpty) {
      final topCondition = conditions.first;
      setState(() {
        _suspectedCondition = topCondition['arabic_name'] ?? topCondition['name'] ?? '';
        _tryMatchDiagnosis(_suspectedCondition);
      });
    }
  }

  void _tryMatchDiagnosis(String condition) {
    final matched = _diagnoses.firstWhere(
          (d) => d['name'].toString().toLowerCase().contains(condition.toLowerCase()),
      orElse: () => <String, dynamic>{},
    );

    if (matched.isNotEmpty) {
      setState(() {
        _selectedDiagnosisId = matched['diagnosis_id'];
      });
    }
  }

  Future<void> _saveBasicInfo() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _formKey.currentState?.save();

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final basicInfo = {
        'full_name': _fullName,
        'date_of_birth': _dateController.text,
        'gender': _gender,
        'child_identifier': _childIdentifier.isEmpty ? null : _childIdentifier,
        'school_info': _schoolInfo.isEmpty ? null : _schoolInfo,
        'photo': _photo.isEmpty ? null : _photo,
        'city': _city.isEmpty ? null : _city,
        'address': _address.isEmpty ? null : _address,
        'location_lat': _locationLat,
        'location_lng': _locationLng,
      };

      print('Saving child basic info: $basicInfo');

      final result = await ApiService.saveChildBasicInfo(token, basicInfo);

      if (result['success'] == true) {
        final childId = result['child_id']?.toString();
        print('Child ID received: $childId');

        if (childId == null) {
          throw Exception('Child ID is null from server');
        }

        setState(() {
          _childId = childId;
          _currentStep = ChildFormStep.medicalInfo;
          _isLoading = false;
        });

        if (widget.screeningData != null && widget.screeningData!['from_screening'] == true) {
          print('🎯 Auto-analyzing from screening data...');

          if (widget.screeningData!['suspected_condition'] != null) {
            _suspectedCondition = widget.screeningData!['suspected_condition'].toString();
          }
          if (widget.screeningData!['symptoms_description'] != null) {
            _symptomsDescription = widget.screeningData!['symptoms_description'].toString();
          }

          if (widget.screeningData!['recommended_institutions'] != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _recommendedInstitutions = widget.screeningData!['recommended_institutions'];
                _currentStep = ChildFormStep.selectInstitution;
              });
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Basic information saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to save basic information');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _analyzeMedicalCondition() async {
    print('Starting medical analysis');

    final hasSymptoms = _symptomsDescription.trim().isNotEmpty;
    final hasSuspectedCondition = _suspectedCondition.trim().isNotEmpty;
    final hasDiagnosis = _selectedDiagnosisId != null;

    print('Current Medical Data:');
    print('   - Symptoms: $hasSymptoms');
    print('   - Suspected Condition: $hasSuspectedCondition');
    print('   - Diagnosis: $hasDiagnosis');
    print('   - Child ID: $_childId');

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final medicalData = <String, dynamic>{};

      if (hasDiagnosis) {
        medicalData['diagnosis_id'] = _selectedDiagnosisId;
      }

      if (hasSuspectedCondition) {
        medicalData['suspected_condition'] = _suspectedCondition;
      }

      if (hasSymptoms) {
        medicalData['symptoms_description'] = _symptomsDescription;
      }

      if (_medicalHistory.isNotEmpty) {
        medicalData['medical_history'] = _medicalHistory;
      }

      if (_previousServices.isNotEmpty) {
        medicalData['previous_services'] = _previousServices;
      }

      if (_additionalNotes.isNotEmpty) {
        medicalData['additional_notes'] = _additionalNotes;
      }

      print('Final medical data to send: $medicalData');

      if (medicalData.isEmpty) {
        throw Exception('No medical data to analyze');
      }

      final result = await ApiService.analyzeMedicalCondition(token, _childId!, medicalData);

      print('API Response: ${result['success']}');

      if (result['success'] == true) {
        print('Analysis successful!');
        print('Target conditions: ${result['target_conditions']}');

        final dynamic institutionsData = result['recommended_institutions'];
        List<dynamic> institutionsList = [];

        if (institutionsData != null) {
          if (institutionsData is List) {
            institutionsList = institutionsData;
          } else if (institutionsData is Map) {
            if (institutionsData['institutions'] != null && institutionsData['institutions'] is List) {
              institutionsList = institutionsData['institutions'];
            } else if (institutionsData['data'] != null && institutionsData['data'] is List) {
              institutionsList = institutionsData['data'];
            }
          }
        }

        print('Institutions found: ${institutionsList.length}');

        setState(() {
          _aiAnalysisResult = result;
          _recommendedInstitutions = institutionsList;
          _currentStep = ChildFormStep.selectInstitution;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis complete! Found ${institutionsList.length} institutions'),
            backgroundColor: AppColors.success,
          ),
        );

      } else {
        print('Analysis failed: ${result['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Analysis failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }

    } catch (e) {
      print('ERROR in analysis: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
      print('Analysis completed');
    }
  }

  List<dynamic> _safeConvertInstitutions(dynamic data) {
    try {
      print('Converting institutions data, type: ${data.runtimeType}');

      if (data == null) return [];

      if (data is List) {
        print('Data is already a List, length: ${data.length}');
        return data;
      }

      if (data is Map) {
        print('Data is Map, keys: ${data.keys}');

        if (data['institutions'] is List) {
          final list = data['institutions'] as List;
          print('Found institutions list, length: ${list.length}');
          return list;
        } else if (data['data'] is List) {
          final list = data['data'] as List;
          print('Found data list, length: ${list.length}');
          return list;
        } else if (data['results'] is List) {
          final list = data['results'] as List;
          print('Found results list, length: ${list.length}');
          return list;
        }

        final values = data.values.toList();
        if (values.isNotEmpty && values.first is List) {
          final list = values.first as List;
          print('Found list in Map values, length: ${list.length}');
          return list;
        }

        if (data.isNotEmpty) {
          print('Converting Map to List directly');
          return [data];
        }
      }

      print('No institutions data found');
      return [];
    } catch (e) {
      print('Error converting institutions: $e');
      return [];
    }
  }

  Future<void> _requestRegistration() async {
    if (_selectedInstitutionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an institution'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please give consent to proceed'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final result = await ApiService.requestInstitutionRegistration(
        token,
        _childId!,
        _selectedInstitutionId!,
        notes: _registrationNotes.isEmpty ? null : _registrationNotes,
        consentGiven: _consentGiven,
      );

      if (result['success'] == true) {
        setState(() {
          _currentStep = ChildFormStep.confirmation;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration request submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Registration failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isWithinDistance(String distanceStr, String maxDistance) {
    if (maxDistance == 'All') return true;
    if (distanceStr.isEmpty || distanceStr == 'غير محسوبة') return false;

    try {
      final cleanDistance = distanceStr.replaceAll(' كم', '').trim();
      final distance = double.tryParse(cleanDistance) ?? 9999.0;
      final maxDist = double.tryParse(maxDistance) ?? 0.0;

      return distance <= maxDist;
    } catch (e) {
      print('Error parsing distance: $e');
      return false;
    }
  }

  Widget _buildSmartSearchField() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by symptoms or behaviors',
              hintText: 'Example: not speaking, repetitive movements, communication difficulty...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _isSmartSearching
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
                  : null,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: _performSmartSearch,
          ),
        ),

        if (_smartSearchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested Results:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _smartSearchResults.map((result) {
                    return FilterChip(
                      label: Text(
                        '${result['arabic_name']} (${(result['confidence'] * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(fontSize: 12),
                      ),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primaryLight,
                      onSelected: (_) {
                        setState(() {
                          _suspectedCondition = result['arabic_name'] ?? result['name'];
                          _symptomsController.text = 'Symptoms: ${result['matching_keywords']?.join(', ') ?? ''}';
                        });
                        _searchController.clear();
                        _smartSearchResults = [];
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildSection(
              title: 'Basic Information',
              icon: Icons.person_outline,
              children: [
                TextFormField(
                  initialValue: _fullName,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    prefixIcon: Icon(Icons.person, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Please enter full name' : null,
                  onSaved: (v) => _fullName = v ?? '',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth *',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    prefixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      onPressed: _pickDate,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Please select date of birth' : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: InputDecoration(
                          labelText: 'Gender *',
                          labelStyle: TextStyle(color: AppColors.textGray),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.accent3),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                        ],
                        onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _childIdentifier,
                        decoration: InputDecoration(
                          labelText: 'Child Identifier',
                          labelStyle: TextStyle(color: AppColors.textGray),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.accent3),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                          ),
                          hintText: 'Optional',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onSaved: (v) => _childIdentifier = v ?? '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: _schoolInfo,
                  decoration: InputDecoration(
                    labelText: 'School Information',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    hintText: 'Optional',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  maxLines: 2,
                  onSaved: (v) => _schoolInfo = v ?? '',
                ),
                const SizedBox(height: 20),
                _buildLocationSection(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInfoStep() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildSection(
              title: 'Medical Information',
              icon: Icons.medical_services_outlined,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent2),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Provide at least one of the following:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Symptoms description\n• Suspected condition\n• Diagnosis',
                        style: TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  initialValue: _symptomsDescription,
                  decoration: InputDecoration(
                    labelText: 'Symptoms Description *',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    hintText: 'Describe specific behaviors, challenges, or concerns...\nExample: "Difficulty with eye contact, repetitive movements, speech delay"',
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    setState(() {
                      _symptomsDescription = value;
                    });
                  },
                  onSaved: (v) => _symptomsDescription = v ?? '',
                ),
                const SizedBox(height: 20),

                TextFormField(
                  initialValue: _suspectedCondition,
                  decoration: InputDecoration(
                    labelText: 'Suspected Condition',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    hintText: 'Example: Autism Spectrum Disorder, ADHD, Speech Delay...',
                    prefixIcon: Icon(Icons.psychology, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _suspectedCondition = value;
                    });
                  },
                  onSaved: (v) => _suspectedCondition = v ?? '',
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<int>(
                  value: _selectedDiagnosisId,
                  decoration: InputDecoration(
                    labelText: 'Known Diagnosis (Optional)',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    prefixIcon: Icon(Icons.medical_information, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  isExpanded: true, // ⭐ هذا يحل مشكلة الoverflow
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text(
                        'No Diagnosis Selected',
                        style: TextStyle(color: AppColors.textLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ..._diagnoses.map((diagnosis) {
                      final diagnosisName = diagnosis['name'] ?? 'Unknown';
                      return DropdownMenuItem<int>(
                        value: diagnosis['diagnosis_id'],
                        child: Text(
                          _truncateDiagnosisName(diagnosisName),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (v) => setState(() => _selectedDiagnosisId = v),
                  selectedItemBuilder: (BuildContext context) {
                    return [
                      const Text(
                        'No Diagnosis Selected',
                        style: TextStyle(color: AppColors.textLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                      ..._diagnoses.map((diagnosis) {
                        final diagnosisName = diagnosis['name'] ?? 'Unknown';
                        return Text(
                          _truncateDiagnosisName(diagnosisName),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        );
                      }).toList(),
                    ];
                  },
                ),
                const SizedBox(height: 20),

                if (_symptomsDescription.isNotEmpty || _suspectedCondition.isNotEmpty || _selectedDiagnosisId != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 20, color: AppColors.success),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Medical data ready for analysis',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
                              const SizedBox(height: 4),
                              Text(
                                _getMedicalDataSummary(),
                                style: TextStyle(fontSize: 12, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
                TextFormField(
                  initialValue: _medicalHistory,
                  decoration: InputDecoration(
                    labelText: 'Medical History',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    hintText: 'Previous diagnoses, treatments, hospitalizations...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  maxLines: 3,
                  onSaved: (v) => _medicalHistory = v ?? '',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: _previousServices,
                  decoration: InputDecoration(
                    labelText: 'Previous Services/Therapies',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    hintText: 'Speech therapy, occupational therapy, behavioral therapy...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  maxLines: 2,
                  onSaved: (v) => _previousServices = v ?? '',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: _additionalNotes,
                  decoration: InputDecoration(
                    labelText: 'Additional Notes',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    hintText: 'Any other relevant information...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  maxLines: 2,
                  onSaved: (v) => _additionalNotes = v ?? '',
                ),
              ],
            ),

            if (_isAnalyzing) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing Symptoms...',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Finding the best institutions based on the provided information',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  String _truncateDiagnosisName(String name) {
    if (name.length <= 35) return name;
    return '${name.substring(0, 32)}...';
  }

  Widget _buildInstitutionSelectionStep() {
    final safeInstitutions = _safeConvertInstitutions(_recommendedInstitutions);

    String _searchFilter = '';
    String _selectedCity = 'All';
    String _selectedSpecialty = 'All';
    String _sortBy = 'match_score';
    String _selectedMaxDistance = 'All';
    double _localMinRating = _minRating;
    double _localMaxPrice = _maxPrice;
    bool _localFilterByMatchingServices = _filterByMatchingServices;

    final cities = ['All', ...safeInstitutions.map((inst) => inst['city']?.toString() ?? 'Unknown').where((city) => city != 'Unknown' && city != 'null').toSet().toList()];
    final specialties = ['All', ...safeInstitutions.expand((inst) => inst['matching_specialties'] ?? []).whereType<String>().toSet().toList()];

    List<dynamic> filteredInstitutions = safeInstitutions.where((institution) {
      final name = institution['name']?.toString().toLowerCase() ?? '';
      final city = institution['city']?.toString() ?? '';
      final instSpecialties = institution['matching_specialties'] ?? [];
      final distance = institution['distance']?.toString() ?? '';
      final rating = double.tryParse(institution['rating']?.toString() ?? '0') ?? 0.0;
      final avgPrice = double.tryParse(institution['avg_price']?.toString() ?? '0') ?? 0.0;
      final matchingServices = institution['available_services'] ?? [];

      final matchesSearch = _searchFilter.isEmpty ||
          name.contains(_searchFilter.toLowerCase()) ||
          city.toLowerCase().contains(_searchFilter.toLowerCase());

      final matchesCity = _selectedCity == 'All' || city == _selectedCity;
      final matchesSpecialty = _selectedSpecialty == 'All' ||
          (instSpecialties is List && instSpecialties.contains(_selectedSpecialty));

      final matchesDistance = _selectedMaxDistance == 'All' ||
          _isWithinDistance(distance, _selectedMaxDistance);

      final matchesRating = rating >= _localMinRating;
      final matchesPrice = _localMaxPrice >= 1000.0 || avgPrice <= _localMaxPrice;
      final matchesServices = !_localFilterByMatchingServices ||
          (matchingServices is List && matchingServices.isNotEmpty);

      return matchesSearch && matchesCity && matchesSpecialty &&
          matchesDistance && matchesRating && matchesPrice && matchesServices;
    }).toList();

    filteredInstitutions.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
        case 'city':
          return (a['city'] ?? '').compareTo(b['city'] ?? '');
        case 'distance':
        case 'nearest':
          final distA = double.tryParse(a['distance']?.toString().replaceAll(' كم', '') ?? '999') ?? 999;
          final distB = double.tryParse(b['distance']?.toString().replaceAll(' كم', '') ?? '999') ?? 999;
          return distA.compareTo(distB);
        case 'rating':
          final ratingA = double.tryParse(a['rating']?.toString() ?? '0') ?? 0.0;
          final ratingB = double.tryParse(b['rating']?.toString() ?? '0') ?? 0.0;
          return ratingB.compareTo(ratingA);
        case 'price':
          final priceA = double.tryParse(a['avg_price']?.toString() ?? '999') ?? 999;
          final priceB = double.tryParse(b['avg_price']?.toString() ?? '999') ?? 999;
          return priceA.compareTo(priceB);
        case 'match_score':
        default:
          final scoreA = _parseMatchScore(a['match_score']);
          final scoreB = _parseMatchScore(b['match_score']);
          return scoreB.compareTo(scoreA);
      }
    });

    int activeFiltersCount = 0;
    if (_searchFilter.isNotEmpty) activeFiltersCount++;
    if (_selectedCity != 'All') activeFiltersCount++;
    if (_selectedSpecialty != 'All') activeFiltersCount++;
    if (_selectedMaxDistance != 'All') activeFiltersCount++;
    if (_localMinRating > 0.0) activeFiltersCount++;
    if (_localMaxPrice < 1000.0) activeFiltersCount++;
    if (_localFilterByMatchingServices) activeFiltersCount++;

    return StatefulBuilder(
      builder: (context, setFilterState) {
        return SingleChildScrollView(
          child: Column(
            children: [
              if (_aiAnalysisResult != null) ...[
                _buildAnalysisResults(),
                const SizedBox(height: 20),
              ],

              _buildSection(
                title: 'Find the Perfect Institution',
                icon: Icons.school,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Institutions',
                      labelStyle: TextStyle(color: AppColors.textGray),
                      hintText: 'Search by name or city...',
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.accent3),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (value) {
                      setFilterState(() {
                        _searchFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // تصميم متجاوب للفلاتر
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        // تصميم عمودي للشاشات الصغيرة
                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedCity,
                              decoration: InputDecoration(
                                labelText: 'City',
                                labelStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
                                prefixIcon: Icon(Icons.location_city, size: 18, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              isExpanded: true,
                              items: cities.map((city) {
                                return DropdownMenuItem(
                                  value: city,
                                  child: Text(
                                    _truncateText(city, 20),
                                    style: TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setFilterState(() {
                                  _selectedCity = value ?? 'All';
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedSpecialty,
                              decoration: InputDecoration(
                                labelText: 'Specialty',
                                labelStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
                                prefixIcon: Icon(Icons.medical_services, size: 18, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              isExpanded: true,
                              items: specialties.map((specialty) {
                                return DropdownMenuItem(
                                  value: specialty,
                                  child: Text(
                                    _truncateText(specialty, 20),
                                    style: TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setFilterState(() {
                                  _selectedSpecialty = value ?? 'All';
                                });
                              },
                            ),
                          ],
                        );
                      } else {
                        // تصميم أفقي للشاشات الكبيرة
                        return Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCity,
                                decoration: InputDecoration(
                                  labelText: 'City',
                                  labelStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
                                  prefixIcon: Icon(Icons.location_city, size: 18, color: AppColors.primary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                                isExpanded: true,
                                items: cities.map((city) {
                                  return DropdownMenuItem(
                                    value: city,
                                    child: Text(
                                      _truncateText(city, 15),
                                      style: TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setFilterState(() {
                                    _selectedCity = value ?? 'All';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedSpecialty,
                                decoration: InputDecoration(
                                  labelText: 'Specialty',
                                  labelStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
                                  prefixIcon: Icon(Icons.medical_services, size: 18, color: AppColors.primary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                                isExpanded: true,
                                items: specialties.map((specialty) {
                                  return DropdownMenuItem(
                                    value: specialty,
                                    child: Text(
                                      _truncateText(specialty, 15),
                                      style: TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setFilterState(() {
                                    _selectedSpecialty = value ?? 'All';
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _selectedMaxDistance,
                    decoration: InputDecoration(
                      labelText: 'Max Distance',
                      labelStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
                      prefixIcon: Icon(Icons.social_distance, size: 18, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('Any Distance')),
                      DropdownMenuItem(value: '10', child: Text('Within 10 km')),
                      DropdownMenuItem(value: '25', child: Text('Within 25 km')),
                      DropdownMenuItem(value: '50', child: Text('Within 50 km')),
                      DropdownMenuItem(value: '100', child: Text('Within 100 km')),
                    ],
                    onChanged: (value) {
                      setFilterState(() {
                        _selectedMaxDistance = value ?? 'All';
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // خيارات الترتيب
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sort, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Sort by:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              isDense: true,
                              style: TextStyle(fontSize: 12, color: AppColors.primary),
                              items: const [
                                DropdownMenuItem(value: 'match_score', child: Text('Best Match')),
                                DropdownMenuItem(value: 'rating', child: Text('Highest Rating')),
                                DropdownMenuItem(value: 'price', child: Text('Lowest Price')),
                                DropdownMenuItem(value: 'nearest', child: Text('Nearest')),
                                DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
                              ],
                              onChanged: (value) {
                                setFilterState(() {
                                  _sortBy = value ?? 'match_score';
                                  if (value == 'nearest') {
                                    _selectedMaxDistance = '50';
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // زر الفلاتر المتقدمة
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                        });
                      },
                      icon: Icon(
                        _showAdvancedFilters ? Icons.expand_less : Icons.tune,
                        size: 18,
                      ),
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showAdvancedFilters ? 'Hide Advanced Filters' : 'Advanced Filters',
                            style: TextStyle(fontSize: 13),
                          ),
                          if (activeFiltersCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$activeFiltersCount',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  if (_showAdvancedFilters) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.filter_alt, size: 20, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Advanced Filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.refresh, size: 20, color: AppColors.primary),
                                onPressed: () {
                                  setFilterState(() {
                                    _localMinRating = 0.0;
                                    _localMaxPrice = 1000.0;
                                    _localFilterByMatchingServices = false;
                                  });
                                  setState(() {
                                    _minRating = 0.0;
                                    _maxPrice = 1000.0;
                                    _filterByMatchingServices = false;
                                  });
                                },
                                tooltip: 'Reset Filters',
                              ),
                            ],
                          ),
                          Divider(color: AppColors.accent3),
                          const SizedBox(height: 12),

                          Text(
                            'Minimum Rating: ${_localMinRating.toStringAsFixed(1)} ⭐',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          Slider(
                            value: _localMinRating,
                            min: 0.0,
                            max: 5.0,
                            divisions: 10,
                            label: _localMinRating.toStringAsFixed(1),
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setFilterState(() {
                                _localMinRating = value;
                              });
                              setState(() {
                                _minRating = value;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Maximum Price: \$${_localMaxPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          Slider(
                            value: _localMaxPrice,
                            min: 0.0,
                            max: 1000.0,
                            divisions: 20,
                            label: '\$${_localMaxPrice.toStringAsFixed(0)}',
                            activeColor: AppColors.success,
                            onChanged: (value) {
                              setFilterState(() {
                                _localMaxPrice = value;
                              });
                              setState(() {
                                _maxPrice = value;
                              });
                            },
                          ),

                          const SizedBox(height: 8),

                          CheckboxListTile(
                            title: Text(
                              'Show Only Matching Services',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Filter institutions with matching services',
                              style: TextStyle(fontSize: 11, color: AppColors.textLight),
                            ),
                            value: _localFilterByMatchingServices,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setFilterState(() {
                                _localFilterByMatchingServices = value ?? false;
                              });
                              setState(() {
                                _filterByMatchingServices = value ?? false;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              _buildSection(
                title: 'Recommended for you (${filteredInstitutions.length})',
                icon: Icons.recommend,
                children: [
                  if (filteredInstitutions.isEmpty)
                    _buildNoInstitutionsWidget()
                  else
                    Column(
                      children: [
                        if (_sortBy == 'match_score' && filteredInstitutions.isNotEmpty) ...[
                          _buildTopRecommendationCard(filteredInstitutions.first),
                          const SizedBox(height: 16),
                        ],
                        ...filteredInstitutions.map((institution) {
                          return _buildInstitutionCard(institution);
                        }).toList(),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 20),

              _buildSection(
                title: 'Registration Details',
                icon: Icons.assignment,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, size: 16, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Text(
                              'Registration Process',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Request sent to institution\n'
                              '• Institution reviews and approves\n'
                              '• You receive notification\n'
                              '• Sessions booked after approval',
                          style: TextStyle(fontSize: 12, color: AppColors.warning),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: _registrationNotes,
                    decoration: InputDecoration(
                      labelText: 'Notes for Institution (Optional)',
                      labelStyle: TextStyle(color: AppColors.textGray),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.accent3),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      hintText: 'Any additional information or special requirements...',
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    maxLines: 3,
                    onChanged: (v) => _registrationNotes = v,
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: AppColors.primary,
                            ),
                            child: Checkbox(
                              value: _consentGiven,
                              onChanged: (v) => setState(() => _consentGiven = v ?? false),
                              activeColor: AppColors.primary,
                              checkColor: Colors.white,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'I give consent for registration and data processing',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'I understand my child\'s information will be shared with the selected institution',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

// أضف هذه الدالة المساعدة في الكلاس
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  Widget _buildAnalysisResults() {
    final analysis = _aiAnalysisResult!;
    final suggestedConditions = analysis['analysis']?['suggested_conditions'] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, size: 20, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                'AI Analysis Results',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (suggestedConditions.isNotEmpty) ...[
            Text('Suggested Conditions:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestedConditions.map<Widget>((condition) {
                final name = condition['name'] ?? 'Unknown';
                final confidence = condition['confidence'];

                String confidenceText;
                if (confidence is double) {
                  confidenceText = '${(confidence * 100).toStringAsFixed(0)}%';
                } else if (confidence is String) {
                  confidenceText = confidence;
                } else {
                  confidenceText = 'N/A';
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('$name ($confidenceText)',
                      style: TextStyle(fontSize: 12, color: AppColors.success)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Found ${_safeConvertInstitutions(_recommendedInstitutions).length} suitable institutions',
            style: TextStyle(fontSize: 12, color: AppColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRecommendationCard(Map<String, dynamic> institution) {
    final id = institution['id'] ?? institution['institution_id'] ?? 0;
    final name = institution['name'] ?? 'Unknown Institution';
    final city = institution['city'] ?? '';
    final matchScore = institution['match_score'] ?? '0%';
    final specialties = institution['matching_specialties'] ?? [];
    final isSelected = _selectedInstitutionId == id;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primaryLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.star, color: AppColors.primary),
        ),
        title: Row(
          children: [
            Text(
              'Best Match',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.0),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            if (city.isNotEmpty && city != 'null')
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    city,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            if (specialties.isNotEmpty && specialties is List && specialties.isNotEmpty)
              Wrap(
                spacing: 4,
                children: (specialties as List).take(3).map<Widget>((specialty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      specialty.toString(),
                      style: TextStyle(fontSize: 10, color: AppColors.primary),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Match: $matchScore',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
          color: isSelected ? AppColors.success : AppColors.primary,
        ),
        onTap: () {
          setState(() {
            _selectedInstitutionId = id;
          });
        },
      ),
    );
  }

  Widget _buildInstitutionCard(Map<String, dynamic> institution) {
    final id = institution['id'] ?? institution['institution_id'] ?? 0;
    final name = institution['name'] ?? 'Unknown Institution';
    final city = institution['city'] ?? '';
    final matchScore = institution['match_score'] ?? '0%';
    final specialties = institution['matching_specialties'] ?? [];
    final distance = institution['distance']?.toString();
    final isSelected = _selectedInstitutionId == id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.accent3,
          width: isSelected ? 2 : 1,
        ),
      ),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.accent1,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.school,
            color: isSelected ? AppColors.primary : AppColors.textLight,
            size: 20,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textDark,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            if (city.isNotEmpty && city != 'null')
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      city,
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (specialties.isNotEmpty && specialties is List)
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: (specialties as List).take(2).map<Widget>((specialty) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        specialty.toString(),
                        style: TextStyle(fontSize: 10, color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMatchScoreColor(matchScore),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 10, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        '$matchScore',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                if (institution['rating'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 10, color: AppColors.warning),
                        SizedBox(width: 2),
                        Text(
                          '${institution['rating']}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (institution['avg_price'] != null && double.tryParse(institution['avg_price'].toString()) != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_money, size: 10, color: AppColors.success),
                        Text(
                          '${double.parse(institution['avg_price'].toString()).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.info.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions, size: 10, color: AppColors.info),
                        SizedBox(width: 2),
                        Text(
                          distance.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (institution['available_services'] != null &&
                    institution['available_services'] is List &&
                    (institution['available_services'] as List).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medical_services, size: 10, color: AppColors.primary),
                        SizedBox(width: 2),
                        Text(
                          '${(institution['available_services'] as List).length} services',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: AppColors.success, size: 24)
            : Icon(Icons.radio_button_unchecked, color: AppColors.textLight, size: 24),
        onTap: () {
          setState(() {
            _selectedInstitutionId = id;
          });
        },
      ),
    );
  }

  Widget _buildNoInstitutionsWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(
            'No Suitable Institutions Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find institutions matching the current symptoms. '
                'Try adjusting the symptoms description or suspected condition.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.warning),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentStep = ChildFormStep.medicalInfo;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Edit Medical Information'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 16),
          Text(
            'Registration Request Submitted!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          Text(
            'Your registration request has been sent to the institution. '
                'You will be notified when it is approved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textGray),
          ),
          const SizedBox(height: 24),
          if (_selectedInstitutionId != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent2),
              ),
              child: ListTile(
                leading: Icon(Icons.school, color: AppColors.primary),
                title: Text('Selected Institution', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_getInstitutionName(_selectedInstitutionId!)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Child Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Select the child\'s location on the map to help us find the nearest institutions to you',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _openMapScreen,
            icon: Icon(Icons.map, color: AppColors.primary),
            label: Text(
              _locationLat != null && _locationLng != null
                  ? 'Edit Location on Map'
                  : 'Choose Location from Map',
              style: TextStyle(color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),

          if (_locationLat != null && _locationLng != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Location Selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_city.isNotEmpty)
                    Text('City: $_city', style: TextStyle(fontSize: 12)),
                  if (_address.isNotEmpty)
                    Text('Address: $_address', style: TextStyle(fontSize: 12)),
                  Text(
                    'Coordinates: ${_locationLat!.toStringAsFixed(4)}, ${_locationLng!.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepIndicator('Basic', _currentStep.index >= 0, 0),
              _buildStepIndicator('Medical', _currentStep.index >= 1, 1),
              _buildStepIndicator('Institution', _currentStep.index >= 2, 2),
              _buildStepIndicator('Confirm', _currentStep.index >= 3, 3),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            if (_currentStep != ChildFormStep.basicInfo)
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _goToPreviousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppColors.primary),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),

            if (_currentStep != ChildFormStep.basicInfo) const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _goToNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text(
                  _getActionButtonText(),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepIndicator(String label, bool isActive, int stepIndex) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.textLight.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isActive
                  ? Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                '${stepIndex + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.primary : AppColors.textLight,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case ChildFormStep.basicInfo:
        return _buildBasicInfoStep();
      case ChildFormStep.medicalInfo:
        return _buildMedicalInfoStep();
      case ChildFormStep.selectInstitution:
        return _buildInstitutionSelectionStep();
      case ChildFormStep.confirmation:
        return _buildConfirmationStep();
    }
  }

  String _getMedicalDataSummary() {
    List<String> parts = [];
    if (_symptomsDescription.isNotEmpty) {
      parts.add('${_symptomsDescription.split(' ').length} words of symptoms');
    }
    if (_suspectedCondition.isNotEmpty) {
      parts.add('suspected $_suspectedCondition');
    }
    if (_selectedDiagnosisId != null) {
      final diagnosis = _diagnoses.firstWhere(
            (d) => d['diagnosis_id'] == _selectedDiagnosisId,
        orElse: () => {'name': 'Unknown'},
      );
      parts.add('diagnosis: ${diagnosis['name']}');
    }
    return parts.join(', ');
  }

  void _goToPreviousStep() {
    setState(() {
      switch (_currentStep) {
        case ChildFormStep.medicalInfo:
          _currentStep = ChildFormStep.basicInfo;
          break;
        case ChildFormStep.selectInstitution:
          _currentStep = ChildFormStep.medicalInfo;
          break;
        case ChildFormStep.confirmation:
          _currentStep = ChildFormStep.selectInstitution;
          break;
        default:
          break;
      }
    });
  }

  void _goToNextStep() {
    switch (_currentStep) {
      case ChildFormStep.basicInfo:
        _saveBasicInfo();
        break;
      case ChildFormStep.medicalInfo:
        _formKey.currentState?.save();
        final hasSymptoms = _symptomsDescription.trim().isNotEmpty;
        final hasSuspectedCondition = _suspectedCondition.trim().isNotEmpty;
        final hasDiagnosis = _selectedDiagnosisId != null;

        if (widget.screeningData != null &&
            widget.screeningData!['from_screening'] == true &&
            widget.screeningData!['recommended_institutions'] != null) {
          setState(() {
            _recommendedInstitutions = widget.screeningData!['recommended_institutions'];
            _currentStep = ChildFormStep.selectInstitution;
          });
        } else if (!hasSymptoms && !hasSuspectedCondition && !hasDiagnosis) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please provide at least one of: symptoms description, suspected condition, or diagnosis'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        } else {
          _analyzeMedicalCondition();
        }
        break;
      case ChildFormStep.selectInstitution:
        _requestRegistration();
        break;
      case ChildFormStep.confirmation:
        Navigator.pop(context, true);
        break;
    }
  }

  String _getActionButtonText() {
    switch (_currentStep) {
      case ChildFormStep.basicInfo:
        return 'Continue to Recommendations';
      case ChildFormStep.medicalInfo:
        return widget.screeningData != null ? 'View Recommended Institutions' : 'Analyze & Find Institutions';
      case ChildFormStep.selectInstitution:
        return 'Request Registration';
      case ChildFormStep.confirmation:
        return 'Finish';
    }
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case ChildFormStep.basicInfo:
        return 'Add Child - Basic Information';
      case ChildFormStep.medicalInfo:
        return widget.screeningData != null ? 'Screening Results Summary' : 'Medical Information';
      case ChildFormStep.selectInstitution:
        return 'Recommended Institutions';
      case ChildFormStep.confirmation:
        return 'Confirmation';
    }
  }

  double _getProgressValue() {
    switch (_currentStep) {
      case ChildFormStep.basicInfo:
        return 0.25;
      case ChildFormStep.medicalInfo:
        return 0.5;
      case ChildFormStep.selectInstitution:
        return 0.75;
      case ChildFormStep.confirmation:
        return 1.0;
    }
  }

  double _parseMatchScore(dynamic score) {
    if (score == null) return 0.0;
    if (score is double) return score;
    if (score is int) return score.toDouble();
    if (score is String) {
      final clean = score.replaceAll('%', '');
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  Color _getMatchScoreColor(String matchScore) {
    final score = _parseMatchScore(matchScore);
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String _getInstitutionName(int institutionId) {
    final institution = _recommendedInstitutions.firstWhere(
          (inst) => inst['id'] == institutionId,
      orElse: () => {'name': 'Unknown Institution'},
    );
    return institution['name'];
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.tryParse(_dateController.text) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,           // اللون الأساسي
              onPrimary: Colors.white,              // لون النص على اللون الأساسي
              surface: AppColors.surface,           // لون الخلفية
              onSurface: AppColors.textDark,        // لون النص على الخلفية
              background: AppColors.background,     // لون الخلفية العامة
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: AppColors.textDark),
              bodyMedium: TextStyle(color: AppColors.textDark),
              titleMedium: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
              labelLarge: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            dialogBackgroundColor: AppColors.background,
            cardColor: AppColors.surface,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _dateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _photo = '';
      });
    }
  }

  Future<void> _openMapScreen() async {
    print('🗺️ Opening map screen...');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLat: _locationLat,
          initialLng: _locationLng,
          initialAddress: _address.isNotEmpty ? _address : null,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      print('📍 [FORM] Received location data from map: $result');
      setState(() {
        _locationLat = result['lat'];
        _locationLng = result['lng'];
        _address = result['address'] ?? '';
        _city = result['city'] ?? '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Location selected: $_city'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.child != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Child' : 'Add New Child',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStepTitle(),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: AppColors.textLight),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.accent2,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: LinearProgressIndicator(
                  value: _getProgressValue(),
                  backgroundColor: Colors.transparent,
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              const SizedBox(height: 32),

              _buildStepContent(),

              const SizedBox(height: 32),

              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }
}