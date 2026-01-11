import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'map_screen.dart';
import '../theme/app_colors.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _userFormKey = GlobalKey<FormState>();
  final _institutionFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  int _currentStep = 0;
  
  // Use getter for steps to avoid GlobalKey issues
  List<Step> get _steps => [
    Step(
      title: Text('Basic Info'),
      content: _buildUserInfoStep(),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    ),
    Step(
      title: Text('Role Details'),
      content: _buildRoleSpecificStep(),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    ),
    Step(
      title: Text('Verification'),
      content: _buildVerificationStep(),
      isActive: _currentStep >= 2,
      state: StepState.indexed,
    ),
  ];
  
  // User data
  String fullName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String role = 'Parent';
  String? phone;
  XFile? profilePicture;
  XFile? licenseFile;
  TextEditingController _locationController = TextEditingController();
  Map<String, dynamic>? userLocation;

  // Role specific fields
  String? parentAddress;
  String? parentOccupation;
  String? specialistSpecialization;
  int? specialistYearsExperience;
  String? specialistInstitutionId;
  String? donorOrganization;
  String? donorInterests;
  String? institutionName;
  String? institutionContactEmail;
  String? institutionContactPhone;
  String? institutionLicense;
  int? institutionEstablishedYear;
  String? adminDepartment;
  String? adminPermissions;

  // OTP
  String otp = '';
  String? tempToken;

  // Loading states
  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool isGettingLocation = false;

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              width: isWeb ? 600 : double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 40 : 25,
                vertical: isWeb ? 30 : 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header with Logo
                  Container(
                    margin: EdgeInsets.only(bottom: isWeb ? 40 : 30),
                    child: Column(
                      children: [
                        // Logo
                        Container(
                          width: isWeb ? 140 : 120,
                          height: isWeb ? 140 : 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background glow effect
                              Container(
                                width: isWeb ? 130 : 110,
                                height: isWeb ? 130 : 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.1),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),

                              // Main logo
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Person with plus icon
                                  Icon(
                                    Icons.person_add_alt_1,
                                    color: AppColors.primary,
                                    size: isWeb ? 45 : 39,
                                  ),

                                  SizedBox(height: isWeb ? 12 : 5),

                                  // Connection symbol
                                  Container(
                                    width: double.infinity,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Left line
                                        Expanded(
                                          child: Container(
                                            height: 3,
                                            margin: EdgeInsets.only(right: isWeb ? 15 : 10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.primary.withOpacity(0.3),
                                                  AppColors.primary,
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),

                                        // Circle in the middle
                                        Container(
                                          width: isWeb ? 40 : 35,
                                          height: isWeb ? 40 : 35,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.group_add,
                                            color: Colors.white,
                                            size: isWeb ? 25 : 22,
                                          ),
                                        ),

                                        // Right line
                                        Expanded(
                                          child: Container(
                                            height: 3,
                                            margin: EdgeInsets.only(left: isWeb ? 15 : 10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.primary,
                                                  AppColors.primary.withOpacity(0.3),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isWeb ? 20 : 15),

                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: isWeb ? 32 : 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Join our community today',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 14,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tabs for Login/Signup
                  Container(
                    margin: EdgeInsets.only(bottom: isWeb ? 30 : 25),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: Text(
                            'Log in',
                            style: TextStyle(
                              fontSize: isWeb ? 20 : 18,
                              color: AppColors.textGray,
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: isWeb ? 20 : 18,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stepper Indicator
                  Container(
                    margin: EdgeInsets.only(bottom: isWeb ? 30 : 25),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _steps.asMap().entries.map((entry) {
                        int idx = entry.key;
                        return Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: idx <= _currentStep
                                      ? AppColors.primary
                                      : Colors.grey[300],
                                  border: Border.all(
                                    color: idx == _currentStep
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: idx < _currentStep
                                      ? Icon(Icons.check, size: 18, color: Colors.white)
                                      : Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            color: idx <= _currentStep
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _steps[idx].title.toString().replaceAll('Text(\'', '').replaceAll('\')', ''),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: idx <= _currentStep
                                      ? AppColors.primary
                                      : Colors.grey,
                                  fontWeight: idx == _currentStep
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Current Step Content
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isWeb ? 40 : 30),
                    child: _steps[_currentStep].content,
                  ),

                  // Navigation Buttons
                  SizedBox(height: isWeb ? 30 : 25),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _goBack,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: isWeb ? 18 : 16),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_back, size: isWeb ? 20 : 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: isWeb ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        if (_currentStep > 0) SizedBox(width: 16),
                        
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: isWeb ? 60 : 55,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: isLoading ? null : _submitStep,
                              child: isLoading
                                  ? SizedBox(
                                      height: isWeb ? 24 : 20,
                                      width: isWeb ? 24 : 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _getButtonText(_currentStep),
                                          style: TextStyle(
                                            fontSize: isWeb ? 18 : 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Icon(
                                          _getButtonIcon(_currentStep),
                                          size: isWeb ? 20 : 18,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Login Link
                  SizedBox(height: isWeb ? 25 : 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: isWeb ? 14 : 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Text(
                          'Log In',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: isWeb ? 14 : 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom decorative element
                  SizedBox(height: isWeb ? 30 : 20),
                  Container(
                    width: 100,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getButtonText(int step) {
    switch (step) {
      case 0: return 'Continue';
      case 1: return 'Create Account';
      case 2: return 'Verify & Complete';
      default: return 'Next';
    }
  }

  IconData _getButtonIcon(int step) {
    switch (step) {
      case 0:
      case 1: return Icons.arrow_forward;
      case 2: return Icons.verified;
      default: return Icons.arrow_forward;
    }
  }

  Widget _buildUserInfoStep() {
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return SingleChildScrollView(
      child: Form(
        key: _userFormKey,
        child: Column(
          children: [
            // Profile Picture
            Column(
              children: [
                GestureDetector(
                  onTap: _pickProfilePicture,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: profilePicture == null
                        ? Icon(Icons.add_a_photo, size: 40, color: AppColors.primary)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.file(
                              File(profilePicture!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 8),
                if (profilePicture != null)
                  TextButton.icon(
                    onPressed: _pickProfilePicture,
                    icon: Icon(Icons.change_circle, size: 16),
                    label: Text('Change Photo'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 25),

            // Full Name
            _buildTextField(
              label: 'Full Name *',
              hintText: 'Enter your full name',
              icon: Icons.person_outline,
              isWeb: isWeb,
              onChanged: (val) => fullName = val,
              validator: (val) => val!.trim().isEmpty ? 'Required' : null,
            ),
            SizedBox(height: isWeb ? 20 : 16),

            // Email
            _buildTextField(
              label: 'Email Address *',
              hintText: 'your@email.com',
              icon: Icons.email_outlined,
              isWeb: isWeb,
              keyboardType: TextInputType.emailAddress,
              onChanged: (val) => email = val,
              validator: (val) {
                if (val!.isEmpty) return 'Required';
                final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                if (!emailRegex.hasMatch(val)) return 'Enter valid email';
                return null;
              },
            ),
            SizedBox(height: isWeb ? 20 : 16),

            // Phone
            _buildTextField(
              label: 'Phone Number *',
              hintText: 'Enter your phone number',
              icon: Icons.phone_outlined,
              isWeb: isWeb,
              keyboardType: TextInputType.phone,
              onChanged: (val) => phone = val,
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: isWeb ? 20 : 16),

            // Password
            _buildPasswordField(
              label: 'Password *',
              hintText: 'Enter password (min 6 characters)',
              isWeb: isWeb,
              obscureText: !showPassword,
              onTogglePassword: () => setState(() => showPassword = !showPassword),
              onChanged: (val) => password = val,
              validator: (val) => val!.length < 6 ? 'Minimum 6 characters' : null,
            ),
            SizedBox(height: isWeb ? 20 : 16),

            // Confirm Password
            _buildPasswordField(
              label: 'Confirm Password *',
              hintText: 'Re-enter your password',
              isWeb: isWeb,
              obscureText: !showConfirmPassword,
              onTogglePassword: () => setState(() => showConfirmPassword = !showConfirmPassword),
              onChanged: (val) => confirmPassword = val,
              validator: (val) {
                if (val!.isEmpty) return 'Required';
                if (val != password) return 'Passwords do not match';
                return null;
              },
            ),
            SizedBox(height: isWeb ? 20 : 16),

            // Location
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isWeb ? 16 : 14,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Enter your address or select from map',
                    hintStyle: TextStyle(color: AppColors.textLight),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: isWeb ? 20 : 16,
                    ),
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.map_outlined, color: AppColors.primary),
                          onPressed: _openMapPicker,
                          tooltip: 'Select from map',
                        ),
                        // IconButton(
                        //   icon: isGettingLocation
                        //       ? SizedBox(
                        //           width: 20,
                        //           height: 20,
                        //           child: CircularProgressIndicator(
                        //             color: AppColors.primary,
                        //             strokeWidth: 2,
                        //           ),
                        //         )
                        //       : Icon(Icons.my_location, color: AppColors.primary),
                        //   onPressed: getCurrentLocation,
                        //   tooltip: 'Use current location',
                        // ),
                      ],
                    ),
                  ),
                  controller: _locationController,
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
              ],
            ),
            SizedBox(height: 8),

            // Location status
            if (userLocation != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Selected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            userLocation!['address'] ?? 'Unknown address',
                            style: TextStyle(fontSize: 12, color: Colors.green[700]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.clear, size: 16, color: Colors.green),
                      onPressed: () {
                        setState(() {
                          userLocation = null;
                          _locationController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),

            if (userLocation == null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: getCurrentLocation,
                  icon: Icon(Icons.location_searching, size: 16),
                  label: Text('Detect My Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            SizedBox(height: isWeb ? 20 : 16),

            // Role Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Role *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isWeb ? 16 : 14,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  items: [
                    DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                    // DropdownMenuItem(value: 'Specialist', child: Text('Specialist')),
                    DropdownMenuItem(value: 'Donor', child: Text('Donor')),
                    DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (val) => setState(() => role = val!),
                  decoration: InputDecoration(
                    hintText: 'Select your role',
                    hintStyle: TextStyle(color: AppColors.textLight),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: isWeb ? 20 : 16,
                    ),
                    prefixIcon: Icon(
                      Icons.work_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  dropdownColor: AppColors.surface,
                ),
              ],
            ),

            // License Upload for Manager
            if (role == 'Manager') ...[
              SizedBox(height: isWeb ? 25 : 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Institution License (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickLicenseFile,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: licenseFile == null
                              ? Colors.grey[300]!
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: licenseFile == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 40,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Upload License',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '(PDF, JPG, PNG)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 40,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'License uploaded',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSpecificStep() {
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return SingleChildScrollView(
      child: Form(
        key: _institutionFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role-specific header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getRoleColor(role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _getRoleColor(role)),
              ),
              child: Row(
                children: [
                  Icon(_getRoleIcon(role), color: _getRoleColor(role)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getRoleTitle(role),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(role),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _getRoleDescription(role),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 25),

            // Parent Specific Fields
            if (role == 'Parent') ...[
              // _buildTextField(
              //   label: 'Address',
              //   hintText: 'Enter your home address',
              //   icon: Icons.home_outlined,
              //   isWeb: isWeb,
              //   onChanged: (val) => parentAddress = val,
              //   validator: (val) =>null,
              // ),
              SizedBox(height: isWeb ? 20 : 16),
              _buildTextField(
                label: 'Occupation',
                hintText: 'Enter your occupation',
                icon: Icons.work_outlined,
                isWeb: isWeb,
                onChanged: (val) => parentOccupation = val,
                validator: (val) =>null,
              ),
            ],

            // Specialist Specific Fields
            // if (role == 'Specialist') ...[
            //   _buildTextField(
            //     label: 'Specialization *',
            //     hintText: 'e.g., Speech Therapy, Occupational Therapy',
            //     icon: Icons.medical_services_outlined,
            //     isWeb: isWeb,
            //     onChanged: (val) => specialistSpecialization = val,
            //     validator: (val) => val!.isEmpty ? 'Required' : null,
            //   ),
            //   SizedBox(height: isWeb ? 20 : 16),
            //   _buildTextField(
            //     label: 'Years of Experience *',
            //     hintText: 'Enter number of years',
            //     icon: Icons.timeline_outlined,
            //     isWeb: isWeb,
            //     keyboardType: TextInputType.number,
            //     onChanged: (val) => specialistYearsExperience = int.tryParse(val),
            //     validator: (val) => val!.isEmpty ? 'Required' : null,
            //   ),
            //   SizedBox(height: isWeb ? 20 : 16),
            //   _buildTextField(
            //     label: 'Institution ID (Optional)',
            //     hintText: 'If affiliated with an institution',
            //     icon: Icons.business_outlined,
            //     isWeb: isWeb,
            //     onChanged: (val) => specialistInstitutionId = val,
            //     validator: (val) =>null,
            //   ),
            // ],

            // Donor Specific Fields
            if (role == 'Donor') ...[
              _buildTextField(
                label: 'Organization (Optional)',
                hintText: 'Enter your organization name',
                icon: Icons.business_outlined,
                isWeb: isWeb,
                onChanged: (val) => donorOrganization = val,
                validator: (val) =>null,
              ),
              SizedBox(height: isWeb ? 20 : 16),
              _buildTextField(
                label: 'Areas of Interest',
                hintText: 'e.g., Education, Healthcare, Technology',
                icon: Icons.interests_outlined,
                isWeb: isWeb,
                onChanged: (val) => donorInterests = val,
                validator: (val) =>null,
              ),
            ],

            // Manager Specific Fields
            if (role == 'Manager') ...[
              _buildTextField(
                label: 'Institution Name *',
                hintText: 'Enter institution name',
                icon: Icons.business,
                isWeb: isWeb,
                onChanged: (val) => institutionName = val,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: isWeb ? 20 : 16),
              _buildTextField(
                label: 'Institution Email *',
                hintText: 'institution@email.com',
                icon: Icons.email_outlined,
                isWeb: isWeb,
                keyboardType: TextInputType.emailAddress,
                onChanged: (val) => institutionContactEmail = val,
                validator: (val) {
                  if (val!.isEmpty) return 'Required';
                  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (!emailRegex.hasMatch(val)) return 'Enter valid email';
                  return null;
                },
              ),
              SizedBox(height: isWeb ? 20 : 16),
              _buildTextField(
                label: 'Institution Phone *',
                hintText: 'Enter institution phone number',
                icon: Icons.phone_outlined,
                isWeb: isWeb,
                keyboardType: TextInputType.phone,
                onChanged: (val) => institutionContactPhone = val,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: isWeb ? 20 : 16),
              _buildTextField(
                label: 'Established Year',
                hintText: 'e.g., 2020',
                icon: Icons.calendar_today_outlined,
                isWeb: isWeb,
                keyboardType: TextInputType.number,
                onChanged: (val) => institutionEstablishedYear = int.tryParse(val),
                validator: (val) =>null,
              ),
              SizedBox(height: isWeb ? 20 : 16),
              _buildTextField(
                label: 'License Number (Optional)',
                hintText: 'Enter license number',
                icon: Icons.badge_outlined,
                isWeb: isWeb,
                onChanged: (val) => institutionLicense = val,
                validator: (val) =>null,
              ),
            ],

            // Admin Specific Fields
            if (role == 'Admin') ...[
              _buildTextField(
                label: 'Department',
                hintText: 'Enter department name',
                icon: Icons.dashboard_outlined,
                isWeb: isWeb,
                onChanged: (val) => adminDepartment = val,
                validator: (val) =>null,
              ),
              SizedBox(height: isWeb ? 20 : 16),
              _buildTextField(
                label: 'Permissions Level',
                hintText: 'e.g., Super Admin, Moderator',
                icon: Icons.admin_panel_settings_outlined,
                isWeb: isWeb,
                onChanged: (val) => adminPermissions = val,
                validator: (val) => null,
              ),
            ],

            // Information Box
            SizedBox(height: 25),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _getRoleColor(role).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _getRoleColor(role),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getRoleInstruction(role),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationStep() {
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return SingleChildScrollView(
      child: Form(
        key: _otpFormKey,
        child: Column(
          children: [
            SizedBox(height: 20),
            Icon(
              Icons.verified_user_outlined,
              size: 80,
              color: AppColors.primary,
            ),
            SizedBox(height: 25),
            Text(
              'Verify Your Email',
              style: TextStyle(
                fontSize: isWeb ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'We sent a verification code to:',
              style: TextStyle(
                fontSize: isWeb ? 16 : 14,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 8),
            Text(
              email,
              style: TextStyle(
                fontSize: isWeb ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 40),

            // OTP Input
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isWeb ? 60 : 40),
              child: TextFormField(
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit code',
                  hintStyle: TextStyle(color: AppColors.textLight),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: isWeb ? 22 : 18,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_clock_outlined,
                    color: AppColors.primary,
                  ),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isWeb ? 22 : 20, letterSpacing: 6),
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (val) => otp = val,
                validator: (val) => val!.length != 6 ? 'Must be 6 digits' : null,
              ),
            ),
            SizedBox(height: 25),

            // Resend OTP
            TextButton(
              onPressed: _resendOTP,
              child: Text(
                'Resend Code',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: isWeb ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Code expires in 15 minutes',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGray,
              ),
            ),
            SizedBox(height: 40),

            // Account Summary
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Summary',
                    style: TextStyle(
                      fontSize: isWeb ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 15),
                  _buildSummaryRow('Name:', fullName, isWeb),
                  _buildSummaryRow('Role:', role, isWeb),
                  _buildSummaryRow('Email:', email, isWeb),
                  if (role == 'Manager' && institutionName != null)
                    _buildSummaryRow('Institution:', institutionName!, isWeb),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isWeb) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: isWeb ? 14 : 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isWeb ? 14 : 12,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required IconData icon,
    required bool isWeb,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isWeb ? 16 : 14,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.textLight),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isWeb ? 20 : 16,
            ),
            prefixIcon: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hintText,
    required bool isWeb,
    required bool obscureText,
    required VoidCallback onTogglePassword,
    required Function(String) onChanged,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isWeb ? 16 : 14,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.textLight),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isWeb ? 20 : 16,
            ),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: AppColors.primary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: AppColors.primary,
              ),
              onPressed: onTogglePassword,
            ),
          ),
          obscureText: obscureText,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  String _getRoleTitle(String role) {
    switch (role) {
      case 'Parent': return 'Parent Account';
      case 'Specialist': return 'Specialist Account';
      case 'Donor': return 'Donor Account';
      case 'Manager': return 'Institution Manager';
      case 'Admin': return 'Administrator';
      default: return 'User Account';
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'Parent': return 'Manage children, book sessions, track progress';
      case 'Specialist': return 'Provide therapy sessions, manage cases';
      case 'Donor': return 'Support programs, fund initiatives';
      case 'Manager': return 'Manage institution, staff, and services';
      case 'Admin': return 'Platform administration and moderation';
      default: return 'User account';
    }
  }

  String _getRoleInstruction(String role) {
    switch (role) {
      case 'Parent': return 'You will be able to add children and book sessions after approval.';
      case 'Specialist': return 'Your account requires admin approval before activation.';
      case 'Donor': return 'Thank you for supporting our cause!';
      case 'Manager': return 'Your institution will be reviewed by admin before activation.';
      case 'Admin': return 'Admin accounts require approval from existing administrators.';
      default: return 'Your account will be activated after verification.';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Parent': return Colors.blue;
      case 'Specialist': return Colors.purple;
      case 'Donor': return Colors.green;
      case 'Manager': return Colors.orange;
      case 'Admin': return Colors.red;
      default: return AppColors.primary;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Parent': return Icons.family_restroom;
      case 'Specialist': return Icons.medical_services;
      case 'Donor': return Icons.volunteer_activism;
      case 'Manager': return Icons.business;
      case 'Admin': return Icons.admin_panel_settings;
      default: return Icons.person;
    }
  }

  Future<void> _pickProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => profilePicture = pickedFile);
    }
  }

  Future<void> _pickLicenseFile() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => licenseFile = pickedFile);
    }
  }

  Future<void> getCurrentLocation() async {
    setState(() => isGettingLocation = true);
    final location = await LocationService.getCurrentLocation();
    setState(() {
      userLocation = location;
      isGettingLocation = false;
    });

    if (location != null && location['success'] == true) {
      _locationController.text = location['address'] ?? 'Current Location';
    }
  }

  Future<void> _openMapPicker() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            initialLat: userLocation?['lat'],
            initialLng: userLocation?['lng'],
            initialAddress: userLocation?['address'],
          ),
        ),
      );

      if (result != null && result is Map) {
        setState(() {
          userLocation = {
            'lat': result['lat'],
            'lng': result['lng'],
            'address': result['address'],
          };
          _locationController.text = userLocation!['address'];
        });
      }
    } catch (e) {
      print('Error in map picker: $e');
    }
  }

  void _resendOTP() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification code resent to your email'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (!_userFormKey.currentState!.validate()) return false;
        if (password != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Passwords do not match')),
          );
          return false;
        }
        return true;
      case 1:
        if (role == 'Manager' && !_institutionFormKey.currentState!.validate()) {
          return false;
        }
        if (role == 'Specialist' && !_institutionFormKey.currentState!.validate()) {
          return false;
        }
        return true;
      case 2:
        if (!_otpFormKey.currentState!.validate()) return false;
        return true;
      default:
        return false;
    }
  }

  Future<void> _submitStep() async {
    if (!_validateCurrentStep()) return;

    if (_currentStep == 2) {
      await _verifyOTP();
      return;
    }

    if (_currentStep == 1) {
      await _sendSignupData();
      return;
    }

    setState(() => _currentStep++);
  }

  Future<void> _sendSignupData() async {
    setState(() => isLoading = true);

    Map<String, dynamic> locationData = userLocation ?? {
      'lat': 31.9539,
      'lng': 35.9106,
      'address': 'Amman, Jordan',
      'city': 'Amman',
      'region': 'Middle East',
    };

    final Map<String, dynamic> data = {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'password': password,
      'role': role,
      'phone': phone,
      'location_lat': locationData['lat'],
      'location_lng': locationData['lng'],
      'location_address': locationData['address'],
      'city': locationData['city'],
      'region': locationData['region'],
    };

    if (role == 'Parent') {
      data['address'] = parentAddress;
      data['occupation'] = parentOccupation;
    } else if (role == 'Specialist') {
      data['specialization'] = specialistSpecialization;
      data['years_experience'] = specialistYearsExperience;
      data['institution_id'] = specialistInstitutionId;
    } else if (role == 'Donor') {
      data['address'] = locationData['address'];
      data['occupation'] = donorOrganization;
    } else if (role == 'Manager') {
      data['institution_name'] = institutionName;
      data['institution_contact_email'] = institutionContactEmail;
      data['institution_contact_phone'] = institutionContactPhone;
      data['institution_license'] = institutionLicense;
      data['institution_established_year'] = institutionEstablishedYear;
      data['institution_city'] = locationData['city'];
      data['institution_region'] = locationData['region'];
    } else if (role == 'Admin') {
      data['address'] = locationData['address'];
      data['occupation'] = adminDepartment;
    }

    try {
      final response = await ApiService.signupInitial(data);
      setState(() => isLoading = false);

      if (response['success'] == true) {
        setState(() {
          tempToken = response['tempToken'];
          _currentStep++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to your email'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${response['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error. Check your internet connection'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyOTP() async {
    setState(() => isLoading = true);

    try {
      final response = await ApiService.verifySignup(tempToken!, otp);
      setState(() => isLoading = false);

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }
}