import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/institution_service.dart';
import '../../models/institution_profile.dart';
import '../../theme/app_colors.dart';
import '../map_screen.dart';

class EditInstitutionProfileScreen extends StatefulWidget {
  final InstitutionProfile profile;
  final VoidCallback onProfileUpdated;

  EditInstitutionProfileScreen({
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  _EditInstitutionProfileScreenState createState() => _EditInstitutionProfileScreenState();
}

class _EditInstitutionProfileScreenState extends State<EditInstitutionProfileScreen> {
  // Text Controllers
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _locationAddressController;
  late TextEditingController _cityController;
  late TextEditingController _regionController;
  late TextEditingController _contactEmailController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _servicesController;
  late TextEditingController _conditionsController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _managerFullNameController;
  late TextEditingController _managerPhoneController;
  late TextEditingController _managerEmailController;

  // Image Variables
  File? _selectedImage;
  String? _profilePictureUrl;
  bool _isUploadingImage = false;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _descriptionController = TextEditingController(
      text: widget.profile.institution.description ?? '',
    );
    _locationController = TextEditingController(
      text: widget.profile.institution.location ?? '',
    );
    _locationAddressController = TextEditingController(
      text: widget.profile.institution.locationAddress ?? '',
    );
    _cityController = TextEditingController(
      text: widget.profile.institution.city ?? '',
    );
    _regionController = TextEditingController(
      text: widget.profile.institution.region ?? '',
    );
    _contactEmailController = TextEditingController(
      text: widget.profile.institution.contactEmail ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: widget.profile.institution.contactPhone ?? '',
    );
    _servicesController = TextEditingController(
      text: widget.profile.institution.servicesOffered.join(', '),
    );
    _conditionsController = TextEditingController(
      text: widget.profile.institution.conditionsSupported.join(', '),
    );

    _latController = TextEditingController(
      text: widget.profile.institution.lat?.toString() ?? '',
    );
    _lngController = TextEditingController(
      text: widget.profile.institution.lng?.toString() ?? '',
    );

    _managerFullNameController = TextEditingController(
      text: widget.profile.manager.fullName,
    );
    _managerPhoneController = TextEditingController(
      text: widget.profile.manager.phone ?? '',
    );
    _managerEmailController = TextEditingController(
      text: widget.profile.manager.email,
    );

    // Initialize profile picture
    _profilePictureUrl = widget.profile.manager.profilePicture;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _locationAddressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _servicesController.dispose();
    _conditionsController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _managerFullNameController.dispose();
    _managerPhoneController.dispose();
    _managerEmailController.dispose();
    super.dispose();
  }

  // ========== IMAGE PICKER FUNCTIONS ==========

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        // Upload image immediately
        await _uploadImage();
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    // Validate image size
    final isValidSize = await InstitutionService.validateImageSize(_selectedImage!);
    if (!isValidSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image size must be less than 5MB'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final result = await InstitutionService.uploadProfilePicture(_selectedImage!);

      if (result['success'] == true) {
        setState(() {
          _profilePictureUrl = result['profile_picture'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Widget _buildProfilePictureSection() {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: ClipOval(
                  child: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                      ? Image.network(
                    _profilePictureUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultProfilePicture();
                    },
                  )
                      : _selectedImage != null
                      ? Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  )
                      : _buildDefaultProfilePicture(),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: _isUploadingImage
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    onPressed: _isUploadingImage ? null : _pickImage,
                    padding: EdgeInsets.zero,
                    tooltip: 'Change profile picture',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Manager Profile Picture',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap camera icon to upload',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultProfilePicture() {
    return Container(
      color: AppColors.surface,
      child: Icon(
        Icons.person,
        size: 60,
        color: AppColors.textLight,
      ),
    );
  }

  // ========== MAP FUNCTIONS ==========

  Future<void> _openMapPicker() async {
    double? initialLat = double.tryParse(_latController.text);
    double? initialLng = double.tryParse(_lngController.text);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLat: initialLat,
          initialLng: initialLng,
          initialAddress: _locationController.text,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _latController.text = result['lat']?.toString() ?? '';
        _lngController.text = result['lng']?.toString() ?? '';
        _locationController.text = result['address']?.toString() ?? '';
        _cityController.text = result['city']?.toString() ?? '';
        _regionController.text = result['region']?.toString() ?? '';
        _locationAddressController.text = result['address']?.toString() ?? '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 Location selected successfully'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ========== PROFILE UPDATE FUNCTION ==========

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      double? latValue = double.tryParse(_latController.text);
      double? lngValue = double.tryParse(_lngController.text);

      final updateData = InstitutionService.prepareUpdateData(
        description: _descriptionController.text,
        location: _locationController.text,
        locationAddress: _locationAddressController.text,
        city: _cityController.text,
        region: _regionController.text,
        lat: latValue,
        lng: lngValue,
        contactEmail: _contactEmailController.text,
        contactPhone: _contactPhoneController.text,
        servicesOffered: _servicesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        conditionsSupported: _conditionsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        managerFullName: _managerFullNameController.text,
        managerPhone: _managerPhoneController.text,
        managerEmail: _managerEmailController.text,
      );

      if (updateData.isEmpty) {
        throw Exception('No changes detected');
      }

      await InstitutionService.updateInstitutionProfile(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onProfileUpdated();
      Navigator.pop(context);

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ========== BUILD METHOD ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit Profile'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(
                Icons.save_rounded,
                color: AppColors.primary,
              ),
              onPressed: _isLoading ? null : _updateProfile,
              tooltip: 'Save Changes',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Saving changes...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit institution and manager profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Profile Picture Section
              _buildProfilePictureSection(),

              // Institution Information Section
              _buildSection(
                title: 'Institution Information',
                icon: Icons.business_rounded,
                color: AppColors.primary,
                children: [
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Enter institution description',
                    icon: Icons.description_rounded,
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter description';
                      }
                      if (value.length < 10) {
                        return 'Description should be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Location Information
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.textLight.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location Information',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 12),

                        // Location Name with Map Button
                        _buildTextFieldWithMap(
                          controller: _locationController,
                          label: 'Location Name',
                          hint: 'Enter location name',
                          icon: Icons.place_rounded,
                          showMapButton: true,
                          onMapTap: _openMapPicker,
                        ),
                        SizedBox(height: 12),

                        // City with Map Button
                        _buildTextFieldWithMap(
                          controller: _cityController,
                          label: 'City',
                          hint: 'Enter city name',
                          icon: Icons.location_city_rounded,
                          showMapButton: true,
                          onMapTap: _openMapPicker,
                        ),
                        SizedBox(height: 12),

                        // Address (auto-filled from map)
                        TextFormField(
                          controller: _locationAddressController,
                          decoration: InputDecoration(
                            labelText: 'Detailed Address',
                            hintText: 'Select location from map',
                            prefixIcon: Icon(Icons.home_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.map_outlined, color: AppColors.primary),
                              onPressed: _openMapPicker,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          readOnly: true,
                          onTap: _openMapPicker,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Contact Information
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.textLight.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _contactEmailController,
                                label: 'Contact Email',
                                hint: 'contact@institution.com',
                                icon: Icons.email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                    if (!emailRegex.hasMatch(value)) {
                                      return 'Please enter valid email';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _contactPhoneController,
                                label: 'Contact Phone',
                                hint: '+962 7X XXX XXXX',
                                icon: Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Services and Conditions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _servicesController,
                        label: 'Services Offered',
                        hint: 'Speech Therapy, Occupational Therapy...',
                        icon: Icons.medical_services_rounded,
                        maxLines: 3,
                        helperText: 'Enter services separated by commas',
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _conditionsController,
                        label: 'Supported Conditions',
                        hint: 'Autism, ADHD, Down Syndrome...',
                        icon: Icons.health_and_safety,
                        maxLines: 3,
                        helperText: 'Enter conditions separated by commas',
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Manager Information Section
              _buildSection(
                title: 'Manager Information',
                icon: Icons.person_rounded,
                color: AppColors.green,
                children: [
                  _buildTextField(
                    controller: _managerFullNameController,
                    label: 'Full Name',
                    hint: 'Enter full name',
                    icon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter full name';
                      }
                      if (value.length < 3) {
                        return 'Name should be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _managerEmailController,
                          label: 'Email',
                          hint: 'manager@example.com',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Please enter valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _managerPhoneController,
                          label: 'Phone',
                          hint: '+962 7X XXX XXXX',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 32),

              // Action Buttons
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Info Note
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '• Upload profile picture by tapping camera icon\n• Select location from map for accurate positioning\n• All changes will be saved immediately\n• Some fields like institution name cannot be edited here',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ========== HELPER WIDGETS ==========

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helperText,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    bool? readOnly,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              helperText: helperText,
              helperStyle: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
              ),
              prefixIcon: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.textLight),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: readOnly == true ? AppColors.surface.withOpacity(0.5) : AppColors.surface,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            keyboardType: keyboardType,
            maxLines: maxLines ?? 1,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
            validator: validator,
            readOnly: readOnly ?? false,
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithMap({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool showMapButton = false,
    VoidCallback? onMapTap,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.textLight),
              ),
              suffixIcon: showMapButton
                  ? IconButton(
                icon: Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
                onPressed: onMapTap,
                tooltip: 'Select from map',
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: validator,
            onTap: showMapButton ? onMapTap : null,
          ),
        ],
      ),
    );
  }
}