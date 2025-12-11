
// lib/screens/EditProfileScreen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
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
  Map<String, String> _currentUserData = {};
  Map<String, String> _editedData = {};

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


  bool _isUploadingImage = false;
  String? _profilePictureUrl;


  @override
  void initState() {
    super.initState();
    _initializeData();
    _profilePictureUrl = _currentUserData['profile_picture'];
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

      final response = await ApiService.getParentDashboard(token);

      if (response == null) {
        throw Exception('Failed to load user data');
      }

      setState(() {
        final parentData = response['parent'] ?? {};
        _currentUserData = {
          'full_name': parentData['name']?.toString() ?? '',
          'email': parentData['email']?.toString() ?? '',
          'phone': parentData['phone']?.toString() ?? '',
          'address': parentData['address']?.toString() ?? '',
          'occupation': parentData['occupation']?.toString() ?? '',
          'profile_picture': parentData['profile_picture']?.toString() ?? '',
        };

        _profilePictureUrl = _currentUserData['profile_picture'];
        _editedData = Map.from(_currentUserData);

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
        // التحقق من حجم الصورة
        final isValidSize = await ApiService.validateImageSize(File(image.path));
        if (!isValidSize) {
          _showErrorSnackBar('Image size must be less than 5MB');
          return;
        }

        setState(() {
          _pickedImageFile = image;
          _selectedImagePath = image.path;
        });

        // رفع الصورة فوراً
        await _uploadProfilePicture();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_pickedImageFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final result = await ApiService.uploadParentProfilePicture(File(_pickedImageFile!.path));

      if (result['success'] == true) {
        final newProfilePicture = result['profile_picture']?.toString() ?? '';

        setState(() {
          _profilePictureUrl = newProfilePicture;
          _currentUserData['profile_picture'] = newProfilePicture;
          _editedData['profile_picture'] = newProfilePicture;
        });

        _showSuccessSnackBar('Profile picture updated successfully');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: $e');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  void _showImageSourceDialog() {
    final hasExistingImage = _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.accent2.withOpacity(0.5)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Change Profile Picture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: AppColors.textLight, size: 24),
                    ),
                  ],
                ),
              ),

              // Options
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt_rounded,
                      title: 'Take Photo',
                      subtitle: 'Use your camera',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildImageSourceOption(
                      icon: Icons.photo_library_rounded,
                      title: 'Choose from Gallery',
                      subtitle: 'Select from your photos',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),

                    // إضافة خيار حذف الصورة إذا كانت موجودة
                    if (hasExistingImage) ...[
                      const SizedBox(height: 12),
                      _buildImageSourceOption(
                        icon: Icons.delete_outline_rounded,
                        title: 'Remove Photo',
                        subtitle: 'Delete current profile picture',
                        color: AppColors.error,
                        onTap: () {
                          Navigator.pop(context);
                          _removeProfilePicture();
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeProfilePicture() async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Profile Picture'),
        content: Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // إرسال طلب لحذف الصورة من السيرفر
        final updateResult = await ApiService.updateParentProfile({
          'profile_picture': null, // استخدم null بدلاً من ''
        });

        if (updateResult) {
          setState(() {
            _profilePictureUrl = null;
            _selectedImagePath = null;
            _pickedImageFile = null;
            _currentUserData['profile_picture'] = '';
            _editedData['profile_picture'] = '';
          });

          _showSuccessSnackBar('Profile picture removed');
        }
      } catch (e) {
        _showErrorSnackBar('Failed to remove picture: $e');
      }
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    final currentImage = _profilePictureUrl ?? _currentUserData['profile_picture'] ?? '';

    return Stack(
      children: [
        // Outer glow effect
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withOpacity(0.2),
                AppColors.primary.withOpacity(0.1),
                Colors.transparent,
              ],
              stops: const [0.1, 0.5, 1.0],
            ),
          ),
        ),

        // Main avatar
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              radius: 62,
              backgroundColor: AppColors.surface,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.background,
                backgroundImage: _selectedImagePath != null
                    ? FileImage(File(_selectedImagePath!)) as ImageProvider
                    : (currentImage.isNotEmpty
                    ? NetworkImage(currentImage)
                    : const AssetImage('assets/images/default_avatar.png') as ImageProvider),
                child: _isUploadingImage
                    ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
                    : (_selectedImagePath == null && currentImage.isEmpty
                    ? Icon(
                  Icons.person_rounded,
                  size: 50,
                  color: AppColors.textLight,
                )
                    : null),
              ),
            ),
          ),
        ),

        // Camera button
        Positioned(
          bottom: 6,
          right: 6,
          child: GestureDetector(
            onTap: _isUploadingImage ? null : _showImageSourceDialog,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: _isUploadingImage
                    ? null
                    : LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: _isUploadingImage ? Colors.grey : null,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isUploadingImage
                  ? Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
                  : Icon(
                Icons.camera_alt_rounded,
                color: AppColors.textWhite,
                size: 20,
              ),
            ),
          ),
        ),
      ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                letterSpacing: -0.2,
              ),
            ),
          ),
          CustomTextField(
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
              final fieldName = _getFieldNameFromLabel(label);
              if (fieldName != null) {
                setState(() {
                  _editedData[fieldName] = value.trim();
                });
              }
            },
          ),
        ],
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

    if ((_profilePictureUrl ?? '') != (_currentUserData['profile_picture'] ?? '')) {
      return true;
    }

    for (final key in _currentUserData.keys) {
      if (key != 'profile_picture' && _editedData[key] != _currentUserData[key]) {
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
      // إزالة حقل الصورة لأنه تم رفعه منفصلاً
      final Map<String, dynamic> updateData = {};

      // أضف فقط الحقول التي تغيرت
      for (final key in _editedData.keys) {
        if (key != 'profile_picture' && _editedData[key] != _currentUserData[key]) {
          updateData[key] = _editedData[key];
        }
      }

      // إذا لم يكن هناك بيانات للتحديث
      if (updateData.isEmpty) {
        Navigator.pop(context, true);
        return;
      }

      // طباعة البيانات للتأكد من نوعها
      print('📤 Sending update data: $updateData');
      print('📤 Data type: ${updateData.runtimeType}');

      final success = await ApiService.updateParentProfile(updateData);

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
        content: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: AppColors.success, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_rounded, color: AppColors.error, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Unsaved Changes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                'You have unsaved changes. Are you sure you want to discard them?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGray,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textGray,
                        side: BorderSide(color: AppColors.accent2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Discard'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Edit Profile',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.textDark,
            ),
          ),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _onWillPop().then((pop) {
              if (pop) Navigator.pop(context);
            }),
          ),
          actions: [
            if (_hasChanges && !_isSaving)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: _saveProfile,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Profile Image Section
                Column(
                  children: [
                    _buildProfileImage(),
                    const SizedBox(height: 20),
                    Text(
                      'Tap to change photo',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Form Fields
                _buildFormField(
                  label: 'Full Name',
                  hintText: 'Enter your full name',
                  controller: _fullNameController,
                  icon: Icons.person_outline_rounded,
                  isRequired: true,
                ),

                _buildFormField(
                  label: 'Email',
                  hintText: 'Enter your email address',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  isRequired: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),

                _buildFormField(
                  label: 'Phone',
                  hintText: 'Enter your phone number',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),

                _buildFormField(
                  label: 'Address',
                  hintText: 'Enter your address',
                  controller: _addressController,
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),

                _buildFormField(
                  label: 'Occupation',
                  hintText: 'Enter your occupation',
                  controller: _occupationController,
                  icon: Icons.work_outline,
                ),

                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                    child: _isSaving
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textWhite,
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Cancel Button
                if (_hasChanges)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                        _onWillPop().then((pop) {
                          if (pop) Navigator.pop(context);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textGray,
                        side: BorderSide(color: AppColors.accent2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Profile...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGray,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: _initializeData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}