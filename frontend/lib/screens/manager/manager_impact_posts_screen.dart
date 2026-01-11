import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../../theme/app_colors.dart';
import '../../services/manager_dashboard_service.dart';

class ManagerImpactPostsScreen extends StatefulWidget {
  const ManagerImpactPostsScreen({super.key});

  @override
  State<ManagerImpactPostsScreen> createState() => _ManagerImpactPostsScreenState();
}

class _ManagerImpactPostsScreenState extends State<ManagerImpactPostsScreen> {
  bool _loading = true;
  String? _error;

  int _page = 1;
  final int _limit = 20;
  int _totalPages = 1;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    try {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });

      final res = await ManagerDashboardService.listImpactPosts(page: page, limit: _limit);
      final items = (res['items'] is List)
          ? (res['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      final pagination = (res['pagination'] is Map)
          ? Map<String, dynamic>.from(res['pagination'] as Map)
          : <String, dynamic>{};
      final totalPages = (pagination['totalPages'] is int)
          ? pagination['totalPages'] as int
          : int.tryParse('${pagination['totalPages'] ?? ''}') ?? 1;

      if (!mounted) return;
      setState(() {
        _items = items;
        _page = page;
        _totalPages = totalPages <= 0 ? 1 : totalPages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
        _error = 'Failed to load impact posts';
      });
    }
  }

  String _formatDate(dynamic v) {
    if (v == null) return '-';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _openEditDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;

    final titleController = TextEditingController(text: existing?['title']?.toString() ?? '');
    final contentController = TextEditingController(text: existing?['content']?.toString() ?? '');
    final coverUrlController = TextEditingController(text: existing?['cover_url']?.toString() ?? '');
    final mediaUrlsController = TextEditingController(
      text: existing?['media_urls'] != null ? jsonEncode(existing!['media_urls']) : '',
    );
    final mediaLinkController = TextEditingController(
      text: (() {
        final cover = (existing?['cover_url'] ?? '').toString();
        if (cover.isNotEmpty) return cover;
        final urls = existing?['media_urls'];
        if (urls is List && urls.isNotEmpty) return urls.first.toString();
        if (urls is String && urls.isNotEmpty) return urls;
        return '';
      })(),
    );

    String type = (existing?['type'] ?? 'update').toString();
    bool isPublished = existing?['is_published'] == true;
    String mediaSource = 'link';
    File? pickedFile;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Impact Post' : 'Create Impact Post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'success_story', child: Text('Success Story')),
                        DropdownMenuItem(value: 'update', child: Text('Update')),
                        DropdownMenuItem(value: 'video', child: Text('Video')),
                        DropdownMenuItem(value: 'tip', child: Text('Tip')),
                        DropdownMenuItem(value: 'thank_you', child: Text('Thank You')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setStateDialog(() {
                          type = v;
                          if (type == 'video') {
                            if (mediaSource != 'file' && mediaSource != 'link') {
                              mediaSource = 'link';
                            }
                          } else {
                            if (mediaSource != 'file' && mediaSource != 'link') {
                              mediaSource = 'link';
                            }
                          }
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: 'Content'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'link',
                            groupValue: mediaSource,
                            onChanged: (v) {
                              if (v == null) return;
                              setStateDialog(() {
                                mediaSource = v;
                                pickedFile = null;
                              });
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(type == 'video' ? 'Video Link' : 'Image Link'),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'file',
                            groupValue: mediaSource,
                            onChanged: (v) {
                              if (v == null) return;
                              setStateDialog(() {
                                mediaSource = v;
                              });
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(type == 'video' ? 'Upload Video' : 'Upload Image'),
                          ),
                        ),
                      ],
                    ),
                    if (mediaSource == 'link') ...[
                      TextField(
                        controller: mediaLinkController,
                        decoration: InputDecoration(
                          labelText: type == 'video' ? 'Video URL (optional)' : 'Image URL (optional)',
                        ),
                      ),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          pickedFile == null ? 'No file selected' : 'Selected: ${pickedFile!.path.split(RegExp(r"[\\/]")).last}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (kIsWeb) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('File upload is not supported on web in this screen. Use a link instead.'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowMultiple: false,
                              allowedExtensions: type == 'video'
                                  ? ['mp4', 'mov', 'mkv', 'webm']
                                  : ['jpg', 'jpeg', 'png', 'gif'],
                            );
                            if (result == null || result.files.isEmpty) return;
                            final p = result.files.single.path;
                            if (p == null || p.isEmpty) return;
                            setStateDialog(() {
                              pickedFile = File(p);
                            });
                          },
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Choose file'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isPublished,
                      onChanged: (v) {
                        setStateDialog(() {
                          isPublished = v;
                        });
                      },
                      title: const Text('Published'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final content = contentController.text.trim().isEmpty ? null : contentController.text.trim();

                    final mediaLink = mediaLinkController.text.trim().isEmpty ? null : mediaLinkController.text.trim();

                    dynamic legacyMediaUrls;
                    final rawMediaJson = mediaUrlsController.text.trim();
                    if (rawMediaJson.isNotEmpty) {
                      try {
                        legacyMediaUrls = jsonDecode(rawMediaJson);
                      } catch (_) {
                        legacyMediaUrls = rawMediaJson;
                      }
                    }

                    final linkMediaUrls = mediaLink != null ? [mediaLink] : null;
                    final linkCoverUrl = mediaLink;

                    final body = <String, dynamic>{
                      'type': type,
                      'title': title,
                      'content': content,
                      'cover_url': linkCoverUrl,
                      'media_urls': linkMediaUrls ?? (rawMediaJson.isEmpty ? null : legacyMediaUrls),
                      'is_published': isPublished,
                    };

                    try {
                      if (isEdit) {
                        final postId = existing!['post_id'];
                        if (postId is int) {
                          if (mediaSource == 'file' && pickedFile != null) {
                            await ManagerDashboardService.updateImpactPostMultipart(
                              postId: postId,
                              fields: body,
                              mediaFile: pickedFile!,
                            );
                          } else {
                            await ManagerDashboardService.updateImpactPost(postId, body);
                          }
                        } else {
                          final id = int.tryParse(postId.toString());
                          if (id != null) {
                            if (mediaSource == 'file' && pickedFile != null) {
                              await ManagerDashboardService.updateImpactPostMultipart(
                                postId: id,
                                fields: body,
                                mediaFile: pickedFile!,
                              );
                            } else {
                              await ManagerDashboardService.updateImpactPost(id, body);
                            }
                          }
                        }
                      } else {
                        if (mediaSource == 'file' && pickedFile != null) {
                          await ManagerDashboardService.createImpactPostMultipart(
                            fields: body,
                            mediaFile: pickedFile!,
                          );
                        } else {
                          await ManagerDashboardService.createImpactPost(body);
                        }
                      }

                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        Navigator.pop(context, false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                  child: Text(isEdit ? 'Save' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _load(page: _page);
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final postIdRaw = post['post_id'];
    final postId = postIdRaw is int ? postIdRaw : int.tryParse(postIdRaw.toString());
    if (postId == null) return;

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Impact Post'),
            content: const Text('Are you sure you want to delete this post?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await ManagerDashboardService.deleteImpactPost(postId);
      if (!mounted) return;
      _load(page: _page);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete post'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impact Posts'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _load(page: _page),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openEditDialog(),
        child: const Icon(Icons.add_rounded),
      ),
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
                        ElevatedButton(
                          onPressed: () => _load(page: 1),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(
                              child: Text(
                                'No impact posts yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final p = _items[index];
                                final title = (p['title'] ?? '').toString();
                                final type = (p['type'] ?? '').toString();
                                final published = p['is_published'] == true;
                                final date = _formatDate(p['published_at'] ?? p['created_at']);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.grey.withOpacity(0.18)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: (published ? Colors.green : Colors.orange).withOpacity(0.15),
                                        ),
                                        child: Icon(
                                          published ? Icons.public : Icons.edit,
                                          color: published ? Colors.green : Colors.orange,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title.isEmpty ? 'Impact Post' : title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$type • $date',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _openEditDialog(existing: p);
                                          } else if (value == 'delete') {
                                            _deletePost(p);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Page $_page / $_totalPages', style: const TextStyle(color: Colors.grey)),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                IconButton(
                                  onPressed: _page < _totalPages ? () => _load(page: _page + 1) : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
