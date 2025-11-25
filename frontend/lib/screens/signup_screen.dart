// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'package:geocoding/geocoding.dart' as geo;// ← تأكد من هذا الـ import
import 'map_screen.dart';
class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  // بيانات التسجيل
  String fullName = '';
  String email = '';
  String password = '';
  String role = 'Parent';
  String? phone;
  String? profilePicture;

  String? address; // للمParent
  String? occupation; // للمParent
  String? specialization; // للمSpecialist
  int? yearsExperience; // للمSpecialist
  String? institutionId; // للمSpecialist والManager
  String? institutionName; // للمInstitution
  String? institutionDescription; // للمInstitution
  String? location; // للمInstitution
  String? website; // للمInstitution
  String? contactInfo; // للمInstitution

  // ✅ بيانات المؤسسة الجديدة للمدير
  String? institutionContactEmail;
  String? institutionContactPhone;
  String? institutionLicense;
  int? institutionEstablishedYear;

  // بيانات OTP
  String otp = '';
  String? tempToken;
  TextEditingController _locationController = TextEditingController();


  // حالة التحميل والعرض
  bool isLoading = false;
  bool showPassword = false;
  bool showOTPScreen = false;

  Map<String, dynamic>? userLocation;
  bool isGettingLocation = false;

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
        SnackBar(content: Text(location?['message'] ?? 'Could not detect location')),
      );
    }
  }


// دالة لعرض رسالة خطأ الموقع
  void _showLocationErrorDialog(Map<String, dynamic> errorResult) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              prefixIcon: Icon(Icons.home_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => address = val,
          ),
          SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Occupation',
              prefixIcon: Icon(Icons.work_outline, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              prefixIcon: Icon(Icons.medical_services_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => specialization = val,
          ),
          SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Years of Experience',
              prefixIcon: Icon(Icons.timeline_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (val) => yearsExperience = int.tryParse(val),
          ),
          SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Institution ID (Optional)',
              prefixIcon: Icon(Icons.business_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (val) => institutionId = val,
          ),
        ],
      );

    // ✅ تحديث Manager ليدخل بيانات المؤسسة الجديدة
    case 'Manager':
      return Column(
        children: [
          SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Institution Name *',
              prefixIcon: Icon(Icons.business, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => institutionName = val,
            validator: (val) => val!.isEmpty ? 'Required for Manager' : null,
          ),
          SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Institution Contact Email *',
              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.phone,
            onChanged: (val) => institutionContactPhone = val,
            validator: (val) => val!.isEmpty ? 'Required for Manager' : null,
          ),
          SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'License Number (Optional)',
              prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => institutionLicense = val,
          ),
          SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Established Year (Optional)',
              prefixIcon: Icon(Icons.calendar_today_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (val) => institutionEstablishedYear = int.tryParse(val),
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

  // ✅ الحل: استخدام userLocation إذا كان موجود، وإلا موقع افتراضي
  Map<String, dynamic> locationData;

  if (userLocation != null &&
      userLocation!['lat'] != null &&
      userLocation!['lng'] != null) {
    locationData = {
      'lat': userLocation!['lat'],
      'lng': userLocation!['lng'],
      'address': userLocation!['address'] ?? 'Selected Location',
      'city': userLocation!['city'] ?? 'فلسطين',
      'region': userLocation!['region'] ?? 'فلسطين',
    };
    print('✅ Using selected location from map: $locationData');
  } else {
    locationData = {
      'lat': 32.4645,
      'lng': 35.3027,
      'address': 'جنين, فلسطين',
      'city': 'جنين',
      'region': 'شمال الضفة',
    };
    print('⚠️ Using default location (Jenin): $locationData');
  }

  final Map<String, dynamic> data = {
    'full_name': fullName.trim(),
    'email': email.trim(),
    'password': password,
    'role': role,
    'phone': phone,
    'profile_picture': profilePicture,

    // ✅ البيانات الجغرافية - مضمونة الآن
    'location_lat': locationData['lat'],
    'location_lng': locationData['lng'],
    'location_address': locationData['address'],
    'city': locationData['city'],
    'region': locationData['region'],

    // بيانات إضافية حسب الدور
    if (role == 'Parent') ...{
      'address': address ?? locationData['address'],
      'occupation': occupation,
    },
    if (role == 'Specialist') ...{
      'specialization': specialization,
      'years_experience': yearsExperience,
      'institution_id': institutionId,
    },
    // ✅ إضافة بيانات المؤسسة للمدير
    if (role == 'Manager') ...{
      'institution_name': institutionName,
      'institution_contact_email': institutionContactEmail,
      'institution_contact_phone': institutionContactPhone,
      'institution_license': institutionLicense,
      'institution_established_year': institutionEstablishedYear,
      'institution_city': locationData['city'], // استخدام نفس مدينة المستخدم
      'institution_region': locationData['region'], // استخدام نفس منطقة المستخدم
    },
  };

  // 🔍 طباعة تفصيلية قبل الإرسال
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🚀 [SIGNUP] SENDING DATA TO API:');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📍 LOCATION DATA:');
  print('   ├─ location_lat: ${data['location_lat']} (${data['location_lat'].runtimeType})');
  print('   ├─ location_lng: ${data['location_lng']} (${data['location_lng'].runtimeType})');
  print('   ├─ location_address: ${data['location_address']}');
  print('   ├─ city: ${data['city']}');
  print('   └─ region: ${data['region']}');
  
  if (role == 'Manager') {
    print('🏢 INSTITUTION DATA:');
    print('   ├─ institution_name: ${data['institution_name']}');
    print('   ├─ institution_contact_email: ${data['institution_contact_email']}');
    print('   ├─ institution_contact_phone: ${data['institution_contact_phone']}');
    print('   ├─ institution_license: ${data['institution_license']}');
    print('   ├─ institution_established_year: ${data['institution_established_year']}');
    print('   ├─ institution_city: ${data['institution_city']}');
    print('   └─ institution_region: ${data['institution_region']}');
  }
  
  print('👤 USER DATA:');
  print('   ├─ full_name: ${data['full_name']}');
  print('   ├─ email: ${data['email']}');
  print('   └─ role: ${data['role']}');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
          content: Text('✅ تم إرسال رمز التحقق لبريدك الإلكتروني'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      print('✅ [SIGNUP] OTP sent successfully!');
      if (role == 'Manager') {
        print('🏢 Institution data included in request');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${response['message']}'),
          backgroundColor: Colors.red,
        ),
      );
      print('❌ [SIGNUP] Failed: ${response['message']}');
    }
  } catch (e) {
    setState(() => isLoading = false);
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('❌ [SIGNUP] CRITICAL ERROR:');
    print('   Error: $e');
    print('   Type: ${e.runtimeType}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ خطأ في الشبكة. تحقق من اتصالك بالإنترنت'),
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

  // lib/screens/signup_screen.dart - تحديث دالة _buildLocationField
  // تحديث _buildLocationField في Signup Screen
  Widget _buildLocationField() {
    return Column(
      children: [
        SizedBox(height: 16),

        // عنوان الموقع
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Location Address',
            hintText: 'Enter your address or select from map',
            prefixIcon: Icon(Icons.location_on_outlined, color: Color(0xFF7815A0)),
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

        // تعليمات إضافية
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

        // عرض الموقع المحدد
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
                        style: TextStyle(fontSize: 12, color: Colors.green[700]),
                      ),
                      if (userLocation!['lat'] != null)
                        Text(
                          'Lat: ${userLocation!['lat']!.toStringAsFixed(4)}, Lng: ${userLocation!['lng']!.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 10, color: Colors.green[600]),
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

        // زر بديل إذا فشل الحصول على الموقع
        if (userLocation == null) ...[
          SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: getCurrentLocation,
            icon: Icon(Icons.location_searching, size: 16),
            label: Text('Detect My Location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF7815A0),
              side: BorderSide(color: Color(0xFF7815A0)),
            ),
          ),
        ],
      ],
    );
  }

  void _openMapPicker() async {
    try {
      print('🗺️ [SIGNUP] Opening map picker...');

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

      print('🗺️ [SIGNUP] Map picker returned: $result');

      if (result != null && result is Map) {
        print('✅ [SIGNUP] Received valid data from map: $result');

        setState(() {
          userLocation = {
            'lat': result['lat'],
            'lng': result['lng'],
            'address': result['address'],
            'city': result['city'] ?? _extractCityFromAddress(result['address']),
            'region': result['region'] ?? _extractRegionFromAddress(result['address']),
          };
          _locationController.text = userLocation!['address'];
        });

        print('✅ [SIGNUP] userLocation updated: $userLocation');
      } else {
        print('❌ [SIGNUP] Map returned NULL or invalid data');
      }
    } catch (e) {
      print('❌ [SIGNUP] Error in map picker: $e');
    }
  }


  String _extractCityFromAddress(String address) {
    if (address.contains('جنين')) return 'جنين';
    if (address.contains('رام الله')) return 'رام الله';
    if (address.contains('غزة')) return 'غزة';
    if (address.contains('الخليل')) return 'الخليل';
    if (address.contains('نابلس')) return 'نابلس';
    if (address.contains('بيت لحم')) return 'بيت لحم';
    return 'فلسطين';
  }

  String _extractRegionFromAddress(String address) {
    if (address.contains('جنين') || address.contains('نابلس')) return 'شمال الضفة';
    if (address.contains('رام الله') || address.contains('بيت لحم')) return 'وسط الضفة';
    if (address.contains('الخليل')) return 'جنوب الضفة';
    if (address.contains('غزة')) return 'قطاع غزة';
    return 'فلسطين';
  }


  Future<String?> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        geo.Placemark placemark = placemarks.first;
        return [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].where((part) => part != null && part.isNotEmpty).join(', ');
      }
    } catch (e) {
      print('❌ Error getting address from coordinates: $e');
    }
    return null;
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

// لا تنسى التخلص من المتحكم عند التدمير
  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0E5FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: showOTPScreen ? _buildOTPScreen() : _buildSignupScreen(),
        ),
      ),
    );
  }

  Widget _buildOTPScreen() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: Color(0xFF7815A0)),
              onPressed: backToSignup,
            ),
            SizedBox(width: 10),
            Text(
              'Verify Email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7815A0),
              ),
            ),
          ],
        ),
        SizedBox(height: 30),

        Image.asset(
          'assets/images/jusoor_logo.png',
          height: 100,
        ),
        SizedBox(height: 30),

        Text(
          'Enter the 6-digit code sent to:',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
        SizedBox(height: 8),
        Text(
          email,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7815A0)),
        ),
        SizedBox(height: 30),

        Form(
          key: _otpFormKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'OTP Code',
                  hintText: 'Enter 6-digit code',
                  prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF7815A0)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (val) => otp = val,
                validator: (val) => val!.length != 6 ? 'Enter 6-digit code' : null,
              ),
              SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Color(0xFF7815A0),
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
                      : Text('Verify & Complete Signup', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('OTP resent to your email')),
                  );
                },
                child: Text(
                  "Didn't receive code? Resend",
                  style: TextStyle(color: Color(0xFF7815A0)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignupScreen() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text(
                  'Log in',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              SizedBox(width: 20),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Sign up',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF7815A0),
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 30),

          Image.asset(
            'assets/images/jusoor_logo.png',
            height: 100,
          ),
          SizedBox(height: 30),

          TextFormField(
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => fullName = val,
            validator: (val) => val!.trim().isEmpty ? 'Required' : null,
          ),
          SizedBox(height: 16),

          TextFormField(
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: (val) => email = val,
            validator: (val) {
              if (val!.isEmpty) return 'Required';
              final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
              if (!emailRegex.hasMatch(val)) return 'Enter valid email';
              return null;
            },
          ),
          SizedBox(height: 16),

          TextFormField(
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF7815A0)),
              suffixIcon: IconButton(
                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => showPassword = !showPassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            obscureText: !showPassword,
            onChanged: (val) => password = val,
            validator: (val) => val!.length < 6 ? 'Min 6 characters' : null,
          ),
          SizedBox(height: 16),

          TextFormField(
            decoration: InputDecoration(
              labelText: 'Phone (Optional)',
              prefixIcon: Icon(Icons.phone, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.phone,
            onChanged: (val) => phone = val,
          ),
          SizedBox(height: 16),

          _buildLocationField(),
          SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: role,
            items: ['Parent','Admin','Specialist','Donor','Manager','Institution']
                .map((r) => DropdownMenuItem(
              value: r,
              child: Text(r),
            )).toList(),
            onChanged: (val) => setState(() => role = val!),
            decoration: InputDecoration(
              labelText: 'Role',
              prefixIcon: Icon(Icons.work_outline, color: Color(0xFF7815A0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          _buildRoleSpecificFields(),
          SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Color(0xFF7815A0),
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
                  : Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
          SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Already have an account? ", style: TextStyle(color: Colors.grey[800])),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text('Login', style: TextStyle(color: Color(0xFF7815A0))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}