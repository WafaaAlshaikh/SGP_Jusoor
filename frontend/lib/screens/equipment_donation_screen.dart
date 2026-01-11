import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import '../theme/app_colors.dart';
import '../screens/donation_screen.dart';
import '../services/api_service.dart';

class CombinedEquipmentScreen extends StatefulWidget {
  final int? institutionId;
  final String? institutionName;
  final String? equipmentName;
  final int? categoryId;

  const CombinedEquipmentScreen({
    super.key,
    this.institutionId,
    this.institutionName,
    this.equipmentName,
    this.categoryId,
  });

  @override
  State<CombinedEquipmentScreen> createState() => _CombinedEquipmentScreenState();
}

class _CombinedEquipmentScreenState extends State<CombinedEquipmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingCampaigns = true;
  String? _error;
  List<Map<String, dynamic>> _campaigns = [];
  bool _isLoadingAI = false;
  String? _aiSummary;
  List<Map<String, dynamic>> _aiRecommendations = [];

  // Form variables
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _institutions = [];
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  // Form controllers
  final TextEditingController _institutionController = TextEditingController();
  final TextEditingController _equipmentNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Form values
  int? _selectedInstitutionId;
  String _selectedCondition = 'used_good';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load data for both tabs
    _loadCampaigns();
    _loadDonorAIRecommendations();
    _loadInitialData();

    // Pre-fill if coming from campaign
    if (widget.equipmentName != null && widget.equipmentName!.trim().isNotEmpty) {
      _equipmentNameController.text = widget.equipmentName!.trim();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _institutionController.dispose();
    _equipmentNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Campaigns Tab Functions
  Future<void> _loadCampaigns() async {
    try {
      setState(() {
        _loadingCampaigns = true;
        _error = null;
        _campaigns = [];
      });

      final campaigns = await ApiService.getOpenEquipmentCampaigns();

      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _loadingCampaigns = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load campaigns';
        _loadingCampaigns = false;
      });
    }
  }

  Future<void> _loadDonorAIRecommendations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ?? '').trim();
      if (token.isEmpty) return;

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
          _aiSummary = null;
          _aiRecommendations = [];
          _isLoadingAI = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiSummary = null;
        _aiRecommendations = [];
        _isLoadingAI = false;
      });
    }
  }

  Future<void> _openCampaignDetails(Map<String, dynamic> campaign) async {
    final campaignId = campaign['campaign_id'];
    if (campaignId is! int) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: ApiService.getEquipmentCampaignDetails(campaignId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(child: Text('Failed to load campaign details'));
                }

                final c = snapshot.data!;
                final equipmentName = (c['equipment_name'] ?? '').toString();
                final equipmentType = (c['equipment_type'] ?? '').toString();
                final qtyNeeded = (c['quantity_needed'] ?? 1);
                final qtyFulfilled = (c['quantity_fulfilled'] ?? 0);
                final status = (c['status'] ?? '').toString();

                final instObj = (c['institution'] is Map) ? Map<String, dynamic>.from(c['institution'] as Map) : null;
                final instId = (instObj?['institution_id'] is int)
                    ? instObj!['institution_id'] as int
                    : (c['institution_id'] is int ? c['institution_id'] as int : null);
                final instName = (instObj?['name'] ?? '').toString();

                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 14,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Text(
                        equipmentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (equipmentType.isNotEmpty)
                        Text(
                          equipmentType,
                          style: const TextStyle(color: AppColors.textGray),
                        ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.accent2.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(label: 'Institution', value: instName.isEmpty ? '—' : instName),
                            const SizedBox(height: 6),
                            _InfoRow(label: 'Quantity Needed', value: qtyNeeded.toString()),
                            const SizedBox(height: 6),
                            _InfoRow(label: 'Quantity Fulfilled', value: qtyFulfilled.toString()),
                            const SizedBox(height: 6),
                            _InfoRow(label: 'Status', value: status),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: instId == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                _selectInstitution(instId!);
                                _tabController.animateTo(1);
                              },
                        icon: const Icon(Icons.volunteer_activism),
                        label: const Text('Donate This Equipment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: instId == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                _tabController.animateTo(2);
                              },
                        icon: const Icon(Icons.attach_money),
                        label: const Text('Donate Money Instead'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Donation Tab Functions
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load institutions
      await _loadInstitutions();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInstitutions() async {
    try {
      final institutions = await ApiService.getEquipmentInstitutions();

      setState(() {
        _institutions = institutions;
      });
    } catch (e) {
      print('Error loading institutions: $e');
      setState(() {
        _institutions = [];
      });
    }
  }

  void _selectInstitution(int institutionId) {
    final institution = _institutions.firstWhere(
      (inst) => inst['institution_id'] == institutionId,
      orElse: () => {},
    );

    if (institution.isNotEmpty) {
      setState(() {
        _selectedInstitutionId = institutionId;
        _institutionController.text = institution['name'] ?? '';
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (images != null) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick images: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      print('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String? _validateForm() {
    if (_selectedInstitutionId == null) {
      return 'Please select an institution';
    }

    if (_equipmentNameController.text.isEmpty) {
      return 'Please enter equipment name';
    }

    if (_selectedDate == null) {
      return 'Please select delivery time';
    }

    return null;
  }

  Future<void> _submitDonation() async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/api/equipment/donate'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['institution_id'] = _selectedInstitutionId.toString();
      request.fields['equipment_name'] = _equipmentNameController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['condition'] = _selectedCondition;
      request.fields['preferred_date'] = _selectedDate!.toIso8601String();

      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final file = await http.MultipartFile.fromPath(
          'images',
          image.path,
          filename: 'equipment_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        request.files.add(file);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 201 && data['success'] == true) {
        await _showSuccessDialog(data);
      } else {
        throw Exception(data['message'] ?? 'Failed to submit donation');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit donation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _showSuccessDialog(Map<String, dynamic> response) async {
    final donationId = response['data']['equipment_donation_id'] as int? ?? 0;
    final paddedId = donationId.toString().padLeft(6, '0');
    final trackingCode = 'EQ$paddedId';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Request Submitted Successfully!',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thank you for your generous donation offer.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Tracking Code: $trackingCode',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please save this code to track your donation status.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Next Steps:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Your donation will be registered immediately\n'
              '• The institution will coordinate with you based on your delivery time\n'
              '• You can track your donation using the tracking code\n'
              '• All donations are tax-deductible',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearForm();
            },
            child: const Text('Submit Another Donation'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Return Home'),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _selectedInstitutionId = null;
      _institutionController.clear();
      _equipmentNameController.clear();
      _descriptionController.clear();
      _selectedCondition = 'used_good';
      _selectedDate = null;
      _selectedImages.clear();
    });
  }

  Future<void> _showInstitutionPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Institution',
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
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _institutions.length,
                  itemBuilder: (context, index) {
                    final institution = _institutions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.apartment, color: AppColors.primary),
                        title: Text(institution['name'] ?? ''),
                        subtitle: Text(institution['city'] ?? ''),
                        onTap: () {
                          setState(() {
                            _selectedInstitutionId = institution['institution_id'] as int;
                            _institutionController.text = institution['name'] ?? '';
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCampaignsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCampaigns();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 4),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_loadingCampaigns)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_campaigns.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text('No open equipment campaigns found.')),
            )
          else
            ..._campaigns.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CampaignCard(
                  campaign: c,
                  onTap: () => _openCampaignDetails(c),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDonationTab() {
    return _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading data...'),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Card(
                  color: Colors.blue.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.medical_services, size: 32, color: Colors.blue),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Donate Medical Equipment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Help support children with special needs by donating equipment',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Institution Selection
                _buildInstitutionSelector(),

                const SizedBox(height: 20),

                // Equipment Information
                const Text(
                  'Equipment Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Equipment Name
                TextFormField(
                  controller: _equipmentNameController,
                  decoration: const InputDecoration(
                    labelText: 'Equipment Name *',
                    hintText: 'e.g., Wheelchair, Hearing Aid, Computer',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe the equipment, brand, model, features...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),

                const SizedBox(height: 16),

                // Condition
                // _buildConditionSelector(),

                // const SizedBox(height: 24),

                // Delivery Information
                const Text(
                  'Delivery Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Preferred Date
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Delivery Time *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                              : 'Select date',
                          style: TextStyle(
                            color: _selectedDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                        const Icon(Icons.calendar_month),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Photos
                _buildImageSelector(),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitDonation,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Donation Request',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Information note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Important Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Your donation will be registered immediately\n'
                        '• The institution will coordinate with you based on your delivery time\n'
                        '• You can track your donation using the tracking code\n'
                        '• All donations are tax-deductible',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),

                // Option to switch to money donation
                if (widget.institutionId != null)
                  Container(
                    margin: const EdgeInsets.only(top: 24, bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.attach_money, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Want to donate money instead?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Support therapy sessions and programs by donating money directly.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _tabController.animateTo(2);
                            },
                            icon: const Icon(Icons.attach_money),
                            label: const Text('Switch to Money Donation'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: BorderSide(color: Colors.green),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
  }

  Widget _buildMoneyDonationTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(
                Icons.attach_money,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.institutionName != null
                          ? 'Donate Money to ${widget.institutionName}'
                          : 'Donate Money',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Support therapy sessions, programs, and operational costs',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.institutionId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: OutlinedButton.icon(
              onPressed: () {
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.medical_services),
              label: const Text('Want to donate equipment instead?'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        Expanded(
          child: DonationScreen(
            institutionId: widget.institutionId,
            institutionName: widget.institutionName,
          ),
        ),
      ],
    );
  }

  Widget _buildInstitutionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Institution *',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showInstitutionPicker,
          child: InputDecorator(
            decoration: const InputDecoration(
              hintText: 'Select institution...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.apartment),
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _institutionController.text.isEmpty
                        ? 'Select institution...'
                        : _institutionController.text,
                    style: TextStyle(
                      color: _institutionController.text.isEmpty ? Colors.grey : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Condition *',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildConditionChip('new', 'جديد', Icons.new_label),
            _buildConditionChip('used_good', 'مستعمل - حالة جيدة', Icons.thumb_up),
            _buildConditionChip('used_fair', 'مستعمل - حالة متوسطة', Icons.build),
            _buildConditionChip('needs_repair', 'يحتاج صيانة', Icons.engineering),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionChip(String value, String label, IconData icon) {
    final isSelected = _selectedCondition == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCondition = value;
        });
      },
      backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
      selectedColor: AppColors.primary.withOpacity(0.2),
    );
  }

  Widget _buildImageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Equipment Photos (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload photos to help the institution evaluate the equipment',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedImages.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImages[index].path),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                        onPressed: () => _removeImage(index),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select from Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_selectedImages.length} photo(s) selected',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.institutionName != null
              ? 'Donate to ${widget.institutionName}'
              : 'Donation Options',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(
              icon: Icon(Icons.campaign),
              text: 'Campaigns',
            ),
            Tab(
              icon: Icon(Icons.medical_services),
              text: 'Donate Equipment',
            ),
            Tab(
              icon: Icon(Icons.attach_money),
              text: 'Donate Money',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCampaignsTab(),
          _buildDonationTab(),
          _buildMoneyDonationTab(),
        ],
      ),
      floatingActionButton: _selectedImages.isNotEmpty && _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _pickImages,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_photo_alternate),
            )
          : null,
    );
  }
}

// Helper widgets from original code
class _CampaignCard extends StatelessWidget {
  final Map<String, dynamic> campaign;
  final VoidCallback onTap;

  const _CampaignCard({
    required this.campaign,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (campaign['equipment_name'] ?? '').toString();
    final type = (campaign['equipment_type'] ?? '').toString();
    final status = (campaign['status'] ?? '').toString();
    final needed = (campaign['quantity_needed'] ?? 1);
    final fulfilled = (campaign['quantity_fulfilled'] ?? 0);
    final instObj = (campaign['institution'] is Map) ? Map<String, dynamic>.from(campaign['institution'] as Map) : null;
    final instName = (instObj?['name'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accent2.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.medical_services, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Equipment Campaign' : title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (instName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(instName, style: const TextStyle(color: AppColors.textGray)),
                    ],
                    if (type.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(type, style: const TextStyle(color: AppColors.textGray)),
                    ],
                    const SizedBox(height: 6),
                    Text('Needed: $needed | Fulfilled: $fulfilled', style: const TextStyle(color: AppColors.textGray)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _statusColor(status).withOpacity(0.25)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.primary;
      case 'partially_fulfilled':
        return Colors.orange;
      case 'fulfilled':
        return AppColors.success;
      case 'closed':
        return Colors.grey;
      default:
        return AppColors.textGray;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textGray),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}