import 'package:flutter/material.dart';

import '../../../services/manager_cms_service.dart';
import '../../../theme/app_colors.dart';

class ManagerPageContentEditorScreen extends StatefulWidget {
  const ManagerPageContentEditorScreen({super.key});

  @override
  State<ManagerPageContentEditorScreen> createState() => _ManagerPageContentEditorScreenState();
}

class _ManagerPageContentEditorScreenState extends State<ManagerPageContentEditorScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final Map<String, TextEditingController> _titleControllers = {
    'about': TextEditingController(),
    'mission': TextEditingController(),
    'our_world': TextEditingController(),
    'contact': TextEditingController(),
    'donate': TextEditingController(),
  };

  final Map<String, TextEditingController> _contentControllers = {
    'about': TextEditingController(),
    'mission': TextEditingController(),
    'our_world': TextEditingController(),
    'contact': TextEditingController(),
    'donate': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    for (final c in _contentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await ManagerCmsService.getPageContent();

      for (final item in items.whereType<Map>()) {
        final key = item['key']?.toString();
        if (key == null) continue;

        if (_titleControllers.containsKey(key)) {
          _titleControllers[key]!.text = (item['title'] ?? '').toString();
        }
        if (_contentControllers.containsKey(key)) {
          _contentControllers[key]!.text = (item['content'] ?? '').toString();
        }
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveKey(String key) async {
    setState(() {
      _saving = true;
    });

    try {
      final title = _titleControllers[key]!.text.trim();
      final content = _contentControllers[key]!.text.trim();

      if (content.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Content cannot be empty'),
            backgroundColor: Colors.orange[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      await ManagerCmsService.upsertPageContent(
        key: key,
        title: title.isEmpty ? null : title,
        content: content,
      );

      if (!mounted) return;
      
      // Show success animation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Saved successfully!', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Error: ${e.toString().split('\n')[0]}'),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _labelForKey(String key) {
    switch (key) {
      case 'about':
        return 'About Us';
      case 'mission':
        return 'Our Mission';
      case 'our_world':
        return 'Our World';
      case 'contact':
        return 'Contact Information';
      case 'donate':
        return 'Donation Information';
      default:
        return key;
    }
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'about':
        return Icons.info_outline;
      case 'mission':
        return Icons.flag_outlined;
      case 'our_world':
        return Icons.public_outlined;
      case 'contact':
        return Icons.contact_mail_outlined;
      case 'donate':
        return Icons.volunteer_activism_outlined;
      default:
        return Icons.text_fields_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit_document, color: AppColors.primary, size: 24),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Page Content Editor',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Manage your website content',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.refresh, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Loading content...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.error_outline, color: Colors.red, size: 40),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load content',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: Icon(Icons.refresh, size: 18),
                          label: Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Edit your website content below. Changes will be visible to visitors immediately after saving.',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Sections List with Scroll
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          for (final key in _contentControllers.keys)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: _SectionEditor(
                                title: _labelForKey(key),
                                icon: _iconForKey(key),
                                titleController: _titleControllers[key]!,
                                contentController: _contentControllers[key]!,
                                onSave: () => _saveKey(key),
                                isSaving: _saving,
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

class _SectionEditor extends StatefulWidget {
  final String title;
  final IconData icon;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final VoidCallback onSave;
  final bool isSaving;

  const _SectionEditor({
    required this.title,
    required this.icon,
    required this.titleController,
    required this.contentController,
    required this.onSave,
    required this.isSaving,
  });

  @override
  State<_SectionEditor> createState() => __SectionEditorState();
}

class __SectionEditorState extends State<_SectionEditor> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: AppColors.primary, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Click to expand/collapse',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Content (collapsible)
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 200,
                      maxHeight: constraints.maxHeight,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Title (optional)',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: widget.titleController,
                            style: TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter title here...',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppColors.primary),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Content *',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            constraints: BoxConstraints(
                              minHeight: 150,
                              maxHeight: 400,
                            ),
                            child: TextField(
                              controller: widget.contentController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter your content here...',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: AppColors.primary),
                                ),
                                contentPadding: EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: widget.isSaving ? null : widget.onSave,
                              icon: widget.isSaving
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(Icons.save_outlined, size: 18),
                              label: Text(widget.isSaving ? 'Saving...' : 'Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}