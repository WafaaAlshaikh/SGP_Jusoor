import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _institutions = [];
  String _donationMode = 'one_time'; // one_time, monthly, or campaign
  List<Map<String, dynamic>> _campaignsForSelectedInstitution = [];
  int? _selectedCampaignId;

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

      setState(() {
        _institutions = institutions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load institutions: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _openCampaignSelectorInDialog(void Function(void Function()) setStateDialog) {
    if (_campaignsForSelectedInstitution.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a campaign',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._campaignsForSelectedInstitution.map((c) {
                  final int id = c['campaign_id'] as int;
                  final bool isSelected = _selectedCampaignId == id;
                  final double target =
                      double.tryParse('${c['target_amount'] ?? 0}') ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      c['name']?.toString() ?? 'Campaign',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((c['description']?.toString() ?? '').isNotEmpty)
                          Text(
                            c['description']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (target > 0)
                          Text(
                            'Target: ${target.toStringAsFixed(0)} JOD',
                            style:
                                const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setStateDialog(() {
                        _selectedCampaignId = id;
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDonateDialog(Map<String, dynamic> institution) async {
    final TextEditingController amountController = TextEditingController();

    // reset campaigns & selection for this institution
    _campaignsForSelectedInstitution = [];
    _selectedCampaignId = null;

    // try to load campaigns for this institution (non-blocking for UI)
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? '';
        if (token.isEmpty) return;

        final campaigns =
            await ApiService.getInstitutionCampaignsForDonations(
          token,
          institution['institution_id'] as int,
        );

        if (!mounted) return;
        setState(() {
          _campaignsForSelectedInstitution = campaigns;
        });
      } catch (_) {}
    }();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Donate to ${institution['name'] ?? ''}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Donation amount',
                  hintText: 'e.g. 50',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'How would you like to donate?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              StatefulBuilder(
                builder: (context, setStateDialog) {
                  return Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'one_time',
                          groupValue: _donationMode,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('One-time (general)'),
                          onChanged: (val) {
                            if (val == null) return;
                            setStateDialog(() {
                              _donationMode = val;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'monthly',
                          groupValue: _donationMode,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Monthly (general)'),
                          onChanged: (val) {
                            if (val == null) return;
                            setStateDialog(() {
                              _donationMode = val;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setStateDialog) {
                  return RadioListTile<String>(
                    value: 'campaign',
                    groupValue: _donationMode,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Donate to a specific campaign'),
                    onChanged: (val) {
                      if (val == null) return;
                      setStateDialog(() {
                        _donationMode = val;
                      });
                    },
                  );
                },
              ),
              if (_donationMode == 'campaign') ...[
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'If you select a campaign, your donation will count towards that goal.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 4),
                StatefulBuilder(
                  builder: (context, setStateDialog) {
                    if (_campaignsForSelectedInstitution.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'This institution has no active campaigns at the moment.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      );
                    }

                    Map<String, dynamic>? selectedCampaign;
                    if (_selectedCampaignId != null) {
                      for (final c in _campaignsForSelectedInstitution) {
                        if (c['campaign_id'] == _selectedCampaignId) {
                          selectedCampaign = c;
                          break;
                        }
                      }
                    }

                    final String selectedLabel = selectedCampaign != null
                        ? 'Selected campaign: ${selectedCampaign['name'] ?? ''}'
                        : 'No campaign selected yet';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedLabel,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          onPressed: () => _openCampaignSelectorInDialog(setStateDialog),
                          child: const Text('Choose campaign'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Donate'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final raw = amountController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter donation amount')),
      );
      return;
    }

    final amount = double.tryParse(raw.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid donation amount')),
      );
      return;
    }

    await _startDonationCheckout(institution, amount);
  }

  Future<void> _startDonationCheckout(
      Map<String, dynamic> institution, double amount) async {
    try {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting payment with Stripe...'),
          backgroundColor: Colors.blue,
        ),
      );

      // Map UI selection to API parameters
      final bool donateToCampaign = _donationMode == 'campaign';
      final String modeToSend =
          _donationMode == 'monthly' ? 'monthly' : 'one_time';
      final int? campaignIdToSend = donateToCampaign ? _selectedCampaignId : null;

      if (donateToCampaign && campaignIdToSend == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a campaign to donate to.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final result = await ApiService.createDonationCheckout(
        token,
        institutionId: institution['institution_id'] as int,
        amount: amount,
        mode: modeToSend,
        campaignId: campaignIdToSend,
      );

      final url = result['url']?.toString();

      if (!mounted) return;

      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get checkout URL from server'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final uri = Uri.tryParse(url);
      if (uri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid payment link'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open payment link: $url'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start donation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donations'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInstitutions,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _institutions.isEmpty
                  ? const Center(
                      child: Text('No institutions available for donations yet'),
                    )
                  : ListView.builder(
                      itemCount: _institutions.length,
                      itemBuilder: (context, index) {
                        final inst = _institutions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(inst['name'] ?? ''),
                            subtitle: Text(
                              (inst['city'] ?? '') +
                                  (inst['address'] != null
                                      ? ' - ${inst['address']}'
                                      : ''),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _showDonateDialog(inst),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Donate'),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Future<void> _showCampaignsBottomSheet(Map<String, dynamic> institution) async {
    List<Map<String, dynamic>> campaigns = [];
    bool isError = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        isError = true;
      } else {
        campaigns = await ApiService.getInstitutionCampaignsForDonations(
          token,
          institution['institution_id'] as int,
        );
      }
    } catch (_) {
      isError = true;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        if (isError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Campaigns',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Could not load campaigns for this institution. Please try again later.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (campaigns.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campaigns',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'This institution has no active campaigns at the moment. Your donation will go to the general fund.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campaigns at ${institution['name'] ?? ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...campaigns.map((c) {
                final double target =
                    double.tryParse('${c['target_amount'] ?? 0}') ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['name']?.toString() ?? 'Campaign',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((c['description']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          c['description']?.toString() ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        target > 0
                            ? 'Target: ${target.toStringAsFixed(0)} JOD'
                            : 'Open target campaign',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
