// lib/screens/parent_donation_history_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ParentDonationHistoryScreen extends StatefulWidget {
  const ParentDonationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ParentDonationHistoryScreen> createState() => _ParentDonationHistoryScreenState();
}

class _ParentDonationHistoryScreenState extends State<ParentDonationHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'You need to login to view your donations.';
          _isLoading = false;
        });
        return;
      }

      final result = await ApiService.getDonationHistory(token, page: 1, limit: 50);
      final data = result['data'] as List<dynamic>? ?? [];

      setState(() {
        _items = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load donation history: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _items.isEmpty
                  ? const Center(child: Text('No donations yet.'))
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index] as Map<String, dynamic>;
                          return _buildDonationTile(item);
                        },
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadHistory,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationTile(Map<String, dynamic> item) {
    final amount = (item['amount'] ?? 0).toDouble();
    final DateTime? date = item['date'] != null
        ? DateTime.tryParse(item['date'].toString())
        : null;
    final institution = item['institution'] as Map<String, dynamic>?;
    final campaign = item['campaign'] as Map<String, dynamic>?;

    final subtitleParts = <String>[];
    if (institution != null) {
      subtitleParts.add(institution['name']?.toString() ?? '');
      if (institution['city'] != null) {
        subtitleParts.add(institution['city'].toString());
      }
    }
    if (campaign != null) {
      subtitleParts.add('Campaign: ${campaign['name']}');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${amount.toStringAsFixed(0)} JOD',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' • '),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date != null
                ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                : '',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
