import 'package:flutter/material.dart';

import '../../../services/manager_cms_service.dart';
import '../../../theme/app_colors.dart';

class ManagerNewsManagementScreen extends StatefulWidget {
  const ManagerNewsManagementScreen({super.key});

  @override
  State<ManagerNewsManagementScreen> createState() => _ManagerNewsManagementScreenState();
}

class _ManagerNewsManagementScreenState extends State<ManagerNewsManagementScreen> {
  bool _loading = true;
  String? _error;

  int _page = 1;
  int _totalPages = 1;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ManagerCmsService.getNews(page: page, limit: 20);
      final items = (data['items'] as List?) ?? const [];
      final pagination = (data['pagination'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

      setState(() {
        _items = items;
        _page = page;
        _totalPages = (pagination['totalPages'] as int?) ?? 1;
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
      builder: (_) => _NewsEditorDialog(existing: existing),
    );

    if (result == true) {
      _load(page: _page);
    }
  }

  Future<void> _delete(int newsId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete news'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ManagerCmsService.deleteNews(newsId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Deleted'), backgroundColor: AppColors.success),
      );
      _load(page: _page);
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
        title: const Text('News'),
        actions: [
          IconButton(onPressed: () => _load(page: _page), icon: const Icon(Icons.refresh)),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Failed to load', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGray)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: () => _load(page: _page), child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          if (item is! Map) return const SizedBox();
                          final id = (item['news_id'] as num?)?.toInt() ?? 0;
                          final title = (item['title'] ?? '').toString();
                          final summary = (item['summary'] ?? '').toString();
                          final published = (item['is_published'] ?? true) == true;

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
                                        color: (published ? AppColors.success : AppColors.warning).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: (published ? AppColors.success : AppColors.warning).withOpacity(0.25)),
                                      ),
                                      child: Text(
                                        published ? 'Published' : 'Hidden',
                                        style: TextStyle(color: published ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                if (summary.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(summary, style: const TextStyle(color: AppColors.textGray, height: 1.3)),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _openEditor(existing: item.cast<String, dynamic>()),
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
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                              child: const Text('Prev'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('$_page / $_totalPages', style: const TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _page < _totalPages ? () => _load(page: _page + 1) : null,
                              child: const Text('Next'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _NewsEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _NewsEditorDialog({this.existing});

  @override
  State<_NewsEditorDialog> createState() => _NewsEditorDialogState();
}

class _NewsEditorDialogState extends State<_NewsEditorDialog> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _content = TextEditingController();
  final _cover = TextEditingController();
  bool _published = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = (e['title'] ?? '').toString();
      _summary.text = (e['summary'] ?? '').toString();
      _content.text = (e['content'] ?? '').toString();
      _cover.text = (e['cover_image_url'] ?? '').toString();
      _published = (e['is_published'] ?? true) == true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _content.dispose();
    _cover.dispose();
    super.dispose();
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
        await ManagerCmsService.createNews(
          title: _title.text.trim(),
          summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
          content: _content.text.trim().isEmpty ? null : _content.text.trim(),
          coverImageUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
          isPublished: _published,
        );
      } else {
        final id = (e['news_id'] as num?)?.toInt() ?? 0;
        await ManagerCmsService.updateNews(
          newsId: id,
          title: _title.text.trim(),
          summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
          content: _content.text.trim().isEmpty ? null : _content.text.trim(),
          coverImageUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
          isPublished: _published,
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
      title: Text(widget.existing == null ? 'Add News' : 'Edit News'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _summary,
              decoration: const InputDecoration(labelText: 'Summary'),
            ),
            TextField(
              controller: _cover,
              decoration: const InputDecoration(labelText: 'Cover image URL (optional)'),
            ),
            TextField(
              controller: _content,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _published,
              onChanged: (v) => setState(() => _published = v),
              title: const Text('Published'),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
        )
      ],
    );
  }
}
