import 'package:flutter/material.dart';
import 'package:frontend/models/institution_profile.dart';
import 'package:frontend/screens/manager/edit_institution_profile_screen.dart';
import 'package:frontend/screens/manager/session_types_screen.dart';
import 'package:frontend/services/institution_service.dart';
import 'package:frontend/services/manager_session_type_service.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManagerOnboardingScreen extends StatefulWidget {
  const ManagerOnboardingScreen({super.key});

  @override
  State<ManagerOnboardingScreen> createState() => _ManagerOnboardingScreenState();
}

class _ManagerOnboardingScreenState extends State<ManagerOnboardingScreen> {
  bool _isLoading = true;
  String? _error;

  InstitutionProfile? _profile;
  int _sessionTypesCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profileResp = await InstitutionService.getInstitutionProfile();
      final profile = InstitutionProfile.fromJson(profileResp);

      int sessionTypesCount = 0;
      try {
        final allResp = await ManagerSessionTypeService.getAllSessionTypes();
        final data = (allResp['data'] as Map?)?.cast<String, dynamic>() ?? {};
        final list = (data['sessionTypes'] as List?) ?? (data['session_types'] as List?) ?? const [];
        sessionTypesCount = list.length;
      } catch (_) {
        sessionTypesCount = 0;
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _sessionTypesCount = sessionTypesCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  bool get _needsProfileBasics {
    final p = _profile;
    if (p == null) return true;

    final inst = p.institution;
    final hasLocation = (inst.locationAddress ?? '').trim().isNotEmpty ||
        ((inst.city ?? '').trim().isNotEmpty && (inst.region ?? '').trim().isNotEmpty);

    final hasDescription = (inst.description ?? '').trim().isNotEmpty;
    return !(hasLocation && hasDescription);
  }

  bool get _needsServices {
    final p = _profile;
    if (p == null) return true;

    final inst = p.institution;
    return inst.servicesOffered.isEmpty;
  }

  bool get _needsProfilePicture {
    final p = _profile;
    if (p == null) return true;

    return (p.manager.profilePicture ?? '').trim().isEmpty;
  }

  bool get _needsSessionTypes {
    return _sessionTypesCount <= 0;
  }

  bool get _needsOnboarding {
    return _needsProfileBasics || _needsServices || _needsProfilePicture || _needsSessionTypes;
  }

  Future<void> _maybeLater() async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch;
    await prefs.setInt('skip_onboarding_until', until);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/managerDashboard');
  }

  Future<void> _openEditProfile() async {
    final p = _profile;
    if (p == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditInstitutionProfileScreen(
          profile: p,
          onProfileUpdated: _load,
        ),
      ),
    );

    await _load();
  }

  Future<void> _openSessionTypes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionTypesScreen()),
    );

    await _load();
  }

  Widget _buildChecklistItem({required String title, required bool done}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent1, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: done ? AppColors.success : AppColors.textLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Welcome'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load institution profile',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome ${_profile?.manager.fullName ?? ''}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To start receiving bookings and show your institution professionally, please complete the following.',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                      const SizedBox(height: 18),

                      _buildChecklistItem(
                        title: 'Basic institution info (description + location)',
                        done: !_needsProfileBasics,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistItem(
                        title: 'Services offered',
                        done: !_needsServices,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistItem(
                        title: 'Profile picture',
                        done: !_needsProfilePicture,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistItem(
                        title: 'Session types',
                        done: !_needsSessionTypes,
                      ),
                      const Spacer(),

                      if (_needsOnboarding) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openEditProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('Complete Institution Profile'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openSessionTypes,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.category_rounded),
                            label: const Text('Manage Session Types'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _maybeLater,
                            child: const Text('Maybe later'),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/managerDashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Go to Dashboard'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
