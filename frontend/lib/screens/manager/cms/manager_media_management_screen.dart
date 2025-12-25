import 'package:flutter/material.dart';

import '../../../services/manager_cms_service.dart';
import '../../../theme/app_colors.dart';

class ManagerMediaManagementScreen extends StatefulWidget {
  const ManagerMediaManagementScreen({super.key});

  @override
  State<ManagerMediaManagementScreen> createState() => _ManagerMediaManagementScreenState();
}

class _ManagerMediaManagementScreenState extends State<ManagerMediaManagementScreen> {
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
      final items = await ManagerCmsService.getMedia();
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
      builder: (_) => _MediaEditorDialog(existing: existing),
    );

    if (result == true) {
      _load();
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete media'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ManagerCmsService.deleteMedia(id);
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
        title: const Text('Media'),
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
                    final id = (map['institution_media_id'] as num?)?.toInt() ?? 0;
                    final type = (map['media_type'] ?? '').toString();
                    final url = (map['url'] ?? '').toString();
                    final title = (map['title'] ?? '').toString();
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
                                child: Text(type.toUpperCase(), style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900)),
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
                          if (title.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(title, style: const TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w700)),
                          ],
                          if (url.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(url, style: const TextStyle(color: AppColors.textLight)),
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

class _MediaEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _MediaEditorDialog({this.existing});

  @override
  State<_MediaEditorDialog> createState() => _MediaEditorDialogState();
}

class _MediaEditorDialogState extends State<_MediaEditorDialog> {
  final _type = TextEditingController();
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _sortOrder = TextEditingController();
  bool _active = true;
  bool _saving = false;

  static const _types = ['logo', 'cover', 'gallery', 'video'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type.text = (e['media_type'] ?? '').toString();
      _url.text = (e['url'] ?? '').toString();
      _title.text = (e['title'] ?? '').toString();
      _description.text = (e['description'] ?? '').toString();
      _sortOrder.text = (e['sort_order'] ?? 0).toString();
      _active = (e['is_active'] ?? true) == true;
    } else {
      _type.text = 'gallery';
      _sortOrder.text = '0';
      _active = true;
    }
  }

  @override
  void dispose() {
    _type.dispose();
    _url.dispose();
    _title.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  int _parseInt(String v, int fallback) {
    final n = int.tryParse(v.trim());
    return n ?? fallback;
  }

  Future<void> _save() async {
    if (_url.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('URL is required'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final mediaType = _type.text.trim().isEmpty ? 'gallery' : _type.text.trim();

    setState(() => _saving = true);

    try {
      final e = widget.existing;
      if (e == null) {
        await ManagerCmsService.createMedia(
          mediaType: mediaType,
          url: _url.text.trim(),
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          sortOrder: _parseInt(_sortOrder.text, 0),
          isActive: _active,
        );
      } else {
        final id = (e['institution_media_id'] as num?)?.toInt() ?? 0;
        await ManagerCmsService.updateMedia(
          mediaId: id,
          mediaType: mediaType,
          url: _url.text.trim(),
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
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
      title: Text(widget.existing == null ? 'Add Media' : 'Edit Media'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _types.contains(_type.text) ? _type.text : 'gallery',
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type.text = v ?? 'gallery'),
              decoration: const InputDecoration(labelText: 'Media type'),
            ),
            TextField(controller: _url, decoration: const InputDecoration(labelText: 'URL')),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title (optional)')),
            TextField(controller: _sortOrder, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sort order')),
            TextField(controller: _description, minLines: 2, maxLines: 6, decoration: const InputDecoration(labelText: 'Description (optional)')),
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
