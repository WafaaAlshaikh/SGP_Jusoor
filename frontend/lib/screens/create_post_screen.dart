import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/community_service.dart';
import '../services/activity_service.dart';
import '../theme/app_colors.dart'; // ✅ استيراد الألوان الجديدة

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _postController = TextEditingController();
  File? _selectedMedia;
  final ImagePicker _picker = ImagePicker();
  bool _isCreatingPost = false;

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
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(icon, color: color, size: 20),
              onPressed: onPressed,
              padding: EdgeInsets.zero,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Create New Post',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
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
              icon: Icon(Icons.send, color: Colors.white, size: 22),
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
                color: AppColors.surface,
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
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Icon(Icons.person, color: AppColors.primary),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "What's on your mind?",
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, color: Colors.white, size: 16),
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
                      hintStyle: TextStyle(color: AppColors.textLight),
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 8,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
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
                        color: AppColors.success,
                      ),
                      _buildMediaButton(
                        icon: Icons.videocam,
                        label: 'Video',
                        onPressed: () {
                          _showErrorSnackBar('Video upload coming soon!');
                        },
                        color: AppColors.primary,
                      ),
                      _buildMediaButton(
                        icon: Icons.attach_file,
                        label: 'File',
                        onPressed: () {
                          _showErrorSnackBar('File upload coming soon!');
                        },
                        color: AppColors.warning,
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                ),
                child: _isCreatingPost
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Publishing...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Publish Post',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Tips for great posts:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Share helpful information\n• Be respectful to others\n• Add relevant images\n• Use clear language',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                      height: 1.5,
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