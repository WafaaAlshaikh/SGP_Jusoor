import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class ManagerFreeSessionsScreen extends StatefulWidget {
  const ManagerFreeSessionsScreen({Key? key}) : super(key: key);

  @override
  State<ManagerFreeSessionsScreen> createState() => _ManagerFreeSessionsScreenState();
}

class _ManagerFreeSessionsScreenState extends State<ManagerFreeSessionsScreen> {
  final _sessionTypeController = TextEditingController();
  final _specialistController = TextEditingController();
  final _maxChildrenController = TextEditingController(text: '5');
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  List<dynamic> _offers = [];

  Future<void> _generateOffers() async {
    if (_sessionTypeController.text.trim().isEmpty ||
        _specialistController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter session type ID and specialist ID'),
        ),
      );
      return;
    }

    final sessionTypeId = int.tryParse(_sessionTypeController.text.trim());
    final specialistId = int.tryParse(_specialistController.text.trim());
    final maxChildren = int.tryParse(_maxChildrenController.text.trim()) ?? 5;

    if (sessionTypeId == null || specialistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IDs must be numeric'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final result = await ApiService.generateFreeSessionOffers(
        token,
        sessionTypeId: sessionTypeId,
        specialistId: specialistId,
        maxChildren: maxChildren,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (result['success'] == true) {
        setState(() {
          _offers = result['data'] ?? [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Free session offers generated'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to generate offers'),
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
          _isSubmitting = false;
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Text(
                'This feature is deprecated and is now read-only. New free session offers are no longer generated from the app.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            if (_offers.isNotEmpty) ...[
              const Text(
                'Created Offers:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _offers.length,
                  itemBuilder: (context, index) {
                    final o = _offers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text('Offer #${o['offer_id'] ?? ''}'),
                        subtitle: Text(
                            'Child: ${o['child_id']}, Parent: ${o['parent_id']}, SessionType: ${o['session_type_id']}'),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text('No offers to display.'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
