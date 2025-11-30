import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'map_screen.dart';
import '../theme/app_colors.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  // User data
  String fullName = '';
  String email = '';
  String password = '';
  String role = 'Parent';
  String? phone;
  String? profilePicture;

  String? address;
  String? occupation;
  String? specialization;
  int? yearsExperience;
  String? institutionId;
  String? institutionName;
  String? institutionDescription;
  String? location;
  String? website;
  String? contactInfo;

  // Institution data for Manager
  String? institutionContactEmail;
  String? institutionContactPhone;
  String? institutionLicense;
  int? institutionEstablishedYear;

  // OTP data
  String otp = '';
  String? tempToken;
  TextEditingController _locationController = TextEditingController();

  // Loading states
  bool isLoading = false;
  bool showPassword = false;
  bool showOTPScreen = false;

  Map<String, dynamic>? userLocation;
  bool isGettingLocation = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location detected: ${location['address']}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(location?['message'] ?? 'Could not detect location')),
      );
    }
  }

  void _showLocationErrorDialog(Map<String, dynamic> errorResult) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('Location Error'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorResult['message'] ?? 'An error occurred'),
                SizedBox(height: 16),
                if (errorResult['error'] == 'Location permission denied')
                  Text(
                    'To fix this:\n1. Go to Settings → Apps → Your App\n2. Tap Permissions\n3. Allow Location access',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (errorResult['error'] == 'Location services disabled')
                  Text(
                    'To fix this:\n1. Go to Settings → Location\n2. Turn on Location services',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              if (errorResult['error'] == 'Location permission denied')
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    LocationService.openAppSettings();
                  },
                  child: Text('Open Settings'),
                ),
              if (errorResult['error'] == 'Location services disabled')
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    LocationService.openLocationSettings();
                  },
                  child: Text('Enable Location'),
                ),
            ],
          ),
    );
  }

  Widget _buildRoleSpecificFields() {
    switch (role) {
      case 'Parent':
        return Column(
          children: [
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.home_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => address = val,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Occupation',
                prefixIcon: Icon(Icons.work_outline, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => occupation = val,
            ),
          ],
        );

      case 'Specialist':
        return Column(
          children: [
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Specialization',
                prefixIcon: Icon(
                    Icons.medical_services_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => specialization = val,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Years of Experience',
                prefixIcon: Icon(
                    Icons.timeline_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => yearsExperience = int.tryParse(val),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Institution ID (Optional)',
                prefixIcon: Icon(
                    Icons.business_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => institutionId = val,
            ),
          ],
        );

      case 'Manager':
        return Column(
          children: [
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Institution Name *',
                prefixIcon: Icon(Icons.business, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => institutionName = val,
              validator: (val) => val!.isEmpty ? 'Required for Manager' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Institution Contact Email *',
                prefixIcon: Icon(
                    Icons.email_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (val) => institutionContactEmail = val,
              validator: (val) {
                if (val!.isEmpty) return 'Required for Manager';
                final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                if (!emailRegex.hasMatch(val)) return 'Enter valid email';
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Institution Contact Phone *',
                prefixIcon: Icon(
                    Icons.phone_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (val) => institutionContactPhone = val,
              validator: (val) => val!.isEmpty ? 'Required for Manager' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'License Number (Optional)',
                prefixIcon: Icon(
                    Icons.badge_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => institutionLicense = val,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Established Year (Optional)',
                prefixIcon: Icon(
                    Icons.calendar_today_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) =>
              institutionEstablishedYear = int.tryParse(val),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your institution will be reviewed by admin before activation',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'Admin':
        return Column(
          children: [
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Admin accounts require approval from existing administrators',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'Donor':
        return Column(
          children: [
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.volunteer_activism, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Thank you for your interest in supporting our cause!',
                      style: TextStyle(color: Colors.green[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      default:
        return SizedBox.shrink();
    }
  }

  void submitSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    Map<String, dynamic> locationData;

    if (userLocation != null &&
        userLocation!['lat'] != null &&
        userLocation!['lng'] != null) {
      locationData = {
        'lat': userLocation!['lat'],
        'lng': userLocation!['lng'],
        'address': userLocation!['address'] ?? 'Selected Location',
        'city': userLocation!['city'] ?? 'Palestine',
        'region': userLocation!['region'] ?? 'Palestine',
      };
    } else {
      locationData = {
        'lat': 32.4645,
        'lng': 35.3027,
        'address': 'Jenin, Palestine',
        'city': 'Jenin',
        'region': 'North West Bank',
      };
    }

    final Map<String, dynamic> data = {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'password': password,
      'role': role,
      'phone': phone,
      'profile_picture': profilePicture,

      'location_lat': locationData['lat'],
      'location_lng': locationData['lng'],
      'location_address': locationData['address'],
      'city': locationData['city'],
      'region': locationData['region'],

      if (role == 'Parent') ...{
        'address': address ?? locationData['address'],
        'occupation': occupation,
      },
      if (role == 'Specialist') ...{
        'specialization': specialization,
        'years_experience': yearsExperience,
        'institution_id': institutionId,
      },
      if (role == 'Manager') ...{
        'institution_name': institutionName,
        'institution_contact_email': institutionContactEmail,
        'institution_contact_phone': institutionContactPhone,
        'institution_license': institutionLicense,
        'institution_established_year': institutionEstablishedYear,
        'institution_city': locationData['city'],
        'institution_region': locationData['region'],
      },
    };

    try {
      final response = await ApiService.signupInitial(data);
      setState(() => isLoading = false);

      if (response['success'] == true) {
        setState(() {
          tempToken = response['tempToken'];
          showOTPScreen = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to your email'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
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

  void verifyOTP() async {
    if (!_otpFormKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    final response = await ApiService.verifySignup(tempToken!, otp);
    setState(() => isLoading = false);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.green,
        ),
      );

      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void backToSignup() {
    setState(() {
      showOTPScreen = false;
      tempToken = null;
      otp = '';
    });
  }

  Widget _buildLocationField() {
    return Column(
      children: [
        SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Location Address',
            hintText: 'Enter your address or select from map',
            prefixIcon: Icon(
                Icons.location_on_outlined, color: AppColors.primary),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.map_outlined),
                  onPressed: _openMapPicker,
                  tooltip: 'Select from map',
                ),
                IconButton(
                  icon: isGettingLocation
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Icon(Icons.my_location),
                  onPressed: getCurrentLocation,
                  tooltip: 'Use current location',
                ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          controller: _locationController,
          onChanged: (val) {
            if (val.isNotEmpty && val.length > 3) {
              _searchAddress(val);
            }
          },
        ),
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Enter address manually or use buttons to detect/set location',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        if (userLocation != null) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
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
                        style: TextStyle(
                            fontSize: 12, color: Colors.green[700]),
                      ),
                      if (userLocation!['lat'] != null)
                        Text(
                          'Lat: ${userLocation!['lat']!.toStringAsFixed(
                              4)}, Lng: ${userLocation!['lng']!.toStringAsFixed(
                              4)}',
                          style: TextStyle(fontSize: 10, color: Colors
                              .green[600]),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.clear, size: 16),
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
        ],
        if (userLocation == null) ...[
          SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: getCurrentLocation,
            icon: Icon(Icons.location_searching, size: 16),
            label: Text('Detect My Location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }

  void _openMapPicker() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MapScreen(
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
            'city': result['city'] ??
                _extractCityFromAddress(result['address']),
            'region': result['region'] ??
                _extractRegionFromAddress(result['address']),
          };
          _locationController.text = userLocation!['address'];
        });
      }
    } catch (e) {
      print('Error in map picker: $e');
    }
  }

  String _extractCityFromAddress(String address) {
    if (address.contains('Jenin')) return 'Jenin';
    if (address.contains('Ramallah')) return 'Ramallah';
    if (address.contains('Gaza')) return 'Gaza';
    if (address.contains('Hebron')) return 'Hebron';
    if (address.contains('Nablus')) return 'Nablus';
    if (address.contains('Bethlehem')) return 'Bethlehem';
    return 'Palestine';
  }

  String _extractRegionFromAddress(String address) {
    if (address.contains('Jenin') || address.contains('Nablus'))
      return 'North West Bank';
    if (address.contains('Ramallah') || address.contains('Bethlehem'))
      return 'Central West Bank';
    if (address.contains('Hebron')) return 'South West Bank';
    if (address.contains('Gaza')) return 'Gaza Strip';
    return 'Palestine';
  }

  Future<void> _searchAddress(String address) async {
    if (address.length > 3) {
      final location = await LocationService.getLocationFromAddress(address);
      if (location != null) {
        setState(() {
          userLocation = location;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery
        .of(context)
        .size
        .width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Container(
            width: isWeb ? 500 : double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isWeb ? 40 : 30,
              vertical: isWeb ? 20 : 40,
            ),
            child: SingleChildScrollView(
              child: showOTPScreen ? _buildOTPScreen() : _buildSignupScreen(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOTPScreen() {
    final bool isWeb = MediaQuery
        .of(context)
        .size
        .width > 600;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Back button and title
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: backToSignup,
            ),
            SizedBox(width: 10),
            Text(
              'Verify Email',
              style: TextStyle(
                fontSize: isWeb ? 28 : 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        SizedBox(height: 30),

        Text(
          'Enter the 6-digit code sent to:',
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
        SizedBox(height: 30),

        // OTP Form
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 25,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(isWeb ? 35 : 25),
          child: Form(
            key: _otpFormKey,
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'OTP Code',
                    hintText: 'Enter 6-digit code',
                    prefixIcon: Icon(
                        Icons.lock_outline, color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (val) => otp = val,
                  validator: (val) =>
                  val!.length != 6
                      ? 'Enter 6-digit code'
                      : null,
                ),
                SizedBox(height: 24),

                // Verify Button
                Container(
                  width: double.infinity,
                  height: isWeb ? 55 : 50,
                  decoration: BoxDecoration(
                    color: Color(0xFF3F7892),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF3F7892).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isLoading ? null : verifyOTP,
                    child: isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                        : Text(
                      'Verify & Complete Signup',
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('OTP resent to your email')),
                    );
                  },
                  child: Text(
                    "Didn't receive code? Resend",
                    style: TextStyle(color: Color(0xFF3F7892)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupScreen() {
    final bool isWeb = MediaQuery
        .of(context)
        .size
        .width > 600;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Tabs
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

        // SizedBox(height: 10),

        // Text(
        //   'Create Account',
        //   style: TextStyle(
        //     fontSize: isWeb ? 32 : 28,
        //     fontWeight: FontWeight.w700,
        //     color: AppColors.textDark,
        //   ),
        // ),
        // SizedBox(height: 8),
        // Text(
        //   'Join our community today',
        //   style: TextStyle(
        //     fontSize: isWeb ? 16 : 14,
        //     color: AppColors.textGray,
        //     fontWeight: FontWeight.w400,
        //   ),
        // ),
        // SizedBox(height: 30),

        // Signup Form
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 25,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(isWeb ? 35 : 25),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Full Name
                _buildTextField(
                  label: 'Full Name',
                  hintText: 'Enter your full name',
                  icon: Icons.person_outline,
                  isWeb: isWeb,
                  onChanged: (val) => fullName = val,
                  validator: (val) => val!.trim().isEmpty ? 'Required' : null,
                ),
                SizedBox(height: isWeb ? 20 : 16),

                // Email
                _buildTextField(
                  label: 'Email Address',
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

                // Password
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isWeb ? 16 : 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        hintStyle: TextStyle(color: AppColors.textGray),
                        filled: true,
                        fillColor: AppColors.backgroundColor.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary,
                              width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isWeb ? 16 : 14,
                        ),
                        prefixIcon: Icon(
                            Icons.lock_outline, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPassword ? Icons.visibility_off : Icons
                                .visibility,
                            color: AppColors.primary,
                          ),
                          onPressed: () =>
                              setState(() => showPassword = !showPassword),
                        ),
                      ),
                      obscureText: !showPassword,
                      onChanged: (val) => password = val,
                      validator: (val) =>
                      val!.length < 6
                          ? 'Minimum 6 characters'
                          : null,
                    ),
                  ],
                ),
                SizedBox(height: isWeb ? 20 : 16),

                // Phone
                _buildTextField(
                  label: 'Phone (Optional)',
                  hintText: 'Enter your phone number',
                  icon: Icons.phone,
                  isWeb: isWeb,
                  keyboardType: TextInputType.phone,
                  onChanged: (val) => phone = val,
                  validator: (val) => null, // Optional field
                ),
                SizedBox(height: isWeb ? 20 : 16),

                // Location
                _buildLocationField(),
                SizedBox(height: isWeb ? 20 : 16),

                // Role Dropdown - بدون ألوان بنفسجية
                DropdownButtonFormField<String>(
                  value: role,
                  items: [
                    'Parent',
                    'Admin',
                    'Specialist',
                    'Donor',
                    'Manager',
                    'Institution'
                  ]
                      .map((r) =>
                      DropdownMenuItem(
                        value: r,
                        child: Text(
                          r,
                          style: TextStyle(color: AppColors.textDark),
                        ),
                      )).toList(),
                  onChanged: (val) => setState(() => role = val!),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: AppColors.textDark),
                    prefixIcon: Icon(
                        Icons.work_outline, color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  dropdownColor: Colors.white,
                  style: TextStyle(color: AppColors.textDark),
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                ),

                // Role Specific Fields
                _buildRoleSpecificFields(),
                SizedBox(height: isWeb ? 25 : 20),

                // Sign Up Button
                Container(
                  width: double.infinity,
                  height: isWeb ? 55 : 50,
                  decoration: BoxDecoration(
                    color: Color(0xFF3F7892),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF3F7892).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isLoading ? null : submitSignup,
                    child: isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                        : Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isWeb ? 20 : 16),

                // Login Link
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
                          color: Color(0xFF3F7892),
                          fontSize: isWeb ? 14 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
            hintStyle: TextStyle(color: AppColors.textGray),
            filled: true,
            fillColor: AppColors.backgroundColor.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isWeb ? 16 : 14,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary),
          ),
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}