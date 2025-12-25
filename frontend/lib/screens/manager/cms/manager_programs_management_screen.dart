import 'package:flutter/material.dart';

import '../../../services/manager_cms_service.dart';
import '../../../theme/app_colors.dart';

class ManagerProgramsManagementScreen extends StatefulWidget {
  const ManagerProgramsManagementScreen({super.key});

  @override
  State<ManagerProgramsManagementScreen> createState() => _ManagerProgramsManagementScreenState();
}

class _ManagerProgramsManagementScreenState extends State<ManagerProgramsManagementScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await ManagerCmsService.getPrograms();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ProgramEditorDialog(existing: existing),
    );

    if (result == true) {
      _load();
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete program'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ManagerCmsService.deleteProgram(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Deleted'), backgroundColor: AppColors.success),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Programs'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    if (item is! Map) return const SizedBox();
                    final map = item.cast<String, dynamic>();
                    final id = (map['program_id'] as num?)?.toInt() ?? 0;
                    final title = (map['title'] ?? '').toString();
                    final desc = (map['description'] ?? '').toString();
                    final active = (map['is_active'] ?? true) == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent1.withOpacity(0.7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (active ? AppColors.success : AppColors.warning).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: (active ? AppColors.success : AppColors.warning).withOpacity(0.25)),
                                ),
                                child: Text(
                                  active ? 'Active' : 'Hidden',
                                  style: TextStyle(color: active ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          if (desc.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(desc, style: const TextStyle(color: AppColors.textGray, height: 1.3)),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openEditor(existing: map),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: id == 0 ? null : () => _delete(id),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _ProgramEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ProgramEditorDialog({this.existing});

  @override
  State<_ProgramEditorDialog> createState() => _ProgramEditorDialogState();
}

class _ProgramEditorDialogState extends State<_ProgramEditorDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _icon = TextEditingController();
  final _imageUrl = TextEditingController();
  final _sortOrder = TextEditingController();
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = (e['title'] ?? '').toString();
      _description.text = (e['description'] ?? '').toString();
      _icon.text = (e['icon'] ?? '').toString();
      _imageUrl.text = (e['image_url'] ?? '').toString();
      _sortOrder.text = (e['sort_order'] ?? 0).toString();
      _active = (e['is_active'] ?? true) == true;
    } else {
      _sortOrder.text = '0';
      _active = true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _icon.dispose();
    _imageUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  int _parseInt(String v, int fallback) {
    final n = int.tryParse(v.trim());
    return n ?? fallback;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Title is required'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final e = widget.existing;
      if (e == null) {
        await ManagerCmsService.createProgram(
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          icon: _icon.text.trim().isEmpty ? null : _icon.text.trim(),
          imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
          sortOrder: _parseInt(_sortOrder.text, 0),
          isActive: _active,
        );
      } else {
        final id = (e['program_id'] as num?)?.toInt() ?? 0;
        await ManagerCmsService.updateProgram(
          programId: id,
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          icon: _icon.text.trim().isEmpty ? null : _icon.text.trim(),
          imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
          sortOrder: _parseInt(_sortOrder.text, 0),
          isActive: _active,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Program' : 'Edit Program'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _icon, decoration: const InputDecoration(labelText: 'Icon (optional)')),
            TextField(controller: _imageUrl, decoration: const InputDecoration(labelText: 'Image URL (optional)')),
            TextField(controller: _sortOrder, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sort order')),
            TextField(controller: _description, minLines: 2, maxLines: 6, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Active'),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        )
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGray)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
