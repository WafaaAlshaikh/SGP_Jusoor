import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/screens/donations_success.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'stripe_checkout_screen.dart';

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
  String _donationMode = 'one_time';
  List<Map<String, dynamic>> _campaignsForSelectedInstitution = [];
  int? _selectedCampaignId;
  bool _didAutoOpenForInstitution = false;
  Map<String, dynamic>? _currentInstitution;

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
      final token = prefs.getString('token') ?? '';

      final institutions = await ApiService.getDonationInstitutions(token);

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
                            final double target = 
                                double.tryParse('${campaign['target_amount'] ?? 0}') ?? 0;
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
                                              color: status == 'active' 
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                      )
                                    : null,
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
            return AlertDialog(
              title: Text(
                'Donate to ${institution['name'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
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
              ],
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
    Map<String, dynamic> institution, double amount) async {
  try {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing payment...'),
          ],
        ),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    
    if (token.isEmpty) {
      Navigator.pop(context); // Remove loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to donate'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await ApiService.createDonationCheckout(
      token,
      institutionId: institution['institution_id'] as int,
      amount: amount,
      mode: _donationMode == 'monthly' ? 'monthly' : 'one_time',
      campaignId: _selectedCampaignId,
    );

    Navigator.pop(context); // Remove loading

    final url = (result['url'] ?? result['checkout_url'])?.toString();

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get checkout URL from server'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // فتح WebView بدلاً من url_launcher
    final paymentCompleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StripeCheckoutScreen(
          checkoutUrl: url,
          sessionId: (result['sessionId'] ?? result['session_id'])?.toString(),
          institutionId: institution['institution_id'] as int,
          institutionName: institution['name'] ?? 'Institution',
          amount: amount,
        ),
      ),
    ) ?? false;

    if (paymentCompleted && context.mounted) {
      // الانتقال لصفحة النجاح
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DonationSuccessScreen(
            sessionId: (result['sessionId'] ?? result['session_id'])?.toString(),
            institutionId: institution['institution_id'] as int,
            // institutionName: institution['name'],
            // amount: amount,
          ),
        ),
      );
    }

  } catch (e) {
    print('Payment error: $e');
    
    if (context.mounted) {
      Navigator.pop(context); // Remove loading if still showing
      
      String errorMessage = 'Failed to process payment';
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        errorMessage = 'Please login to make a donation';
      } else if (e.toString().contains('Network')) {
        errorMessage = 'Network error. Please check your connection';
      } else if (e.toString().contains('Stripe')) {
        errorMessage = 'Payment service error. Please try again';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Failed'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
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
      appBar: AppBar(
        title: Text(
          widget.institutionId != null && 
          (widget.institutionName ?? '').trim().isNotEmpty
              ? 'Donate to ${widget.institutionName}'
              : 'Support Institutions',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_institutions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About Donations'),
                    content: const Text(
                      'Your donations help support children\'s therapy sessions. '
                      'You can donate to specific campaigns or to the general fund. '
                      'All donations are processed securely through Stripe.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
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
                  : Column(
                      children: [
                        // Header with total count
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: AppColors.primary.withOpacity(0.1),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_user,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_institutions.length} institution${_institutions.length != 1 ? 's' : ''} available for donation',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Institutions List
                        Expanded(
                          child: ListView.builder(
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
                        ),
                      ],
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