import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class DonationInviteStatsScreen extends StatefulWidget {
  const DonationInviteStatsScreen({super.key});

  @override
  State<DonationInviteStatsScreen> createState() => _DonationInviteStatsScreenState();
}

class _DonationInviteStatsScreenState extends State<DonationInviteStatsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ?? '').trim();
      if (token.isEmpty) {
        throw Exception('Authentication required');
      }

      final res = await ApiService.getMyDonationInviteStats(token);
      setState(() {
        _data = res['data'] is Map<String, dynamic> ? (res['data'] as Map<String, dynamic>) : res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load invite stats';
      });
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_data?['summary'] is Map)
        ? Map<String, dynamic>.from(_data!['summary'] as Map)
        : <String, dynamic>{};
    final items = (_data?['items'] is List)
        ? (_data!['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Invite Impact'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Summary',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _kpi(
                                    'Invites',
                                    _toInt(summary['invites_count']).toString(),
                                    Icons.link,
                                    AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _kpi(
                                    'Clicks',
                                    _toInt(summary['clicks']).toString(),
                                    Icons.ads_click,
                                    Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _kpi(
                                    'Checkouts',
                                    _toInt(summary['checkouts']).toString(),
                                    Icons.shopping_cart_checkout,
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _kpi(
                                    'Donations',
                                    _toInt(summary['donations_count']).toString(),
                                    Icons.volunteer_activism,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _kpi(
                              'Total Raised',
                              '${_toDouble(summary['donated_amount_total']).toStringAsFixed(0)} JOD',
                              Icons.attach_money,
                              Colors.teal,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your Invites',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        const Text('No invites yet', style: TextStyle(color: Colors.grey))
                      else
                        ...items.map((inv) {
                          final code = (inv['code'] ?? '').toString();
                          final campaignId = inv['campaign_id'];
                          final stats = (inv['stats'] is Map)
                              ? Map<String, dynamic>.from(inv['stats'] as Map)
                              : <String, dynamic>{};

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.withOpacity(0.15)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.link, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Code: $code',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                if (campaignId != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Campaign ID: $campaignId', style: const TextStyle(color: Colors.grey)),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _mini('Clicks', _toInt(stats['clicks']).toString())),
                                    Expanded(child: _mini('Checkouts', _toInt(stats['checkouts']).toString())),
                                    Expanded(child: _mini('Donations', _toInt(stats['donations_count']).toString())),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Raised: ${_toDouble(stats['donated_amount_total']).toStringAsFixed(0)} JOD',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _kpi(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
