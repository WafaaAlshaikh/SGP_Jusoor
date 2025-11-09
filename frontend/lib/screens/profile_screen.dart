import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/activity_service.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _errorMessage = '';

  // Colors
  static const Color primary = Color(0xFF7815A0);
  static const Color background = Color(0xFFF0E5FF);
  static const Color textDark = Color(0xFF333333);
  static const Color textGray = Color(0xFF777777);
  static const Color textName = Color(0xFFE5DDFD);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFE5DDFD);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final response = await ProfileService.getProfile();
      setState(() {
        _userData = response['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfilePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 70,
      );

      if (image != null) {
        // Here you would typically upload the image to your server
        final response = await ProfileService.updateProfile(
          profilePicture: 'uploads/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (response['success'] == true) {
          await _loadProfile();
          _showSuccessSnackBar('Profile picture updated successfully');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update profile picture: $e');
    }
  }

  void _editPersonalInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditPersonalInfoSheet(),
    );
  }

  void _editEmail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditEmailSheet(),
    );
  }

  void _changePassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildChangePasswordSheet(),
    );
  }

  void _editProfessionalInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditProfessionalInfoSheet(),
    );
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

  Widget _buildEditPersonalInfoSheet() {
    final TextEditingController fullNameController =
    TextEditingController(text: _userData?['full_name'] ?? '');
    final TextEditingController phoneController =
    TextEditingController(text: _userData?['phone'] ?? '');

    return _buildBottomSheet(
      title: 'Edit Personal Information',
      children: [
        _buildTextField(
          controller: fullNameController,
          label: 'Full Name',
          icon: Icons.person,
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: phoneController,
          label: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
      ],
      onSave: () async {
        try {
          final response = await ProfileService.updateProfile(
            fullName: fullNameController.text,
            phone: phoneController.text,
          );

          if (response['success'] == true) {
            Navigator.pop(context);

            await _loadProfile();
            await ActivityService.addActivity(
                'Personal information updated',
                'profile'
            );
            _showSuccessSnackBar('Profile updated successfully');
          }
        } catch (e) {
          _showErrorSnackBar('Failed to update profile: $e');
        }
      },
    );
  }

  Widget _buildEditEmailSheet() {
    final TextEditingController emailController =
    TextEditingController(text: _userData?['email'] ?? '');

    return _buildBottomSheet(
      title: 'Change Email',
      children: [
        _buildTextField(
          controller: emailController,
          label: 'Email Address',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
      onSave: () async {
        try {
          final response = await ProfileService.updateProfile(
            email: emailController.text,
          );

          if (response['success'] == true) {
            Navigator.pop(context);
            await _loadProfile();
            await ActivityService.addActivity(
                'Email address updated',
                'profile'
            );
            _showSuccessSnackBar('Email updated successfully');
          }
        } catch (e) {
          _showErrorSnackBar('Failed to update email: $e');
        }
      },
    );
  }

  Widget _buildChangePasswordSheet() {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    return _buildBottomSheet(
      title: 'Change Password',
      children: [
        _buildTextField(
          controller: currentPasswordController,
          label: 'Current Password',
          icon: Icons.lock,
          obscureText: true,
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: newPasswordController,
          label: 'New Password',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: confirmPasswordController,
          label: 'Confirm New Password',
          icon: Icons.lock_reset,
          obscureText: true,
        ),
      ],
      onSave: () async {
        if (newPasswordController.text != confirmPasswordController.text) {
          _showErrorSnackBar('New passwords do not match');
          return;
        }

        try {
          final response = await ProfileService.changePassword(
            currentPassword: currentPasswordController.text,
            newPassword: newPasswordController.text,
          );

          if (response['success'] == true) {
            Navigator.pop(context);
            await ActivityService.addActivity(
                'Password changed',
                'security'
            );
            _showSuccessSnackBar('Password changed successfully');
          }
        } catch (e) {
          _showErrorSnackBar('Failed to change password: $e');
        }
      },
    );
  }

  Widget _buildEditProfessionalInfoSheet() {
    final TextEditingController specializationController =
    TextEditingController(text: _userData?['specialist_info']?['specialization'] ?? '');
    final TextEditingController yearsExperienceController =
    TextEditingController(text: _userData?['specialist_info']?['years_experience']?.toString() ?? '');

    return _buildBottomSheet(
      title: 'Edit Professional Information',
      children: [
        _buildTextField(
          controller: specializationController,
          label: 'Specialization',
          icon: Icons.work,
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: yearsExperienceController,
          label: 'Years of Experience',
          icon: Icons.timeline,
          keyboardType: TextInputType.number,
        ),
      ],
      onSave: () async {
        try {
          final response = await ProfileService.updateSpecialistInfo(
            specialization: specializationController.text,
            yearsExperience: int.tryParse(yearsExperienceController.text),
          );

          if (response['success'] == true) {
            Navigator.pop(context);
            await ActivityService.addActivity(
                'Profile picture updated',
                'profile'
            );
            await _loadProfile();
            _showSuccessSnackBar('Professional info updated successfully');
          }
        } catch (e) {
          _showErrorSnackBar('Failed to update professional info: $e');
        }
      },
    );
  }

  Widget _buildBottomSheet({
    required String title,
    required List<Widget> children,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          SizedBox(height: 20),
          ...children,
          SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textGray.withOpacity(0.1),
                    foregroundColor: textGray,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Cancel'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Save'),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        filled: true,
        fillColor: background.withOpacity(0.3),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: textName,
                  backgroundImage: _userData?['profile_picture'] != null
                      ? NetworkImage('http://10.0.2.2:5000/${_userData!['profile_picture']}')
                      : null,
                  child: _userData?['profile_picture'] == null
                      ? Icon(
                    Icons.person,
                    size: 45,
                    color: primary,
                  )
                      : null,
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: GestureDetector(
                  onTap: _updateProfilePicture,
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            _userData?['full_name'] ?? 'No Name',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          if (_userData?['role'] == 'Specialist')
            Text(
              _userData?['specialist_info']?['specialization'] ?? 'Specialist',
              style: TextStyle(
                fontSize: 16,
                color: textName,
                fontWeight: FontWeight.w500,
              ),
            ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              _userData?['role'] ?? 'User',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, {VoidCallback? onEdit}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit, color: primary, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
              ],
            ),
            SizedBox(height: 15),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primary, size: 20),
        ),
        title: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: textDark,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: textGray, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primary, strokeWidth: 3),
              SizedBox(height: 20),
              Text(
                'Loading Profile...',
                style: TextStyle(
                  color: textGray,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: primary),
              SizedBox(height: 20),
              Text(
                'Error loading profile',
                style: TextStyle(fontSize: 18, color: textDark, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: textGray),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: _loadProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildProfileHeader(),
            SizedBox(height: 25),

            // Action Buttons
            _buildActionButton('Edit Personal Information', Icons.person, _editPersonalInfo),
            _buildActionButton('Change Email Address', Icons.email, _editEmail),
            _buildActionButton('Change Password', Icons.lock, _changePassword),

            if (_userData?['role'] == 'Specialist') ...[
              SizedBox(height: 8),
              _buildActionButton('Edit Professional Info', Icons.work, _editProfessionalInfo),
            ],

            SizedBox(height: 20),

            // Personal Information
            _buildInfoSection(
              'Personal Information',
              [
                _buildInfoRow('Full Name', _userData?['full_name'] ?? 'No name'),
                _buildInfoRow('Email', _userData?['email'] ?? 'No email'),
                _buildInfoRow('Phone', _userData?['phone'] ?? 'No phone number'),
              ],
            ),

            // Professional Information (for Specialists)
            if (_userData?['role'] == 'Specialist')
              _buildInfoSection(
                'Professional Information',
                [
                  _buildInfoRow(
                    'Specialization',
                    _userData?['specialist_info']?['specialization'] ?? 'Not specified',
                  ),
                  _buildInfoRow(
                    'Years of Experience',
                    '${_userData?['specialist_info']?['years_experience'] ?? 0} years',
                  ),
                  _buildInfoRow(
                    'Salary',
                    '\$${_userData?['specialist_info']?['salary']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                ],
              ),

            // Institution Information
            if (_userData?['institution'] != null)
              _buildInfoSection(
                'Institution',
                [
                  _buildInfoRow('Name', _userData?['institution']['name'] ?? 'Unknown'),
                  _buildInfoRow('Address', _userData?['institution']['location'] ?? _userData?['institution']['address'] ?? 'No address'),
                  _buildInfoRow('Phone', _userData?['institution']['phone'] ?? 'No phone'),
                ],
              ),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textDark,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: textGray,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}