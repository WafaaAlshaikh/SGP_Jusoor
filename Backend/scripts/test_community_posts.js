// Quick test to check community posts
const sequelize = require('../config/db');

async function testPosts() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    const posts = await sequelize.query(`
      SELECT 
        cp.post_id,
        cp.content,
        cp.created_at,
        u.user_id,
        u.full_name as user_name,
        COALESCE((SELECT COUNT(*) FROM Likes WHERE post_id = cp.post_id), 0) as likes_count,
        COALESCE((SELECT COUNT(*) FROM Comments WHERE post_id = cp.post_id), 0) as comments_count
      FROM Posts cp
      JOIN Users u ON cp.user_id = u.user_id
      WHERE cp.status = 'active'
      ORDER BY cp.created_at DESC
      LIMIT 10
    `, {
      type: sequelize.QueryTypes.SELECT
    });

    console.log(`\n📊 Found ${posts.length} community posts:`);
    posts.forEach((post, idx) => {
      console.log(`\n${idx + 1}. ${post.user_name}`);
      console.log(`   Content: ${post.content.substring(0, 60)}...`);
      console.log(`   Likes: ${post.likes_count}, Comments: ${post.comments_count}`);
    });

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

testPosts();
