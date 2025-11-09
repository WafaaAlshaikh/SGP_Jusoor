import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/community_service.dart';
import '../services/activity_service.dart';
class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _postController = TextEditingController();
  File? _selectedMedia;
  final ImagePicker _picker = ImagePicker();
  bool _isCreatingPost = false;

  // الألوان البنفسجية للثيم
  static const Color primaryColor = Color(0xFF7815A0);
  static const Color primaryLight = Color(0xFF9F7AEA);
  static const Color backgroundColor = Color(0xFFFAF5FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF2D3748);

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    if (_postController.text.isEmpty && _selectedMedia == null) {
      _showErrorSnackBar('Post must contain text or media');
      return;
    }

    setState(() => _isCreatingPost = true);

    try {
      await CommunityService.createPost(
        content: _postController.text,
        mediaFile: _selectedMedia,
        mediaType: _selectedMedia != null ? 'image' : null,
      );

      _postController.clear();
      setState(() {
        _selectedMedia = null;
        _isCreatingPost = false;
      });

      await ActivityService.addActivity(
          'New post shared in community',
          'post'
      );

      _showSuccessSnackBar('Post created successfully 🎉');

      // العودة للصفحة السابقة بعد النشر
      Navigator.pop(context);

    } catch (e) {
      setState(() => _isCreatingPost = false);
      _showErrorSnackBar('Failed to create post: $e');
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedMedia = File(image.path);
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.only(right: 12),
      child: Column(
        children: [
          IconButton(
            icon: Icon(icon, color: color),
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: color.withOpacity(0.1),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Create New Post',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: _isCreatingPost
                ? CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            )
                : IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _createPost,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Create Post Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: primaryLight.withOpacity(0.2),
                        child: Icon(Icons.person, color: primaryColor),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "What's on your mind?",
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Media Preview
                  if (_selectedMedia != null) ...[
                    SizedBox(height: 16),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedMedia!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMedia = null),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Text Input
                  SizedBox(height: 16),
                  TextField(
                    controller: _postController,
                    decoration: InputDecoration(
                      hintText: "Share your thoughts...",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[400]),
                    ),
                    maxLines: 8,
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),

                  // Actions Row
                  SizedBox(height: 16),
                  Row(
                    children: [
                      // Media Buttons
                      _buildMediaButton(
                        icon: Icons.photo_library,
                        label: 'Photo',
                        onPressed: _pickImage,
                        color: Colors.green,
                      ),
                      _buildMediaButton(
                        icon: Icons.videocam,
                        label: 'Video',
                        onPressed: () {
                          // يمكنك إضافة اختيار الفيديو لاحقاً
                          _showErrorSnackBar('Video upload coming soon!');
                        },
                        color: primaryColor,
                      ),
                      _buildMediaButton(
                        icon: Icons.attach_file,
                        label: 'File',
                        onPressed: () {
                          // يمكنك إضافة رفع الملفات لاحقاً
                          _showErrorSnackBar('File upload coming soon!');
                        },
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Publish Button
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreatingPost ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isCreatingPost
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Publishing...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                    : Text(
                  'Publish Post',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Tips
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 8),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Tips for great posts:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Share helpful information\n• Be respectful to others\n• Add relevant images\n• Use clear language',
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}