import 'package:flutter/material.dart';
import '../../services/institution_service.dart';
import '../../models/institution_profile.dart';
import './edit_institution_profile_screen.dart';
import '../../theme/app_colors.dart';

class InstitutionProfileScreen extends StatefulWidget {
  @override
  _InstitutionProfileScreenState createState() => _InstitutionProfileScreenState();
}

class _InstitutionProfileScreenState extends State<InstitutionProfileScreen> {
  late Future<InstitutionProfile> _profileFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    setState(() {
      _profileFuture = _fetchProfile();
    });
  }

  Future<InstitutionProfile> _fetchProfile() async {
    try {
      final response = await InstitutionService.getInstitutionProfile();
      return InstitutionProfile.fromJson(response);
    } catch (e) {
      print('Error in _fetchProfile: $e');
      throw Exception('Failed to load profile: ${e.toString()}');
    }
  }

  void _navigateToEditProfile(InstitutionProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditInstitutionProfileScreen(
          profile: profile,
          onProfileUpdated: () {
            _loadProfile();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<InstitutionProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error.toString());
          }

          if (snapshot.hasData) {
            return _buildProfileScreen(snapshot.data!);
          }

          return _buildEmptyScreen();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _profileFuture.then((profile) {
            _navigateToEditProfile(profile);
          }).catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot edit: $error'),
                backgroundColor: AppColors.error,
              ),
            );
          });
        },
        icon: Icon(Icons.edit_rounded, color: Colors.white),
        label: Text('Edit', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading institution data...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 50,
                color: AppColors.error,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Sorry, an error occurred',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _getErrorMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textGray,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text('Try Again', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
            SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => print('Error details: $error'),
              icon: Icon(Icons.info_outline_rounded, color: AppColors.textLight),
              label: Text('Technical Details', style: TextStyle(color: AppColors.textLight)),
            ),
          ],
        ),
      ),
    );
  }

  String _getErrorMessage(String error) {
    if (error.contains('No authentication token found')) {
      return 'Please login first to access the profile';
    } else if (error.contains('Session expired')) {
      return 'Session expired, please login again';
    } else if (error.contains('Profile not found')) {
      return 'Institution profile not found';
    } else if (error.contains('Failed to load profile')) {
      return 'Failed to load profile, check your internet connection';
    }
    return 'Unexpected error: ${error.length > 100 ? error.substring(0, 100) + '...' : error}';
  }

  Widget _buildProfileScreen(InstitutionProfile profile) {
    return CustomScrollView(
      slivers: [
        // Header with institution image (if exists) or icon
        SliverAppBar(
          expandedHeight: 200,
          backgroundColor: AppColors.primary,
          iconTheme: IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(
                        Icons.business_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      profile.institution.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Institution Profile',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          pinned: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadProfile,
            ),
          ],
        ),

        // Profile content
        SliverList(
          delegate: SliverChildListDelegate([
            SizedBox(height: 20),

            // Basic Information
            _buildSection(
              title: 'Basic Information',
              icon: Icons.info_rounded,
              color: AppColors.primary,
              children: [
                _buildInfoCard(
                  icon: Icons.description_rounded,
                  label: 'Description',
                  value: profile.institution.description ?? 'No description added',
                  color: AppColors.accent1,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.location_on_rounded,
                        label: 'City',
                        value: profile.institution.city ?? 'Not specified',
                        color: AppColors.accent2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.location_city_rounded,
                        label: 'Region',
                        value: profile.institution.region ?? 'Not specified',
                        color: AppColors.accent3,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.map_rounded,
                  label: 'Detailed Address',
                  value: profile.institution.locationAddress ?? 'No address added',
                  color: AppColors.accent4,
                ),
              ],
            ),

            // Contact Information
            _buildSection(
              title: 'Contact Information',
              icon: Icons.contact_mail_rounded,
              color: AppColors.green,
              children: [
                _buildContactCard(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: profile.institution.contactEmail ?? 'No email added',
                  onTap: profile.institution.contactEmail != null
                      ? () {
                    // Can add email app opening
                  }
                      : null,
                ),
                SizedBox(height: 12),
                _buildContactCard(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: profile.institution.contactPhone ?? 'No phone added',
                  onTap: profile.institution.contactPhone != null
                      ? () {
                    // Can add phone call
                  }
                      : null,
                ),
              ],
            ),

            // Services Offered
            _buildSection(
              title: 'Services Offered',
              icon: Icons.medical_services_rounded,
              color: AppColors.blue,
              children: [
                if (profile.institution.servicesOffered.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent1, width: 1),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.institution.servicesOffered
                          .map((service) => Chip(
                        label: Text(
                          service,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.accent1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ))
                          .toList(),
                    ),
                  )
                else
                  _buildEmptyState(
                    icon: Icons.hotel_class,
                    message: 'No services added yet',
                    color: AppColors.textLight,
                  ),
              ],
            ),

            // Supported Conditions
            _buildSection(
              title: 'Supported Conditions',
              icon: Icons.healing_rounded,
              color: AppColors.ment,
              children: [
                if (profile.institution.conditionsSupported.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent2, width: 1),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.institution.conditionsSupported
                          .map((condition) => Chip(
                        label: Text(
                          condition,
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.accent2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ))
                          .toList(),
                    ),
                  )
                else
                  _buildEmptyState(
                    icon: Icons.health_and_safety,
                    message: 'No supported conditions added',
                    color: AppColors.textLight,
                  ),
              ],
            ),

            // Additional Information
            _buildSection(
              title: 'Additional Information',
              icon: Icons.badge_rounded,
              color: AppColors.darkGreen,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.verified_rounded,
                        label: 'License Number',
                        value: profile.institution.licenseNumber ?? 'Not available',
                        color: AppColors.yal,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.calendar_today_rounded,
                        label: 'Established Year',
                        value: profile.institution.establishedYear?.toString() ?? 'Not available',
                        color: AppColors.yalw,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Manager Information
            _buildSection(
              title: 'Manager Information',
              icon: Icons.person_pin_rounded,
              color: AppColors.primaryDark,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.1),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                        ),
                        child: profile.manager.profilePicture != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: Image.network(
                            profile.manager.profilePicture!,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Icon(
                          Icons.person_rounded,
                          size: 35,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.manager.fullName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.email_rounded, size: 16, color: AppColors.textLight),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    profile.manager.email,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textGray,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (profile.manager.phone != null) ...[
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded, size: 16, color: AppColors.textLight),
                                  SizedBox(width: 6),
                                  Text(
                                    profile.manager.phone!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: 8),
                            Text(
                              'Registered: ${_formatDate(profile.manager.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 100), // Space for floating button
          ]),
        ),
      ],
    );
  }

  Widget _buildEmptyScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business, // Changed from business_off_rounded to business
              size: 60,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'No institution profile data found',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textGray,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadProfile,
            child: Text('Refresh Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 20),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textDark.withOpacity(0.7)),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark.withOpacity(0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent1, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: 12),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1.withOpacity(0.5), width: 1), // Changed from dashed to solid with opacity
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years years ago';
    }
  }
}