// lib/screens/EditProfileScreen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // بيانات المستخدم الحالية
  Map<String, dynamic> _currentUserData = {};
  Map<String, dynamic> _editedData = {};

  // متغيرات النموذج
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _occupationController;

  // حالة التحميل والأخطاء
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _selectedImagePath;
  XFile? _pickedImageFile;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('Token not found');
      }

      // جلب بيانات الوالد من الـ API - يرجع Map وليس DashboardData
      final response = await ApiService.getParentDashboard(token);

      if (response == null) {
        throw Exception('Failed to load user data');
      }

      setState(() {
        // ⬇️⬇️⬇️ التصحيح هنا - استخدم response مباشرة كـ Map ⬇️⬇️⬇️
        final parentData = response['parent'] ?? {};
        _currentUserData = {
          'full_name': parentData['name'] ?? '',
          'email': parentData['email'] ?? '',
          'phone': parentData['phone'] ?? '',
          'address': parentData['address'] ?? '',
          'occupation': parentData['occupation'] ?? '',
          'profile_picture': parentData['profile_picture'] ?? '',
        };

        _editedData = Map.from(_currentUserData);

        // تهيئة الـ controllers
        _fullNameController = TextEditingController(text: _currentUserData['full_name']);
        _emailController = TextEditingController(text: _currentUserData['email']);
        _phoneController = TextEditingController(text: _currentUserData['phone']);
        _addressController = TextEditingController(text: _currentUserData['address']);
        _occupationController = TextEditingController(text: _currentUserData['occupation']);

        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _pickedImageFile = image;
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Profile Picture'),
          content: const Text('Choose image source'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage() {
    final currentImage = _currentUserData['profile_picture'] ?? '';

    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: ParentAppColors.primaryTeal.withOpacity(0.1),
            backgroundImage: _selectedImagePath != null
                ? FileImage(File(_selectedImagePath!)) as ImageProvider
                : (currentImage.isNotEmpty
                ? NetworkImage(currentImage)
                : const AssetImage('assets/images/default_avatar.png') as ImageProvider),
            child: _selectedImagePath == null && currentImage.isEmpty
                ? const Icon(
              Icons.person,
              size: 50,
              color: ParentAppColors.primaryTeal,
            )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParentAppColors.primaryTeal,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CustomTextField(
        controller: controller,
        labelText: label,
        hintText: hintText,
        prefixIcon: icon,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator ?? (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
        onChanged: (value) {
          // تحديث البيانات المحررة
          final fieldName = _getFieldNameFromLabel(label);
          if (fieldName != null) {
            setState(() {
              _editedData[fieldName] = value.trim();
            });
          }
        },
      ),
    );
  }

  String? _getFieldNameFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'full name': return 'full_name';
      case 'email': return 'email';
      case 'phone': return 'phone';
      case 'address': return 'address';
      case 'occupation': return 'occupation';
      default: return null;
    }
  }

  bool get _hasChanges {
    if (_pickedImageFile != null) return true;

    for (final key in _currentUserData.keys) {
      if (_editedData[key] != _currentUserData[key]) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // رفع الصورة إذا كانت موجودة
      if (_pickedImageFile != null) {
        final imageUrl = await ApiService.uploadProfileImage(
            _pickedImageFile!.path
        );
        if (imageUrl != null) {
          _editedData['profile_picture'] = imageUrl;
        }
      }

      // استدعاء API التحديث
      final success = await ApiService.updateParentProfile(_editedData);

      if (success) {
        _showSuccessSnackBar('Profile updated successfully');
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to update profile');
      }

    } catch (e) {
      _showErrorSnackBar('Failed to save changes: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: ParentAppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onWillPop().then((pop) {
              if (pop) Navigator.pop(context);
            }),
          ),
          actions: [
            if (_hasChanges && !_isSaving)
              TextButton(
                onPressed: _saveProfile,
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: ParentAppColors.primaryTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeData,
                child: const Text('Retry'),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Center(child: _buildProfileImage()),
                const SizedBox(height: 8),
                Text(
                  'Tap to change photo',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                _buildFormField(
                  label: 'Full Name',
                  hintText: 'Enter your full name',
                  controller: _fullNameController,
                  icon: Icons.person,
                  isRequired: true,
                ),

                _buildFormField(
                  label: 'Email',
                  hintText: 'Enter your email address',
                  controller: _emailController,
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  isRequired: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),

                _buildFormField(
                  label: 'Phone',
                  hintText: 'Enter your phone number',
                  controller: _phoneController,
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),

                _buildFormField(
                  label: 'Address',
                  hintText: 'Enter your address',
                  controller: _addressController,
                  icon: Icons.location_on,
                  maxLines: 2,
                ),

                _buildFormField(
                  label: 'Occupation',
                  hintText: 'Enter your occupation',
                  controller: _occupationController,
                  icon: Icons.work,
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParentAppColors.primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (_hasChanges)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                        _onWillPop().then((pop) {
                          if (pop) Navigator.pop(context);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}