import 'package:flutter/material.dart';

import '../services/reports_service.dart';
import '../services/public_institution_service.dart';
import '../theme/app_colors.dart';

class CreateReportScreen extends StatefulWidget {
  final ReportsScope scope;
  final String title;

  const CreateReportScreen({
    super.key,
    required this.scope,
    this.title = 'Create Report',
  });

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String _priority = 'medium';

  bool _loadingInstitutions = false;
  List<dynamic> _institutions = [];
  int? _selectedInstitutionId;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadInstitutions() async {
    setState(() {
      _loadingInstitutions = true;
    });

    try {
      final list = await PublicInstitutionService.getInstitutions();
      if (!mounted) return;
      setState(() {
        _institutions = list;
        _loadingInstitutions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _institutions = [];
        _loadingInstitutions = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _submitting = true;
    });

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final category = _categoryController.text.trim();

      await ReportsService.createReportScoped(
        scope: widget.scope,
        title: title,
        description: description,
        institutionId: _selectedInstitutionId,
        category: category.isEmpty ? null : category,
        priority: _priority,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report created successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.textWhite,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Title is required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Description is required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _priority = v;
                  });
                },
              ),
              const SizedBox(height: 12),
              _loadingInstitutions
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : DropdownButtonFormField<int?>(
                      value: _selectedInstitutionId,
                      decoration: const InputDecoration(
                        labelText: 'Institution (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No institution'),
                        ),
                        ..._institutions.map((e) {
                          final m = (e as Map).cast<String, dynamic>();
                          final id = (m['institution_id'] as num?)?.toInt();
                          final name = m['name']?.toString() ?? 'Institution';
                          if (id == null) return null;
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          );
                        }).whereType<DropdownMenuItem<int?>>()
                      ],
                      onChanged: (v) {
                        setState(() {
                          _selectedInstitutionId = v;
                        });
                      },
                    ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
