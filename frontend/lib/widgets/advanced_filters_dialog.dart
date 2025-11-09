// ملف جديد: lib/screens/manage_children/widgets/advanced_filters_dialog.dart

import 'package:flutter/material.dart';

class AdvancedFiltersDialog extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApply;
  final VoidCallback onReset;

  const AdvancedFiltersDialog({
    super.key,
    required this.currentFilters,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<AdvancedFiltersDialog> createState() => _AdvancedFiltersDialogState();
}

class _AdvancedFiltersDialogState extends State<AdvancedFiltersDialog> {
  late Map<String, dynamic> _tempFilters;

  @override
  void initState() {
    super.initState();
    _tempFilters = Map.from(widget.currentFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الفلاتر المتقدمة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // نطاق العمر
                  _buildAgeRangeFilter(),
                  SizedBox(height: 20),

                  // تحليل الذكاء الاصطناعي
                  _buildAIFilter(),
                  SizedBox(height: 20),

                  // مستوى الخطورة
                  _buildRiskLevelFilter(),
                  SizedBox(height: 20),

                  // حالة التسجيل
                  _buildRegistrationFilter(),
                ],
              ),
            ),
          ),

          // أزرار التنفيذ
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onReset,
                  child: Text('إعادة التعيين'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_tempFilters);
                    Navigator.pop(context);
                  },
                  child: Text('تطبيق الفلاتر'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نطاق العمر', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(
            _tempFilters['ageRange']['min']?.toDouble() ?? 0,
            _tempFilters['ageRange']['max']?.toDouble() ?? 18,
          ),
          min: 0,
          max: 18,
          divisions: 18,
          labels: RangeLabels(
            '${_tempFilters['ageRange']['min']} سنة',
            '${_tempFilters['ageRange']['max']} سنة',
          ),
          onChanged: (values) {
            setState(() {
              _tempFilters['ageRange'] = {
                'min': values.start.round(),
                'max': values.end.round(),
              };
            });
          },
        ),
      ],
    );
  }

  Widget _buildAIFilter() {
    return SwitchListTile(
      title: Text('لديه تحليل ذكاء اصطناعي'),
      subtitle: Text('عرض الأطفال الذين تم تحليل حالتهم بالذكاء الاصطناعي'),
      value: _tempFilters['hasAiAnalysis'] ?? false,
      onChanged: (value) {
        setState(() {
          _tempFilters['hasAiAnalysis'] = value;
        });
      },
    );
  }

  Widget _buildRiskLevelFilter() {
    final riskLevels = ['Low', 'Medium', 'High'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('مستوى الخطورة', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: riskLevels.map((level) {
            final isSelected = (_tempFilters['riskLevel'] ?? []).contains(level);
            return FilterChip(
              label: Text(level),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  final List current = List.from(_tempFilters['riskLevel'] ?? []);
                  if (selected) {
                    current.add(level);
                  } else {
                    current.remove(level);
                  }
                  _tempFilters['riskLevel'] = current;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRegistrationFilter() {
    final statuses = ['Not Registered', 'Pending', 'Approved', 'Archived'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('حالة التسجيل', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _tempFilters['registrationStatus'],
          items: [
            DropdownMenuItem(value: null, child: Text('جميع الحالات')),
            ...statuses.map((status) =>
                DropdownMenuItem(value: status, child: Text(status)))
          ],
          onChanged: (value) {
            setState(() {
              _tempFilters['registrationStatus'] = value;
            });
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }
}