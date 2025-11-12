const CommunityPost = require('../model/CommunityPost');
const sequelize = require('../config/db');

// Get all community posts with user information
exports.getPosts = async (req, res) => {
  try {
    const { limit = 10 } = req.query;

    const posts = await sequelize.query(`
      SELECT 
        cp.post_id,
        cp.content,
        cp.created_at,
        cp.updated_at,
        u.user_id,
        u.full_name as user_name,
        u.role as user_role,
        COALESCE((SELECT COUNT(*) FROM Likes WHERE post_id = cp.post_id), 0) as likes_count,
        COALESCE((SELECT COUNT(*) FROM Comments WHERE post_id = cp.post_id), 0) as comments_count
      FROM Posts cp
      JOIN Users u ON cp.user_id = u.user_id
      WHERE cp.status = 'active'
      ORDER BY cp.created_at DESC
      LIMIT ?
    `, {
      replacements: [parseInt(limit)],
      type: sequelize.QueryTypes.SELECT
    });

    res.status(200).json({
      success: true,
      count: posts.length,
      data: posts
    });
  } catch (error) {
    console.error('Error fetching community posts:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// Create a new post
exports.createPost = async (req, res) => {
  try {
    const { content } = req.body;
    const userId = req.user.userId;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({ message: 'Post content is required' });
    }

    const newPost = await CommunityPost.create({
      user_id: userId,
      content: content.trim()
    });

    res.status(201).json({
      success: true,
      message: 'Post created successfully',
      post: newPost
    });
  } catch (error) {
    console.error('Error creating post:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// Like a post
exports.likePost = async (req, res) => {
  try {
    const { postId } = req.params;

    const post = await CommunityPost.findByPk(postId);
    if (!post) {
      return res.status(404).json({ message: 'Post not found' });
    }

    await post.increment('likes_count');

    res.status(200).json({
      success: true,
      message: 'Post liked',
      likes_count: post.likes_count + 1
    });
  } catch (error) {
    console.error('Error liking post:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

module.exports = exports;
