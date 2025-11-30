import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/community_service.dart';
import '../services/activity_service.dart';
import '../theme/app_colors.dart'; // ✅ استيراد الألوان الجديدة

class CommunityScreen extends StatefulWidget {
  @override
  _CommunityScreenState createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with TickerProviderStateMixin {

  TabController? _tabController;
  List<dynamic> _allPosts = [];
  List<dynamic> _myPosts = [];
  int _currentPage = 1;
  int _myPostsPage = 1;
  bool _isLoading = false;
  bool _isLoadingMyPosts = false;
  bool _hasMore = true;
  bool _hasMoreMyPosts = true;
  bool _isCreatingPost = false;

  final TextEditingController _postController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editPostController = TextEditingController();
  final TextEditingController _repostController = TextEditingController();
  File? _selectedMedia;
  final ImagePicker _picker = ImagePicker();

  // Animation controllers
  AnimationController? _createPostAnimation;
  AnimationController? _likeAnimation;
  Map<String, bool> _likedPosts = {};
  Map<String, bool> _isEditing = {};
  Map<String, bool> _showComments = {};

  @override
  void initState() {
    super.initState();
    _initializeController();
    _initializeAnimations();
    _loadInitialPosts();
  }

  void _initializeController() {
    _tabController = TabController(length: 2, vsync: this);
  }

  void _initializeAnimations() {
    _createPostAnimation = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _likeAnimation = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }

  Future<void> _loadInitialPosts() async {
    setState(() {
      _isLoading = true;
      _isLoadingMyPosts = true;
    });

    try {
      final allPostsResponse = await CommunityService.getAllPosts(page: 1);
      final myPostsResponse = await CommunityService.getMyPosts(page: 1);

      setState(() {
        _allPosts = allPostsResponse['data'] ?? [];
        _myPosts = myPostsResponse['data'] ?? [];
        _isLoading = false;
        _isLoadingMyPosts = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMyPosts = false;
      });
      _showErrorSnackBar('Failed to load posts: $e');
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.isEmpty && _selectedMedia == null) {
      _showErrorSnackBar('Post must contain text or media');
      return;
    }

    setState(() => _isCreatingPost = true);

    try {
      _createPostAnimation?.forward();

      await CommunityService.createPost(
        content: _postController.text,
        mediaFile: _selectedMedia,
        mediaType: _selectedMedia != null ? 'image' : null,
      );

      await Future.delayed(Duration(milliseconds: 500));
      _createPostAnimation?.reset();

      await ActivityService.addActivity(
          'New post shared in community',
          'post'
      );
      await _loadInitialPosts();

      _postController.clear();
      setState(() {
        _selectedMedia = null;
        _isCreatingPost = false;
      });

      _showSuccessSnackBar('Post created successfully 🎉');
    } catch (e) {
      setState(() => _isCreatingPost = false);
      _createPostAnimation?.reset();
      _showErrorSnackBar('Failed to create post: $e');
    }
  }

  Future<void> _repostWithText(String postId) async {
    final String? comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Repost',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Do you want to repost this post?',
              style: TextStyle(color: AppColors.textGray),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _repostController,
              decoration: InputDecoration(
                hintText: 'Add your comment... (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.accent2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: AppColors.textDark),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGray),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _repostController.text),
            child: Text(
              'Repost',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (comment != null) {
      try {
        await CommunityService.repost(postId, comment: comment.isNotEmpty ? comment : null);
        _repostController.clear();
        await _loadInitialPosts();

        if (comment.isNotEmpty) {
          _showSuccessSnackBar('Post reposted with comment 🔄💬');
        } else {
          _showSuccessSnackBar('Post reposted successfully 🔄');
        }
      } catch (e) {
        _showErrorSnackBar('Failed to repost: $e');
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    setState(() {
      _likedPosts[postId] = !(_likedPosts[postId] ?? false);
    });

    _likeAnimation?.forward(from: 0.0);

    try {
      await CommunityService.toggleLike(postId);
      await _loadInitialPosts();
    } catch (e) {
      setState(() {
        _likedPosts[postId] = !(_likedPosts[postId] ?? false);
      });
      _showErrorSnackBar('Failed to toggle like: $e');
    }
  }

  Future<void> _updatePost(String postId, String newContent) async {
    try {
      await CommunityService.updatePost(postId, newContent);
      await _loadInitialPosts();
      setState(() {
        _isEditing[postId] = false;
      });
      _showSuccessSnackBar('Post updated successfully ✏️');
    } catch (e) {
      _showErrorSnackBar('Failed to update post: $e');
    }
  }

  Future<void> _deletePost(String postId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Post',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await CommunityService.deletePost(postId);
        await _loadInitialPosts();
        _showSuccessSnackBar('Post deleted successfully 🗑️');
      } catch (e) {
        _showErrorSnackBar('Failed to delete post: $e');
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Comment',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await CommunityService.deleteComment(commentId);
        await _loadInitialPosts();
        _showSuccessSnackBar('Comment deleted successfully 🗑️');
      } catch (e) {
        _showErrorSnackBar('Failed to delete comment: $e');
      }
    }
  }

  String _getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    if (url.startsWith('/uploads/')) {
      return 'http://10.0.2.2:5000$url';
    }

    return url;
  }

  Widget _buildCreatePostWidget() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.all(16),
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

          SizedBox(height: 16),
          TextField(
            controller: _postController,
            decoration: InputDecoration(
              hintText: "Share your thoughts...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: AppColors.textLight),
            ),
            maxLines: 3,
            style: TextStyle(fontSize: 16, color: AppColors.textDark),
          ),

          SizedBox(height: 16),
          Row(
            children: [
              _buildMediaButton(
                icon: Icons.photo_library,
                label: 'Photo',
                onPressed: _pickImage,
                color: AppColors.success,
              ),
              _buildMediaButton(
                icon: Icons.videocam,
                label: 'Video',
                onPressed: () {},
                color: AppColors.primary,
              ),
              _buildMediaButton(
                icon: Icons.attach_file,
                label: 'File',
                onPressed: () {},
                color: AppColors.warning,
              ),
              Spacer(),
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                child: _isCreatingPost
                    ? CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                )
                    : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _createPost,
                      borderRadius: BorderRadius.circular(25),
                      child: IntrinsicWidth(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ScaleTransition(
                                scale: _createPostAnimation ?? AnimationController(
                                  vsync: this,
                                  duration: Duration(milliseconds: 300),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 0,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add Post',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
            width: 40,
            height: 40,
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

  Widget _buildPostWidget(dynamic post, {bool isMyPost = false}) {
    if (post == null) return SizedBox.shrink();

    final user = post['user'] ?? {};
    final comments = (post['comments'] as List<dynamic>?) ?? [];
    final likes = (post['likes'] as List<dynamic>?) ?? [];
    final postId = post['post_id']?.toString() ?? 'unknown';
    final createdAt = post['created_at']?.toString() ?? '';
    final content = post['content']?.toString() ?? '';
    final mediaUrl = post['media_url']?.toString();
    final isRepost = post['is_repost'] ?? false;
    final originalPost = post['originalPost'] ?? {};
    final repostCount = post['repost_count'] ?? 0;

    final isLiked = _likedPosts[postId] ??
        likes.any((like) => (like['user']?['user_id'] ?? '') == 'current_user_id');

    final isEditing = _isEditing[postId] ?? false;
    final showComments = _showComments[postId] ?? false;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: user['profile_picture'] != null
                        ? NetworkImage(_getImageUrl(user['profile_picture']))
                        : null,
                    child: user['profile_picture'] == null
                        ? Icon(Icons.person, color: Colors.white)
                        : null,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['full_name']?.toString() ?? 'Unknown User',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMyPost && !isEditing) _buildPostMenu(postId, content),
                ],
              ),
            ),

            // Repost Indicator
            if (isRepost && originalPost.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Reposted',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            if (content.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isRepost && originalPost.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (content.contains('───'))
                            Text(
                              content.split('───')[0].trim(),
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                          if (content.contains('───')) SizedBox(height: 12),

                          // Original Post
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accent2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Original User Info
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: originalPost['user']?['profile_picture'] != null
                                          ? NetworkImage(_getImageUrl(originalPost['user']?['profile_picture']))
                                          : null,
                                      child: originalPost['user']?['profile_picture'] == null
                                          ? Icon(Icons.person, size: 14, color: Colors.white)
                                          : null,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            originalPost['user']?['full_name']?.toString() ?? 'Unknown User',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            _formatDate(originalPost['created_at']?.toString() ?? ''),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),

                                // Original Content
                                if (originalPost['content'] != null && originalPost['content'].toString().isNotEmpty)
                                  Text(
                                    content.contains('───')
                                        ? content.split('───')[1].trim()
                                        : content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: AppColors.textGray,
                                    ),
                                  ),

                                // Original Media
                                if (originalPost['media_url'] != null && originalPost['media_url'].toString().isNotEmpty)
                                  Container(
                                    margin: EdgeInsets.only(top: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        _getImageUrl(originalPost['media_url']),
                                        width: double.infinity,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            height: 120,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                    : null,
                                                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 120,
                                            color: AppColors.accent1,
                                            child: Center(
                                              child: Icon(Icons.error, color: AppColors.textLight),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      isEditing
                          ? TextField(
                        controller: _editPostController..text = content,
                        maxLines: null,
                        style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.textDark),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      )
                          : Text(
                        content,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: AppColors.textDark,
                        ),
                      ),

                    // Edit Buttons
                    if (isEditing) ...[
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _updatePost(postId, _editPostController.text);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing[postId] = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textGray,
                                side: BorderSide(color: AppColors.textLight),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                    ],
                  ],
                ),
              ),

            // Media
            if (mediaUrl != null && mediaUrl.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 12),
                child: ClipRRect(
                  child: Image.network(
                    _getImageUrl(mediaUrl),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: AppColors.accent1,
                        child: Center(
                          child: Icon(Icons.error, color: AppColors.textLight),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Stats
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildStatItem(
                    icon: Icons.thumb_up,
                    count: likes.length,
                    color: AppColors.info,
                  ),
                  SizedBox(width: 16),
                  _buildStatItem(
                    icon: Icons.comment,
                    count: comments.length,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 16),
                  _buildStatItem(
                    icon: Icons.repeat,
                    count: repostCount,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.thumb_up,
                      label: 'Like',
                      isActive: isLiked,
                      onPressed: () => _toggleLike(postId),
                    ),
                  ),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.comment,
                      label: 'Comment',
                      onPressed: () => _toggleComments(postId),
                    ),
                  ),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.repeat,
                      label: 'Repost',
                      onPressed: () => _repostWithText(postId),
                    ),
                  ),
                ],
              ),
            ),

            // Comments Section
            if (showComments)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    top: BorderSide(color: AppColors.accent2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (comments.isNotEmpty) ...[
                      Text(
                        'Comments (${comments.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...comments.map((comment) =>
                          _buildCommentWidget(comment, isMyPost: isMyPost)).toList(),
                      SizedBox(height: 16),
                    ],

                    // Comment Input
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: AppColors.textLight),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              maxLines: null,
                              style: TextStyle(fontSize: 14, color: AppColors.textDark),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            child: FloatingActionButton(
                              onPressed: () => _addComment(postId),
                              mini: true,
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
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

  void _toggleComments(String postId) {
    setState(() {
      _showComments[postId] = !(_showComments[postId] ?? false);
    });
  }

  Widget _buildPostMenu(String postId, String currentContent) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppColors.textLight),
      onSelected: (value) async {
        if (value == 'edit') {
          setState(() {
            _isEditing[postId] = true;
            _editPostController.text = currentContent;
          });
        } else if (value == 'delete') {
          _deletePost(postId);
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: AppColors.error, size: 18),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  Widget _buildStatItem({required IconData icon, required int count, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 6),
        Text(
          _formatCount(count),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? AppColors.primary : AppColors.textLight,
              ),
              SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? AppColors.primary : AppColors.textLight,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentWidget(dynamic comment, {bool isMyPost = false}) {
    if (comment == null) return SizedBox.shrink();

    final user = comment['user'] ?? {};
    final commentContent = comment['content']?.toString() ?? '';
    final commentId = comment['comment_id']?.toString() ?? 'unknown';
    final isMyComment = comment['user_id']?.toString() == 'current_user_id';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: user['profile_picture'] != null
                ? NetworkImage(_getImageUrl(user['profile_picture']))
                : null,
            child: user['profile_picture'] == null
                ? Icon(Icons.person, size: 14, color: Colors.white)
                : null,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['full_name']?.toString() ?? 'Unknown User',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (isMyPost || isMyComment)
                        GestureDetector(
                          onTap: () => _deleteComment(commentId),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.accent2,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, size: 12, color: AppColors.textLight),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    commentContent,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedMedia = File(image.path);
      });
    }
  }

  Future<void> _addComment(String postId) async {
    if (_commentController.text.isEmpty) return;

    try {
      await CommunityService.addComment(postId, _commentController.text);
      _commentController.clear();
      await _loadInitialPosts();
      _showSuccessSnackBar('Comment added successfully 💬');
    } catch (e) {
      _showErrorSnackBar('Failed to add comment: $e');
    }
  }

  Future<void> _repost(String postId) async {
    try {
      await CommunityService.repost(postId);
      await _loadInitialPosts();
      _showSuccessSnackBar('Post reposted successfully 🔄');
    } catch (e) {
      _showErrorSnackBar('Failed to repost: $e');
    }
  }

  String _formatDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'Unknown time';

      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now().toLocal();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';

      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown time';
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

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Loading posts...',
            style: TextStyle(
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article, size: 64, color: AppColors.textLight),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null || _createPostAnimation == null || _likeAnimation == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Community',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: 'All Posts'),
            Tab(text: 'My Posts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _loadInitialPosts,
            backgroundColor: AppColors.background,
            color: AppColors.primary,
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                _buildCreatePostWidget(),

                if (_isLoading && _allPosts.isEmpty)
                  _buildLoadingIndicator(),

                if (_allPosts.isEmpty && !_isLoading)
                  _buildEmptyState('No posts yet\nBe the first to share something!'),

                ..._allPosts.where((post) {
                  final user = post['user'] ?? {};
                  final userId = user['user_id']?.toString();
                  return userId != 'current_user_id';
                }).map((post) => _buildPostWidget(post, isMyPost: false)),

                if (_isLoading && _allPosts.isNotEmpty)
                  _buildLoadingIndicator(),

                if (!_hasMore && _allPosts.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No more posts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          RefreshIndicator(
            onRefresh: _loadInitialPosts,
            backgroundColor: AppColors.background,
            color: AppColors.primary,
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                if (_isLoadingMyPosts && _myPosts.isEmpty)
                  _buildLoadingIndicator(),

                if (_myPosts.isEmpty && !_isLoadingMyPosts)
                  _buildEmptyState('You haven\'t posted anything yet\nStart sharing your thoughts!'),

                ..._myPosts.map((post) => _buildPostWidget(post, isMyPost: true)),

                if (_isLoadingMyPosts && _myPosts.isNotEmpty)
                  _buildLoadingIndicator(),

                if (!_hasMoreMyPosts && _myPosts.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No more posts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _createPostAnimation?.dispose();
    _likeAnimation?.dispose();
    _postController.dispose();
    _commentController.dispose();
    _editPostController.dispose();
    _repostController.dispose();
    super.dispose();
  }
}