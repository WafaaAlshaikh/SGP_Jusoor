import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/screens/donations_success.dart';
import 'package:frontend/screens/equipment_donation_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'stripe_checkout_screen.dart';
import 'donation_campaign_details_screen.dart';
import 'stripe_payment_screen.dart';

class DonationScreen extends StatefulWidget {
  final int? institutionId;
  final String? institutionName;

  const DonationScreen({
    super.key,
    this.institutionId,
    this.institutionName,
  });

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _institutions = [];
  bool _isLoadingAI = false;
  String? _aiSummary;
  List<Map<String, dynamic>> _aiRecommendations = [];
  bool _isLoadingImpact = false;
  String? _impactError;
  Map<String, dynamic>? _impactV2;
  List<Map<String, dynamic>> _impactFeedItems = [];
  int _impactFeedPage = 1;
  bool _impactFeedHasMore = false;
  String _authToken = '';
  String _donationMode = 'one_time';
  List<Map<String, dynamic>> _campaignsForSelectedInstitution = [];
  int? _selectedCampaignId;
  bool _didAutoOpenForInstitution = false;
  Map<String, dynamic>? _currentInstitution;

  bool _isAnonymous = false;
  final TextEditingController _donorNameController = TextEditingController();
  final TextEditingController _donorEmailController = TextEditingController();

  final TextEditingController _inviteCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ?? '').trim();
      _authToken = token;

      final institutions = await ApiService.getDonationInstitutions(token);

      if (token.isNotEmpty) {
        _loadDonorAIRecommendations(token);
        _loadImpact(token);
      }

      final filtered = widget.institutionId == null
          ? institutions
          : institutions
              .where((i) => i['institution_id'] == widget.institutionId)
              .toList();

      setState(() {
        _institutions = filtered;
        _isLoading = false;
      });

      if (widget.institutionId != null && !_didAutoOpenForInstitution) {
        _didAutoOpenForInstitution = true;
        if (!mounted) return;

        if (_institutions.isNotEmpty) {
          Future.microtask(() {
            if (!mounted) return;
            _showDonateDialog(_institutions.first);
          });
        } else {
          setState(() {
            _errorMessage = 'Institution is not available for donations.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load institutions: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadImpact(String token) async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingImpact = true;
        _impactError = null;
      });

      final v2 = await ApiService.getDonationImpactV2(token);
      final feed = await ApiService.getDonorImpactFeed(token, page: 1, limit: 10);

      if (!mounted) return;

      final v2Data = (v2['data'] is Map) ? Map<String, dynamic>.from(v2['data'] as Map) : <String, dynamic>{};
      final feedData = (feed['data'] is Map) ? Map<String, dynamic>.from(feed['data'] as Map) : <String, dynamic>{};
      final items = (feedData['items'] is List)
          ? (feedData['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      final pagination = (feedData['pagination'] is Map) ? Map<String, dynamic>.from(feedData['pagination'] as Map) : <String, dynamic>{};
      final totalPages = (pagination['totalPages'] is int)
          ? pagination['totalPages'] as int
          : int.tryParse('${pagination['totalPages'] ?? ''}') ?? 1;
      final page = (pagination['page'] is int) ? pagination['page'] as int : int.tryParse('${pagination['page'] ?? ''}') ?? 1;

      setState(() {
        _impactV2 = v2Data;
        _impactFeedItems = items;
        _impactFeedPage = page;
        _impactFeedHasMore = page < totalPages;
        _isLoadingImpact = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _impactV2 = null;
        _impactFeedItems = [];
        _impactFeedPage = 1;
        _impactFeedHasMore = false;
        _impactError = 'Failed to load impact';
        _isLoadingImpact = false;
      });
    }
  }

  Future<void> _loadDonorAIRecommendations(String token) async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingAI = true;
      });

      final result = await ApiService.getDonorAIRecommendations(token, limit: 6);

      if (!mounted) return;
      if (result['success'] == true) {
        final recs = (result['recommendations'] as List?) ?? [];
        setState(() {
          _aiSummary = result['ai_summary']?.toString();
          _aiRecommendations = recs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoadingAI = false;
        });
      } else {
        setState(() {
          _aiRecommendations = [];
          _aiSummary = null;
          _isLoadingAI = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiRecommendations = [];
        _aiSummary = null;
        _isLoadingAI = false;
      });
    }
  }

  Map<String, dynamic>? _findInstitutionById(int institutionId) {
    try {
      return _institutions.firstWhere(
        (x) => x['institution_id'] == institutionId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCampaignsForInstitution(int institutionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final campaigns = await ApiService.getInstitutionCampaignsForDonations(
        token,
        institutionId,
      );

      if (!mounted) return;
      setState(() {
        _campaignsForSelectedInstitution = campaigns;
      });
    } catch (e) {
      print('Error loading campaigns: $e');
      setState(() {
        _campaignsForSelectedInstitution = [];
      });
    }
  }

  void _openCampaignSelectorInDialog(void Function(void Function()) setStateDialog) {
    if (_campaignsForSelectedInstitution.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No campaigns available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select a Campaign',
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
                const SizedBox(height: 8),
                const Text(
                  'Choose a campaign to support:',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _campaignsForSelectedInstitution.isEmpty
                      ? const Center(
                          child: Text('No campaigns available'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _campaignsForSelectedInstitution.length,
                          itemBuilder: (context, index) {
                            final campaign = _campaignsForSelectedInstitution[index];
                            final int id = campaign['campaign_id'] as int;
                            final bool isSelected = _selectedCampaignId == id;
                            final double target = double.tryParse('${campaign['target_amount'] ?? 0}') ?? 0;
                            final String status = campaign['status']?.toString() ?? 'active';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                title: Text(
                                  campaign['name']?.toString() ?? 'Campaign',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppColors.primary : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((campaign['description']?.toString() ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          campaign['description']?.toString() ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (target > 0)
                                          Text(
                                            'Target: ${target.toStringAsFixed(0)} JOD',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'active'
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'active' ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Campaign details',
                                      icon: const Icon(Icons.info_outline),
                                      onPressed: () {
                                        final inst = _currentInstitution != null
                                            ? Map<String, dynamic>.from(_currentInstitution as Map)
                                            : <String, dynamic>{};
                                        final camp = Map<String, dynamic>.from(campaign);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DonationCampaignDetailsScreen(
                                              institution: inst,
                                              campaign: camp,
                                              onDonate: () {
                                                setStateDialog(() {
                                                  _donationMode = 'campaign';
                                                  _selectedCampaignId = id;
                                                });
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  setStateDialog(() {
                                    _selectedCampaignId = id;
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDonateDialog(Map<String, dynamic> institution) async {
    final TextEditingController amountController = TextEditingController();
    _currentInstitution = institution;

    // Load campaigns for this institution
    await _loadCampaignsForInstitution(institution['institution_id'] as int);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.volunteer_activism,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Donate to ${institution['name'] ?? ''}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _inviteCodeController,
                                decoration: InputDecoration(
                                  labelText: 'Invite Code (optional)',
                                  hintText: 'Enter invite code to support the same campaign',
                                  prefixIcon: const Icon(Icons.link),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Amount Input
                              TextField(
                                controller: amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Amount (JOD)',
                                  hintText: 'Enter donation amount',
                                  prefixIcon: const Icon(Icons.attach_money),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Donation Type
                              const Text(
                                'Donation Type',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: [
                                  RadioListTile<String>(
                                    value: 'one_time',
                                    groupValue: _donationMode,
                                    title: const Text('One-time Donation'),
                                    subtitle: const Text('Single donation to general fund'),
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setStateDialog(() {
                                        _donationMode = val;
                                        _selectedCampaignId = null;
                                      });
                                    },
                                  ),
                                  RadioListTile<String>(
                                    value: 'monthly',
                                    groupValue: _donationMode,
                                    title: const Text('Monthly Donation'),
                                    subtitle: const Text('Recurring monthly donation'),
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setStateDialog(() {
                                        _donationMode = val;
                                        _selectedCampaignId = null;
                                      });
                                    },
                                  ),
                                  RadioListTile<String>(
                                    value: 'campaign',
                                    groupValue: _donationMode,
                                    title: const Text('Campaign Donation'),
                                    subtitle: const Text('Support specific campaign'),
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setStateDialog(() {
                                        _donationMode = val;
                                      });
                                    },
                                  ),
                                ],
                              ),

                              // Campaign Selection (if mode is campaign)
                              if (_donationMode == 'campaign') ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Select Campaign',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                if (_campaignsForSelectedInstitution.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'No active campaigns available for this institution. Please choose another donation type.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (_selectedCampaignId != null)
                                              ..._campaignsForSelectedInstitution
                                                  .where((c) => c['campaign_id'] == _selectedCampaignId)
                                                  .map((campaign) => Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            campaign['name']?.toString() ?? '',
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          if ((campaign['description']?.toString() ?? '').isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 4),
                                                              child: Text(
                                                                campaign['description']?.toString() ?? '',
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.grey,
                                                                ),
                                                              ),
                                                            ),
                                                          const SizedBox(height: 8),
                                                          Align(
                                                            alignment: Alignment.centerLeft,
                                                            child: TextButton.icon(
                                                              onPressed: () {
                                                                final inst = _currentInstitution != null
                                                                    ? Map<String, dynamic>.from(_currentInstitution as Map)
                                                                    : <String, dynamic>{};
                                                                final camp = Map<String, dynamic>.from(campaign);
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) => DonationCampaignDetailsScreen(
                                                                      institution: inst,
                                                                      campaign: camp,
                                                                      onDonate: () {
                                                                        setStateDialog(() {
                                                                          _donationMode = 'campaign';
                                                                          _selectedCampaignId = (campaign['campaign_id'] is int)
                                                                              ? campaign['campaign_id'] as int
                                                                              : int.tryParse('${campaign['campaign_id'] ?? ''}');
                                                                        });
                                                                        Navigator.pop(context);
                                                                      },
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              icon: const Icon(Icons.info_outline, size: 18),
                                                              label: const Text('Campaign details'),
                                                              style: TextButton.styleFrom(
                                                                foregroundColor: AppColors.primary,
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ))
                                                  .toList()
                                            else
                                              const Text(
                                                'No campaign selected',
                                                style: TextStyle(color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
  child: OutlinedButton.icon(
    onPressed: () => _openCampaignSelectorInDialog(setStateDialog),
    icon: const Icon(Icons.search),
    label: const Text('Browse Campaigns'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.primary),
    ),
  ),
),
                                          if (_selectedCampaignId != null)
                                            IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                setStateDialog(() {
                                                  _selectedCampaignId = null;
                                                });
                                              },
                                              tooltip: 'Clear selection',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                              ],

                              // Quick Amount Buttons
                              const SizedBox(height: 20),
                              const Text(
                                'Quick Amounts (JOD)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [10, 25, 50, 100, 250, 500].map((amount) {
                                  return ElevatedButton(
                                    onPressed: () {
                                      amountController.text = amount.toString();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[200],
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: Text('$amount'),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // Anonymous Donor Option
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Donor Information',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Anonymous Toggle
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Donate Anonymously'),
                                    subtitle: const Text('Your name will not be displayed publicly'),
                                    value: _isAnonymous,
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        _isAnonymous = value;
                                        if (value) {
                                          // إذا اختار التبرع المجهول، نمسح الحقول
                                          _donorNameController.clear();
                                          _donorEmailController.clear();
                                        }
                                      });
                                    },
                                  ),

                                  // Donor Information Fields (تظهر فقط إذا لم يكن مجهولاً)
                                  if (!_isAnonymous) ...[
                                    const SizedBox(height: 16),

                                    // Donor Name
                                    TextField(
                                      controller: _donorNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Your Name (Optional)',
                                        hintText: 'Enter your name',
                                        prefixIcon: const Icon(Icons.person),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Donor Email
                                    TextField(
                                      controller: _donorEmailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'Your Email (Optional)',
                                        hintText: 'Enter your email for receipt',
                                        prefixIcon: const Icon(Icons.email),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 8),
                                    Text(
                                      'Your information will be kept private and only used for receipt purposes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],

                                  // Note for Anonymous Donors
                                  if (_isAnonymous) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info, color: Colors.blue[700]),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Thank you for your anonymous donation! '
                                              'Your contribution will be recorded without personal details.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Actions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final amount = amountController.text.trim();
                                  if (amount.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter donation amount'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  if (_donationMode == 'campaign' && _selectedCampaignId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please select a campaign'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.of(context).pop(true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Continue to Payment'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true) return;

    final raw = amountController.text.trim();
    final amount = double.tryParse(raw.replaceAll(',', '.'));

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid donation amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _startDonationCheckout(institution, amount);
  }

  Future<void> _startDonationCheckout(
  Map<String, dynamic> institution,
  double amount,
) async {
  try {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text('Preparing payment...'),
            const SizedBox(height: 8),
            Text(
              '${amount.toStringAsFixed(2)} JOD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );

    // ✅ الحصول على token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    // ✅ تحديد المنصة (Mobile أو Web)
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    print('🔍 Starting donation checkout:');
    print('   Platform: ${isMobile ? "Mobile 📱" : "Web 💻"}');
    print('   Amount: $amount JOD');
    print('   Mode: $_donationMode');
    print('   Anonymous: $_isAnonymous');
    print('   Token: ${token.isNotEmpty ? "✅" : "❌"}');

    // ==================== للـ MOBILE: استخدام Payment Intent ====================
    if (isMobile) {
      print('📱 Using Mobile Payment Flow (Stripe SDK)');

      Navigator.pop(context); // Remove loading dialog

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => StripePaymentScreen(
            institutionId: institution['institution_id'] as int,
            institutionName: institution['name'] ?? 'Institution',
            amount: amount,
            campaignId: _selectedCampaignId,
            donationMode: _donationMode,
            isAnonymous: _isAnonymous,
            donorName: _donorNameController.text.isEmpty 
                ? null 
                : _donorNameController.text,
            donorEmail: _donorEmailController.text.isEmpty 
                ? null 
                : _donorEmailController.text,
            inviteCode: _inviteCodeController.text.isEmpty 
                ? null 
                : _inviteCodeController.text,
          ),
        ),
      );

      // ✅ معالجة النتيجة المحسّنة
      if (result != null && result['success'] == true && mounted) {
        print('✅ Mobile payment completed successfully');
        print('   Result: $result');
        
        // ✅ تحويل donation_id
        final donationId = result['donation_id'];
        int? donationIdInt;
        
        if (donationId is int) {
          donationIdInt = donationId;
        } else if (donationId is String) {
          donationIdInt = int.tryParse(donationId);
        }
        
        print('   Donation ID (converted): $donationIdInt');
        
        // ✅ الانتقال لصفحة النجاح
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DonationSuccessScreen(
              donationId: donationIdInt,  // ✅ donation_id
              sessionId: null,             // ✅ null للـ Mobile
              institutionId: institution['institution_id'] as int,
              isAnonymous: _isAnonymous,
              amount: amount,
            ),
          ),
        );
      } else if (result != null && result['cancelled'] == true) {
        print('⚠️ Payment cancelled by user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment cancelled'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

      return;
    }

    // ==================== للـ WEB: استخدام Checkout Session ====================
    print('💻 Using Web Payment Flow (Checkout Session)');

    // إعداد البيانات
    Map<String, dynamic> requestBody = {
      'institution_id': institution['institution_id'],
      'amount': amount,
      'mode': _donationMode == 'monthly' ? 'monthly' : 'one_time',
      'currency': 'jod',
      'anonymous': _isAnonymous,
      'platform': 'web', // ✅ مهم للـ Backend
    };

    // إضافة campaign_id إذا كان موجوداً
    if (_selectedCampaignId != null) {
      requestBody['campaign_id'] = _selectedCampaignId;
    }

    // إضافة invite_code إذا كان موجوداً
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isNotEmpty) {
      requestBody['invite_code'] = inviteCode;
    }

    // ✅ إضافة بيانات المتبرع إذا كانت متوفرة
    if (_donorNameController.text.isNotEmpty) {
      requestBody['donor_name'] = _donorNameController.text.trim();
    }
    if (_donorEmailController.text.isNotEmpty) {
      requestBody['donor_email'] = _donorEmailController.text.trim();
    }

    Map<String, dynamic> result;

    // ✅ اختيار API بناءً على حالة المصادقة
    if (token.isEmpty) {
      // ⭐ مستخدم غير مسجل - استخدام API المرن
      print('🟡 Using flexible checkout (unauthenticated)');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/donations/flexible/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        result = jsonDecode(response.body);
        
        if (result['success'] != true) {
          throw Exception(result['message'] ?? 'Failed to create checkout');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create checkout');
      }
    } else {
      // ✅ مستخدم مسجل - استخدام API مع المصادقة
      print('🟢 Using authenticated checkout');

      result = await ApiService.createDonationCheckout(
        token,
        institutionId: institution['institution_id'] as int,
        amount: amount,
        mode: _donationMode == 'monthly' ? 'monthly' : 'one_time',
        campaignId: _selectedCampaignId,
        inviteCode: inviteCode.isEmpty ? null : inviteCode,
        anonymous: _isAnonymous,
        donorName: _donorNameController.text.isEmpty 
            ? null 
            : _donorNameController.text.trim(),
        donorEmail: _donorEmailController.text.isEmpty 
            ? null 
            : _donorEmailController.text.trim(),
      );
    }

    // إزالة شاشة التحميل
    if (mounted) {
      Navigator.pop(context);
    }

    // ✅ التحقق من النتيجة
    print('📦 Checkout result: $result');

    final url = (result['url'] ?? result['checkout_url'])?.toString();
    final sessionId = (result['sessionId'] ?? result['session_id'])?.toString();

    if (url == null || url.isEmpty) {
      throw Exception('No checkout URL received from server');
    }

    print('🔗 Checkout URL: $url');

    // ✅ فتح WebView للـ Web
    final paymentCompleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StripeCheckoutScreen(
          checkoutUrl: url,
          sessionId: sessionId,
          institutionId: institution['institution_id'] as int,
          institutionName: institution['name'] ?? 'Institution',
          amount: amount,
        ),
      ),
    );

    // معالجة النتيجة
    if (paymentCompleted == true && mounted) {
      print('✅ Payment completed successfully');
      
      // الانتقال لصفحة النجاح
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DonationSuccessScreen(
            sessionId: sessionId,
            institutionId: institution['institution_id'] as int,
            isAnonymous: _isAnonymous,
          ),
        ),
      );
    } else if (paymentCompleted == false && mounted) {
      print('⚠️ Payment not completed');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Payment was not completed. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

  } on TimeoutException {
    print('❌ Timeout error');
    
    if (mounted) {
      Navigator.pop(context); // Remove loading
      
      _showErrorDialog(
        'Connection Timeout',
        'The request took too long. Please check your internet connection and try again.',
        showRetry: true,
        onRetry: () => _startDonationCheckout(institution, amount),
      );
    }
  } on SocketException {
    print('❌ Network error');
    
    if (mounted) {
      Navigator.pop(context); // Remove loading
      
      _showErrorDialog(
        'No Internet Connection',
        'Please check your internet connection and try again.',
        showRetry: true,
        onRetry: () => _startDonationCheckout(institution, amount),
      );
    }
  } catch (e) {
    print('❌ Payment error: $e');

    if (mounted) {
      // إزالة شاشة التحميل إذا كانت موجودة
      try {
        Navigator.pop(context);
      } catch (_) {}

      // تحديد نوع الخطأ
      String title = 'Payment Failed';
      String message = 'Failed to process payment. Please try again.';
      bool showAnonymousOption = false;

      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        title = 'Authentication Required';
        message = 'You need to be logged in to complete this donation. '
                 'Alternatively, you can donate anonymously.';
        showAnonymousOption = true;
      } else if (e.toString().contains('Network') || e.toString().contains('Connection')) {
        title = 'Network Error';
        message = 'Please check your internet connection and try again.';
      } else if (e.toString().contains('timeout')) {
        title = 'Request Timeout';
        message = 'The request took too long. Please try again.';
      } else if (e.toString().contains('Invalid')) {
        title = 'Invalid Data';
        message = e.toString().replaceAll('Exception:', '').trim();
      }

      _showErrorDialog(
        title,
        message,
        showRetry: true,
        showAnonymousOption: showAnonymousOption,
        onRetry: () => _startDonationCheckout(institution, amount),
        onAnonymous: showAnonymousOption
            ? () {
                setState(() {
                  _isAnonymous = true;
                });
                _startDonationCheckout(institution, amount);
              }
            : null,
      );
    }
  }
}

// ==================== دالة مساعدة لعرض رسائل الخطأ ====================
void _showErrorDialog(
  String title,
  String message, {
  bool showRetry = false,
  bool showAnonymousOption = false,
  VoidCallback? onRetry,
  VoidCallback? onAnonymous,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (showAnonymousOption) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can donate without creating an account',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        // Cancel button
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            side: BorderSide(color: Colors.grey[300]!),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
        
        // Anonymous donation button (if applicable)
        if (showAnonymousOption && onAnonymous != null)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onAnonymous();
            },
            icon: const Icon(Icons.volunteer_activism, size: 18),
            label: const Text('Donate Anonymously'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        
        // Retry button (if applicable)
        if (showRetry && onRetry != null && !showAnonymousOption)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    ),
  );
}

  /// Open Stripe checkout URL
  static Future<void> launchStripeCheckout(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } else {
      throw Exception('Could not launch Stripe checkout');
    }
  }

  /// Copy URL to clipboard
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     widget.institutionId != null &&
      //             (widget.institutionName ?? '').trim().isNotEmpty
      //         ? 'Donate to ${widget.institutionName}'
      //         : 'Support Institutions',
      //   ),
      //   backgroundColor: AppColors.primary,
      //   foregroundColor: Colors.white,
      //   actions: [
      //     if (_institutions.isNotEmpty)
      //       IconButton(
      //         icon: const Icon(Icons.info_outline),
      //         onPressed: () {
      //           showDialog(
      //             context: context,
      //             builder: (context) => AlertDialog(
      //               title: const Text('About Donations'),
      //               content: const Text(
      //                 'Your donations help support children\'s therapy sessions. '
      //                 'You can donate to specific campaigns or to the general fund. '
      //                 'All donations are processed securely through Stripe.',
      //               ),
      //               actions: [
      //                 TextButton(
      //                   onPressed: () => Navigator.pop(context),
      //                   child: const Text('OK'),
      //                 ),
      //               ],
      //             ),
      //           );
      //         },
      //       ),
      //   ],
      // ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading institutions...'),
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
                          onPressed: _loadInstitutions,
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
              : _institutions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.volunteer_activism,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No institutions available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check back later for donation opportunities',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadInstitutions,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_isLoadingAI)
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: AppColors.primary.withOpacity(0.06),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(child: Text('Loading AI suggestions...')),
                                ],
                              ),
                            )
                          else if (_aiRecommendations.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: AppColors.primary.withOpacity(0.06),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AI Suggestions for You',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  if ((_aiSummary ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _aiSummary!,
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 120,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _aiRecommendations.length,
                                      itemBuilder: (context, index) {
                                        final r = _aiRecommendations[index];
                                        final id = r['institution_id'];
                                        final name = (r['name'] ?? '').toString();
                                        final reasons = (r['reasons'] is List)
                                            ? (r['reasons'] as List).map((x) => x.toString()).toList()
                                            : <String>[];

                                        return Container(
                                          width: 260,
                                          margin: EdgeInsets.only(right: index == _aiRecommendations.length - 1 ? 0 : 12),
                                          child: Card(
                                            elevation: 1,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: id is int
                                                  ? () {
                                                      final inst = _findInstitutionById(id);
                                                      if (inst != null) {
                                                        _showDonateDialog(inst);
                                                      }
                                                    }
                                                  : null,
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name.isEmpty ? 'Institution' : name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      reasons.isNotEmpty ? reasons.first : 'Suggested for you',
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.grey),
                                                    ),
                                                    const Spacer(),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.volunteer_activism, size: 16, color: AppColors.primary),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Donate',
                                                          style: TextStyle(
                                                            color: AppColors.primary,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        )
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Institutions List
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _institutions.length,
                            itemBuilder: (context, index) {
                              final inst = _institutions[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.account_balance,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  inst['name'] ?? 'Institution',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                if (inst['city'] != null)
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        inst['city'] ?? '',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _showCampaignsForInstitution(inst),
                                              icon: const Icon(Icons.campaign),
                                              label: const Text('View Campaigns'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.primary,
                                                side: BorderSide(color: AppColors.primary),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _showDonateDialog(inst),
                                              icon: const Icon(Icons.volunteer_activism),
                                              label: const Text('Donate Now'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 80), // Add padding for FAB
                        ],
                      ),
                    ),
      floatingActionButton: _institutions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                if (_institutions.length == 1) {
                  _showDonateDialog(_institutions.first);
                } else {
                  // Show institution selector
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Select Institution'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _institutions.length,
                          itemBuilder: (context, index) {
                            final inst = _institutions[index];
                            return ListTile(
                              title: Text(inst['name'] ?? ''),
                              subtitle: Text(inst['city'] ?? ''),
                              onTap: () {
                                Navigator.pop(context);
                                _showDonateDialog(inst);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.favorite),
              label: const Text('Quick Donate'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Future<void> _showCampaignsForInstitution(Map<String, dynamic> institution) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading campaigns...'),
            ],
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final campaigns = await ApiService.getInstitutionCampaignsForDonations(
        token,
        institution['institution_id'] as int,
      );

      if (!mounted) return;
      Navigator.pop(context); // Remove loading

      if (campaigns.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Campaigns'),
            content: const Text(
              'This institution doesn\'t have any active campaigns at the moment. '
              'You can still donate to their general fund.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Campaigns - ${institution['name']}',
                      style: const TextStyle(
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
                const SizedBox(height: 8),
                Text(
                  '${campaigns.length} active campaign${campaigns.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: campaigns.length,
                    itemBuilder: (context, index) {
                      final campaign = campaigns[index];
                      final double target = 
                          double.tryParse('${campaign['target_amount'] ?? 0}') ?? 0;
                      final String status = campaign['status']?.toString() ?? 'active';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            campaign['name']?.toString() ?? 'Campaign',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((campaign['description']?.toString() ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                                  child: Text(
                                    campaign['description']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              Row(
                                children: [
                                  if (target > 0)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Target',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '${target.toStringAsFixed(0)} JOD',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Status',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'active' 
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'active' 
                                                  ? Colors.green
                                                  : Colors.orange,
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
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Close campaign list
                              _donationMode = 'campaign';
                              _selectedCampaignId = campaign['campaign_id'] as int;
                              _showDonateDialog(institution);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Donate'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error loading campaigns: $e');
      if (context.mounted) {
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load campaigns: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}