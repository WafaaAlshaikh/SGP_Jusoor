// lib/screens/admin/content_moderation.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/admin_api_service.dart';

class ContentModeration extends StatefulWidget {
  @override
  _ContentModerationState createState() => _ContentModerationState();
}

class _ContentModerationState extends State<ContentModeration> {
  List<Map<String, dynamic>> _reportedContent = [];
  List<Map<String, dynamic>> _pendingReviews = [];
  bool _isLoading = true;
  
  final List<String> _contentTypes = [
    'post',
    'comment',
    'review',
    'message'
  ];

  @override
  void initState() {
    super.initState();
    _loadReportedContent();
    _loadPendingReviews();
  }

  Future<void> _loadReportedContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/moderation/reported-content'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _reportedContent = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading reported content: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingReviews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.get(
        Uri.parse('${AdminApiService.baseUrl}/moderation/pending-reviews'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _pendingReviews = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading pending reviews: $e');
    }
  }

  Future<void> _removeContent(String contentId, String contentType, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.post(
        Uri.parse('${AdminApiService.baseUrl}/moderate/remove'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'content_type': contentType,
          'content_id': contentId,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReportedContent();
        _loadPendingReviews();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove content'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _approveReview(String reviewId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.post(
        Uri.parse('${AdminApiService.baseUrl}/moderation/reviews/$reviewId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingReviews();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve review'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _dismissReports(String contentId, String contentType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // ✅ Fixed: Using AdminApiService.baseUrl
      final response = await http.post(
        Uri.parse('${AdminApiService.baseUrl}/moderation/dismiss-reports'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'content_type': contentType,
          'content_id': contentId,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reports dismissed successfully'),
            backgroundColor: Colors.blue,
          ),
        );
        _loadReportedContent();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dismiss reports'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildContentCard(Map<String, dynamic> content) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(content['user_name'][0]),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content['user_name'],
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _getContentTypeText(content['content_type']),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    '${content['report_count'] ?? 0} reports',
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.red[50],
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                content['content_preview'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            SizedBox(height: 12),
            
            if (content['reasons'] != null && content['reasons'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Reasons:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  ...content['reasons'].map<Widget>((reason) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text('• $reason'),
                    );
                  }).toList(),
                ],
              ),
            
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showRemoveDialog(
                        content['content_id'],
                        content['content_type'],
                      );
                    },
                    icon: Icon(Icons.delete, size: 18),
                    label: Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _dismissReports(
                        content['content_id'],
                        content['content_type'],
                      );
                    },
                    icon: Icon(Icons.check, size: 18),
                    label: Text('Keep'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveDialog(String contentId, String contentType) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter the reason for removal:'),
            SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Removal reason',
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                _removeContent(contentId, contentType, reasonController.text);
                Navigator.pop(context);
              }
            },
            child: Text('Remove'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getContentTypeText(String type) {
    switch (type) {
      case 'post': return 'Post';
      case 'comment': return 'Comment';
      case 'review': return 'Review';
      case 'message': return 'Message';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Content Moderation'),
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.flag), text: 'Reported Content'),
              Tab(icon: Icon(Icons.star), text: 'Pending Reviews'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadReportedContent();
                _loadPendingReviews();
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Reported Content Tab
                  _reportedContent.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flag, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No reported content',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'All content is clean!',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _reportedContent.length,
                          itemBuilder: (context, index) {
                            return _buildContentCard(_reportedContent[index]);
                          },
                        ),
                  
                  // Pending Reviews Tab
                  _pendingReviews.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No pending reviews',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'All reviews are moderated',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _pendingReviews.length,
                          itemBuilder: (context, index) {
                            return _buildReviewCard(_pendingReviews[index]);
                          },
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.orange),
                SizedBox(width: 4),
                Text(
                  review['rating'].toString(),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Chip(
                  label: Text(
                    _getContentTypeText(review['target_type']),
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.blue[50],
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            if (review['title'] != null && review['title'].isNotEmpty)
              Text(
                review['title'],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            
            if (review['comment'] != null && review['comment'].isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(review['comment']),
              ),
            
            SizedBox(height: 12),
            
            Text(
              'By: ${review['author_name']}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            
            if (review['created_at'] != null)
              Text(
                'Date: ${_formatDate(review['created_at'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _approveReview(review['review_id'].toString());
                    },
                    icon: Icon(Icons.check, size: 18),
                    label: Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showRemoveDialog(
                        review['review_id'].toString(),
                        'review',
                      );
                    },
                    icon: Icon(Icons.close, size: 18),
                    label: Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final parsed = DateTime.parse(date).toLocal();
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return date;
    }
  }
}