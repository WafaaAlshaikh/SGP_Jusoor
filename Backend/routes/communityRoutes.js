const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { Post, Comment, Like, User } = require('../model/index');
const TranslationService = require('../services/translationService');
const multer = require('multer');
const path = require('path');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/posts/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'post-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: function (req, file, cb) {
    const allowedTypes = /jpeg|jpg|png|gif|mp4|mov|avi|pdf|doc|docx/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Only images, videos and documents are allowed'));
    }
  }
});

// مسار واحد لإنشاء البوست يدعم جميع الأنواع
router.post('/posts', authMiddleware, upload.single('media'), async (req, res) => {
  try {
    const { content, media_type } = req.body;
    const user_id = req.user.user_id;

    // تحديد نوع المحتوى بناءً على الملف المرفوع أو البيانات المرسلة
    let mediaUrl = null;
    let finalMediaType = null;

    if (req.file) {
      mediaUrl = `/uploads/posts/${req.file.filename}`;
      
      // تحديد نوع الميديا تلقائياً من الملف
      const fileExt = path.extname(req.file.originalname).toLowerCase();
      if (['.mp4', '.mov', '.avi'].includes(fileExt)) {
        finalMediaType = 'video';
      } else if (['.jpg', '.jpeg', '.png', '.gif'].includes(fileExt)) {
        finalMediaType = 'image';
      } else if (['.pdf', '.doc', '.docx'].includes(fileExt)) {
        finalMediaType = 'document';
      } else {
        finalMediaType = media_type || 'file';
      }
    } else if (req.body.media_url) {
      // إذا كان فيه رابط ميديا موجود مسبقاً
      mediaUrl = req.body.media_url;
      finalMediaType = media_type || 'image';
    }

    // التأكد من وجود محتوى على الأقل (نص أو ميديا)
    if (!content && !mediaUrl) {
      return res.status(400).json({
        success: false,
        message: 'Post must contain either text or media'
      });
    }

    const post = await Post.create({
      user_id,
      content: content || null, // يمكن أن يكون نص أو null
      original_content: content || null,
      media_url: mediaUrl,
      media_type: finalMediaType
    });

    const postWithUser = await Post.findByPk(post.post_id, {
      include: [{ model: User, as: 'user', attributes: ['user_id', 'full_name', 'profile_picture', 'role'] }]
    });

    res.status(201).json({
      success: true,
      message: 'Post created successfully',
      data: postWithUser
    });
  } catch (error) {
    console.error('Error creating post:', error);
    res.status(500).json({
      success: false,
      message: 'Error creating post',
      error: error.message
    });
  }
});

// Get all posts (لجميع المستخدمين)
router.get('/posts', authMiddleware, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;

    const posts = await Post.findAndCountAll({
      where: { status: 'active' },
      include: [
        { 
          model: User, 
          as: 'user', 
          attributes: ['user_id', 'full_name', 'profile_picture', 'role'] 
        },
        {
          model: Comment,
          as: 'comments',
          where: { status: 'active' },
          required: false,
          include: [{
            model: User,
            as: 'user',
            attributes: ['user_id', 'full_name', 'profile_picture', 'role']
          }]
        },
        {
          model: Like,
          as: 'likes',
          include: [{
            model: User,
            as: 'user',
            attributes: ['user_id', 'full_name']
          }]
        },
        {
          model: Post,
          as: 'originalPost',
          include: [{
            model: User,
            as: 'user',
            attributes: ['user_id', 'full_name', 'profile_picture', 'role']
          }]
        }
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset
    });

    // ✅ NEW: إضافة عدد الريبوستات لكل بوست
    const postsWithRepostCount = await Promise.all(
      posts.rows.map(async (post) => {
        const repostCount = await Post.count({
          where: { 
            original_post_id: post.post_id,
            status: 'active'
          }
        });
        
        return {
          ...post.toJSON(),
          repost_count: repostCount
        };
      })
    );

    res.json({
      success: true,
      data: postsWithRepostCount,
      total: posts.count,
      page,
      totalPages: Math.ceil(posts.count / limit)
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching posts',
      error: error.message
    });
  }
});

// ✅ NEW: Get current user's posts only
router.get('/posts/my-posts', authMiddleware, async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;

    const posts = await Post.findAndCountAll({
      where: { 
        user_id: user_id,
        status: 'active' 
      },
      include: [
        { 
          model: User, 
          as: 'user', 
          attributes: ['user_id', 'full_name', 'profile_picture', 'role'] 
        },
        {
          model: Comment,
          as: 'comments',
          where: { status: 'active' },
          required: false,
          include: [{
            model: User,
            as: 'user',
            attributes: ['user_id', 'full_name', 'profile_picture', 'role']
          }]
        },
        {
          model: Like,
          as: 'likes',
          include: [{
            model: User,
            as: 'user',
            attributes: ['user_id', 'full_name']
          }]
        },
        {
          model: Post,
          as: 'originalPost',
          include: [{
            model: User,
            as: 'user',
            attributes: ['user_id', 'full_name', 'profile_picture', 'role']
          }]
        }
      ],
      order: [['created_at', 'DESC']],
      limit,
      offset
    });

    // ✅ NEW: إضافة عدد الريبوستات لكل بوست
    const postsWithRepostCount = await Promise.all(
      posts.rows.map(async (post) => {
        const repostCount = await Post.count({
          where: { 
            original_post_id: post.post_id,
            status: 'active'
          }
        });
        
        return {
          ...post.toJSON(),
          repost_count: repostCount
        };
      })
    );

    res.json({
      success: true,
      data: postsWithRepostCount,
      total: posts.count,
      page,
      totalPages: Math.ceil(posts.count / limit)
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching user posts',
      error: error.message
    });
  }
});

// Translate post
router.post('/posts/:id/translate', authMiddleware, async (req, res) => {
  try {
    const { targetLang } = req.body;
    const post = await Post.findByPk(req.params.id);

    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found'
      });
    }

    const translatedContent = await TranslationService.translateText(post.original_content, targetLang);

    res.json({
      success: true,
      data: {
        original_content: post.original_content,
        translated_content: translatedContent,
        original_language: post.language,
        target_language: targetLang
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error translating post',
      error: error.message
    });
  }
});

// Add comment
router.post('/posts/:id/comments', authMiddleware, async (req, res) => {
  try {
    const { content } = req.body;
    const user_id = req.user.user_id;
    const post_id = req.params.id;

    const comment = await Comment.create({
      post_id,
      user_id,
      content,
      original_content: content
    });

    const commentWithUser = await Comment.findByPk(comment.comment_id, {
      include: [{ model: User, as: 'user', attributes: ['user_id', 'full_name', 'profile_picture', 'role'] }]
    });

    res.status(201).json({
      success: true,
      message: 'Comment added successfully',
      data: commentWithUser
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error adding comment',
      error: error.message
    });
  }
});

// Like/unlike post
router.post('/posts/:id/like', authMiddleware, async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const post_id = req.params.id;

    const existingLike = await Like.findOne({
      where: { post_id, user_id }
    });

    if (existingLike) {
      await existingLike.destroy();
      res.json({
        success: true,
        message: 'Post unliked',
        liked: false
      });
    } else {
      await Like.create({ post_id, user_id });
      res.json({
        success: true,
        message: 'Post liked',
        liked: true
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating like',
      error: error.message
    });
  }
});

// Repost
router.post('/posts/:id/repost', authMiddleware, async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const original_post_id = req.params.id;
    const { comment } = req.body; // ✅ إضافة نص الريبوست

    const originalPost = await Post.findByPk(original_post_id);
    
    if (!originalPost) {
      return res.status(404).json({
        success: false,
        message: 'Original post not found'
      });
    }

    // ✅ NEW: إنشاء محتوى الريبوست الجديد
    let repostContent = '';
    
    if (comment && comment.trim() !== '') {
      // إذا في تعليق، اجمع المحتوى الأصلي + التعليق
      repostContent = `${comment}\n\n───\n${originalPost.content || ''}`;
    } else {
      // إذا ما في تعليق، استخدم المحتوى الأصلي
      repostContent = originalPost.content || '';
    }

    const repost = await Post.create({
      user_id,
      content: repostContent, // ✅ المحتوى الجديد
      original_content: originalPost.original_content,
      language: originalPost.language,
      is_repost: true,
      original_post_id,
      media_url: originalPost.media_url, // ✅ احتفظ بالميديا
      media_type: originalPost.media_type // ✅ احتفظ بنوع الميديا
    });

    const repostWithUser = await Post.findByPk(repost.post_id, {
      include: [
        { model: User, as: 'user', attributes: ['user_id', 'full_name', 'profile_picture', 'role'] },
        { model: Post, as: 'originalPost', include: [{ model: User, as: 'user' }] }
      ]
    });

    res.status(201).json({
      success: true,
      message: 'Post reposted successfully',
      data: repostWithUser
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error reposting',
      error: error.message
    });
  }
});

// ✅ Update post - بالفعل آمن (يعدل فقط بوستات اليوزر نفسه)
router.put('/posts/:id', authMiddleware, async (req, res) => {
  try {
    const { content } = req.body;
    const user_id = req.user.user_id;

    const post = await Post.findOne({
      where: { 
        post_id: req.params.id, 
        user_id: user_id  // ✅ هنا التأمين - بس بستطيع يعدل على بوستاته
      }
    });

    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found or unauthorized'
      });
    }

    await post.update({
      content,
      original_content: content,
      updated_at: new Date()
    });

    res.json({
      success: true,
      message: 'Post updated successfully',
      data: post
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating post',
      error: error.message
    });
  }
});

// ✅ Delete post - بالفعل آمن (يحذف فقط بوستات اليوزر نفسه)
router.delete('/posts/:id', authMiddleware, async (req, res) => {
  try {
    const user_id = req.user.user_id;

    const post = await Post.findOne({
      where: { 
        post_id: req.params.id, 
        user_id: user_id  // ✅ هنا التأمين - بس بستطيع يحذف بوستاته
      }
    });

    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found or unauthorized'
      });
    }

    await post.update({ status: 'deleted' });

    res.json({
      success: true,
      message: 'Post deleted successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error deleting post',
      error: error.message
    });
  }
});

// Delete comment
router.delete('/comments/:id', authMiddleware, async (req, res) => {
  try {
    const user_id = req.user.user_id;

    const comment = await Comment.findOne({
      where: { 
        comment_id: req.params.id, 
        user_id: user_id  // ✅ هنا التأمين - بس بستطيع يحذف تعليقاته
      }
    });

    if (!comment) {
      return res.status(404).json({
        success: false,
        message: 'Comment not found or unauthorized'
      });
    }

    await comment.update({ status: 'deleted' });

    res.json({
      success: true,
      message: 'Comment deleted successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error deleting comment',
      error: error.message
    });
  }
});

// ✅ NEW: Get repost count for a specific post
router.get('/posts/:id/repost-count', authMiddleware, async (req, res) => {
  try {
    const post_id = req.params.id;

    // التأكد من وجود البوست الأصلي
    const originalPost = await Post.findByPk(post_id);
    if (!originalPost) {
      return res.status(404).json({
        success: false,
        message: 'Post not found'
      });
    }

    // عد الريبوستات للبوست الأصلي
    const repostCount = await Post.count({
      where: { 
        original_post_id: post_id,
        status: 'active'
      }
    });

    res.json({
      success: true,
      data: {
        post_id: post_id,
        repost_count: repostCount
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching repost count',
      error: error.message
    });
  }
});

module.exports = router;