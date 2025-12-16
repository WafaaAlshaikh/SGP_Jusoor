import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ParentFreeSessionsScreen extends StatefulWidget {
  const ParentFreeSessionsScreen({Key? key}) : super(key: key);

  @override
  State<ParentFreeSessionsScreen> createState() => _ParentFreeSessionsScreenState();
}

class _ParentFreeSessionsScreenState extends State<ParentFreeSessionsScreen> {
  bool _isLoading = true;
  List<dynamic> _offers = [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final result = await ApiService.getParentFreeSessionOffers(token);

      if (result['success'] == true) {
        setState(() {
          _offers = result['data'] ?? [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load offers'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free Session Offers'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Free session offers are deprecated and are now read-only. You can still view any existing offers here.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                Expanded(
                  child: _offers.isEmpty
                      ? const Center(
                          child: Text(
                              'No free session offers available at the moment'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadOffers,
                          child: ListView.builder(
                            itemCount: _offers.length,
                            itemBuilder: (context, index) {
                              final o = _offers[index];
                              final child = o['child'];
                              final institution = o['institution'];

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Offer #${o['offer_id'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (child != null)
                                        Text(
                                            'Child: ${child['name'] ?? child['id']}'),
                                      if (institution != null)
                                        Text(
                                            'Institution: ${institution['name'] ?? institution['id']}'),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Session Type: ${o['session_type_id']}'),
                                      const SizedBox(height: 4),
                                      if (o['notes'] != null &&
                                          (o['notes'] as String).isNotEmpty)
                                        Text('Notes: ${o['notes']}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
