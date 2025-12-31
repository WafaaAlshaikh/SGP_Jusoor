import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../theme/app_colors.dart';

class EquipmentDonationScreen extends StatefulWidget {
  final int? institutionId;
  final String? institutionName;
  final String? equipmentName;
  final int? categoryId;

  const EquipmentDonationScreen({
    super.key,
    this.institutionId,
    this.institutionName,
    this.equipmentName,
    this.categoryId,
  });

  @override
  State<EquipmentDonationScreen> createState() => _EquipmentDonationScreenState();
}

class _EquipmentDonationScreenState extends State<EquipmentDonationScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _institutions = [];
  List<Map<String, dynamic>> _categories = [];
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  List<String> _uploadedImages = [];

  // Form controllers
  final TextEditingController _institutionController = TextEditingController();
  final TextEditingController _equipmentNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _estimatedValueController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();

  // Form values
  int? _selectedInstitutionId;
  int? _selectedCategoryId;
  String _selectedCondition = 'used_good';
  String _selectedDeliveryType = 'pickup';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();

    if (widget.equipmentName != null && widget.equipmentName!.trim().isNotEmpty) {
      _equipmentNameController.text = widget.equipmentName!.trim();
    }
    if (widget.categoryId != null) {
      _selectedCategoryId = widget.categoryId;
    }

    _loadInitialData();
    
    // Pre-fill contact info if user is logged in
    _loadUserContactInfo();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load institutions
      await _loadInstitutions();
      
      // Load equipment categories
      await _loadCategories();

      // Auto-select institution if provided
      if (widget.institutionId != null) {
        _selectInstitution(widget.institutionId!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInstitutions() async {
    try {
      final institutions = await ApiService.getEquipmentInstitutions();
      
      setState(() {
        _institutions = institutions;
      });
    } catch (e) {
      print('Error loading institutions: $e');
      setState(() {
        _institutions = [];
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/equipment/categories');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _categories = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
      setState(() {
        _categories = [];
      });
    }
  }

  Future<void> _loadUserContactInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token != null && token.isNotEmpty) {
        // Get user profile info
        final userResponse = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/users/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        
        if (userResponse.statusCode == 200) {
          final userData = jsonDecode(userResponse.body);
          if (userData['success'] == true && userData['data'] != null) {
            final user = userData['data'];
            
            setState(() {
              _contactPersonController.text = user['full_name'] ?? '';
              _contactPhoneController.text = user['phone'] ?? '';
              _contactEmailController.text = user['email'] ?? '';
            });
          }
        }
      }
    } catch (e) {
      print('Error loading user contact info: $e');
    }
  }

  void _selectInstitution(int institutionId) {
    final institution = _institutions.firstWhere(
      (inst) => inst['institution_id'] == institutionId,
      orElse: () => {},
    );
    
    if (institution.isNotEmpty) {
      setState(() {
        _selectedInstitutionId = institutionId;
        _institutionController.text = institution['name'] ?? '';
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (images != null) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick images: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      print('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate ?? now.add(const Duration(days: 7)),
    firstDate: now,
    lastDate: DateTime(now.year + 1, now.month, now.day), // نفس الشهر واليوم السنة القادمة
  );

  if (picked != null) {
    setState(() {
      _selectedDate = picked;
    });
  }
}



  String? _validateForm() {
    if (_selectedInstitutionId == null) {
      return 'Please select an institution';
    }
    
    if (_equipmentNameController.text.isEmpty) {
      return 'Please enter equipment name';
    }
    
    if (_contactPersonController.text.isEmpty) {
      return 'Please enter your name';
    }
    
    if (_contactPhoneController.text.isEmpty) {
      return 'Please enter your phone number';
    }
    
    return null;
  }

  Future<void> _submitDonation() async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      // Prepare form data
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/api/equipment/donate'),
      );
      
      // Add headers if authenticated
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Add form fields
      request.fields['institution_id'] = _selectedInstitutionId.toString();
      if (_selectedCategoryId != null) {
        request.fields['category_id'] = _selectedCategoryId.toString();
      }
      request.fields['equipment_name'] = _equipmentNameController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['condition'] = _selectedCondition;
      request.fields['delivery_type'] = _selectedDeliveryType;
      if (_estimatedValueController.text.isNotEmpty) {
        request.fields['estimated_value'] = _estimatedValueController.text;
      }
      if (_selectedDate != null) {
        request.fields['preferred_date'] = _selectedDate!.toIso8601String();
      }
      request.fields['contact_person'] = _contactPersonController.text;
      request.fields['contact_phone'] = _contactPhoneController.text;
      if (_contactEmailController.text.isNotEmpty) {
        request.fields['contact_email'] = _contactEmailController.text;
      }
      
      // Add images
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final file = await http.MultipartFile.fromPath(
          'images',
          image.path,
          filename: 'equipment_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        request.files.add(file);
      }
      
      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      
      if (response.statusCode == 201 && data['success'] == true) {
        // Success
        await _showSuccessDialog(data);
      } else {
        throw Exception(data['message'] ?? 'Failed to submit donation');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit donation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _showSuccessDialog(Map<String, dynamic> response) async {
  final donationId = response['data']['equipment_donation_id'] as int? ?? 0;
final paddedId = donationId.toString().padLeft(6, '0');
final trackingCode = 'EQ$paddedId';
  
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text(
        'Request Submitted Successfully!',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thank you for your generous donation offer.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Tracking Code: $trackingCode',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please save this code to track your donation status.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Next Steps:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. The institution will review your donation request\n'
            '2. You will be contacted to arrange pickup/delivery\n'
            '3. You will receive updates via SMS/Email',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _clearForm();
          },
          child: const Text('Submit Another Donation'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Return Home'),
        ),
      ],
    ),
  );
}

  void _clearForm() {
    setState(() {
      _selectedInstitutionId = null;
      _institutionController.clear();
      _selectedCategoryId = null;
      _equipmentNameController.clear();
      _descriptionController.clear();
      _estimatedValueController.clear();
      _selectedCondition = 'used_good';
      _selectedDeliveryType = 'pickup';
      _selectedDate = null;
      _contactPersonController.clear();
      _contactPhoneController.clear();
      _contactEmailController.clear();
      _selectedImages.clear();
      _uploadedImages.clear();
    });
  }

  Widget _buildInstitutionSelector() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Select Institution *',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 8),
      InkWell(
        onTap: _showInstitutionPicker,
        child: InputDecorator(
          decoration: const InputDecoration(
            hintText: 'Select institution...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.apartment),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _institutionController.text.isEmpty
                      ? 'Select institution...'
                      : _institutionController.text,
                  style: TextStyle(
                    color: _institutionController.text.isEmpty ? Colors.grey : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

  Future<void> _showInstitutionPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Institution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _institutions.length,
                  itemBuilder: (context, index) {
                    final institution = _institutions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.apartment, color: AppColors.primary),
                        title: Text(institution['name'] ?? ''),
                        subtitle: Text(institution['city'] ?? ''),
                        onTap: () {
                          setState(() {
                            _selectedInstitutionId = institution['institution_id'] as int;
                            _institutionController.text = institution['name'] ?? '';
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Equipment Category',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _selectedCategoryId,
          decoration: const InputDecoration(
            hintText: 'Select category (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Select category (optional)'),
            ),
            ..._categories.map((category) {
              return DropdownMenuItem(
                value: category['category_id'] as int,
                child: Text(category['name_ar'] ?? category['name_en'] ?? ''),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildConditionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Condition *',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildConditionChip('new', 'جديد', Icons.new_label),
            _buildConditionChip('used_good', 'مستعمل - حالة جيدة', Icons.thumb_up),
            _buildConditionChip('used_fair', 'مستعمل - حالة متوسطة', Icons.build),
            _buildConditionChip('needs_repair', 'يحتاج صيانة', Icons.engineering),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionChip(String value, String label, IconData icon) {
    final isSelected = _selectedCondition == value;
    
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCondition = value;
        });
      },
      backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
      selectedColor: AppColors.primary.withOpacity(0.2),
    );
  }

  Widget _buildDeliveryTypeSelector() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Delivery Method *',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 8),
      Column(
        children: [
          RadioListTile<String>(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delivery_dining),
                SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('I can deliver it'),
                      SizedBox(height: 2),
                      Text(
                        'I can bring the equipment to the institution',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            value: 'delivery',
            groupValue: _selectedDeliveryType,
            onChanged: (value) {
              setState(() {
                _selectedDeliveryType = value!;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping),
                SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pickup needed'),
                      SizedBox(height: 2),
                      Text(
                        'The institution needs to arrange pickup',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            value: 'pickup',
            groupValue: _selectedDeliveryType,
            onChanged: (value) {
              setState(() {
                _selectedDeliveryType = value!;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    ],
  );
}

  Widget _buildImageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Equipment Photos (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload photos to help the institution evaluate the equipment',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        
        // Image grid
        if (_selectedImages.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImages[index].path),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                        onPressed: () => _removeImage(index),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        
        const SizedBox(height: 16),
        
        // Add buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select from Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_selectedImages.length} photo(s) selected',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.institutionName != null
              ? 'Donate Equipment to ${widget.institutionName}'
              : 'Donate Medical Equipment',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading data...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadInitialData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Card(
                        color: Colors.blue.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.medical_services, size: 32, color: Colors.blue),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Donate Medical Equipment',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Help support children with special needs by donating equipment',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Institution Selection
                      _buildInstitutionSelector(),
                      
                      const SizedBox(height: 20),
                      
                      // Equipment Information
                      const Text(
                        'Equipment Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Equipment Name
                      TextFormField(
                        controller: _equipmentNameController,
                        decoration: const InputDecoration(
                          labelText: 'Equipment Name *',
                          hintText: 'e.g., Wheelchair, Hearing Aid, Computer',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medical_services),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter equipment name';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Category
                      _buildCategorySelector(),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Describe the equipment, brand, model, features...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Condition
                      _buildConditionSelector(),
                      
                      const SizedBox(height: 16),
                      
                      // Estimated Value
                      TextFormField(
                        controller: _estimatedValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimated Value (JOD) (Optional)',
                          hintText: 'e.g., 500',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'JOD',
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Delivery Information
                      const Text(
                        'Delivery Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Delivery Method
                      _buildDeliveryTypeSelector(),
                      
                      const SizedBox(height: 16),
                      
                      // Preferred Date
                      InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Preferred Delivery Date (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate != null
                                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                    : 'Select date',
                                style: TextStyle(
                                  color: _selectedDate != null ? Colors.black : Colors.grey,
                                ),
                              ),
                              const Icon(Icons.calendar_month),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Contact Information
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Contact Person
                      TextFormField(
                        controller: _contactPersonController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name *',
                          hintText: 'Enter your full name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Contact Phone
                      TextFormField(
                        controller: _contactPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number *',
                          hintText: 'e.g., 0791234567',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Contact Email
                      TextFormField(
                        controller: _contactEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address (Optional)',
                          hintText: 'your.email@example.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Photos
                      _buildImageSelector(),
                      
                      const SizedBox(height: 32),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitDonation,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _isSubmitting ? 'Submitting...' : 'Submit Donation Request',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Information note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Important Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• Your donation request will be reviewed by the institution\n'
                              '• You will be contacted within 2-3 business days\n'
                              '• You can track your donation status using the tracking code\n'
                              '• All donations are tax-deductible',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _selectedImages.isNotEmpty
          ? FloatingActionButton(
              onPressed: _pickImages,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_photo_alternate),
            )
          : null,
    );
  }
}