// Script to seed community posts with sample data
const sequelize = require('../config/db');
const { Post, User } = require('../model/index');

async function seedPosts() {
  try {
    await sequelize.sync();
    
    // Get some users (parents)
    const parents = await User.findAll({
      where: { role: 'parent' },
      limit: 3
    });

    if (parents.length === 0) {
      console.log('❌ No parents found. Please create parent users first.');
      process.exit(1);
    }

    const samplePosts = [
      {
        user_id: parents[0].user_id,
        content: 'New autism awareness event this Friday at Yasmeen Charity! Join us for valuable workshops and networking with other parents. Topics include behavioral strategies and early intervention techniques.',
        original_content: 'New autism awareness event this Friday at Yasmeen Charity! Join us for valuable workshops and networking with other parents. Topics include behavioral strategies and early intervention techniques.',
        status: 'active'
      },
      {
        user_id: parents[1]?.user_id || parents[0].user_id,
        content: 'Looking for recommendations for ADHD specialists in Amman. My son is 6 years old and we need someone experienced with children. Any suggestions from fellow parents?',
        original_content: 'Looking for recommendations for ADHD specialists in Amman. My son is 6 years old and we need someone experienced with children. Any suggestions from fellow parents?',
        status: 'active'
      },
      {
        user_id: parents[2]?.user_id || parents[0].user_id,
        content: 'Just wanted to share our progress! My daughter has been doing speech therapy for 3 months and we are seeing amazing improvements. Keep going everyone! 💪',
        original_content: 'Just wanted to share our progress! My daughter has been doing speech therapy for 3 months and we are seeing amazing improvements. Keep going everyone! 💪',
        status: 'active'
      },
      {
        user_id: parents[0].user_id,
        content: 'Does anyone have experience with sensory integration therapy? Looking for resources and recommendations in Irbid area.',
        original_content: 'Does anyone have experience with sensory integration therapy? Looking for resources and recommendations in Irbid area.',
        status: 'active'
      },
      {
        user_id: parents[1]?.user_id || parents[0].user_id,
        content: 'Great session at Bright Minds Learning Center today! The occupational therapist was fantastic with my son. Highly recommend! 🌟',
        original_content: 'Great session at Bright Minds Learning Center today! The occupational therapist was fantastic with my son. Highly recommend! 🌟',
        status: 'active'
      }
    ];

    for (const postData of samplePosts) {
      const [post, created] = await Post.findOrCreate({
        where: { 
          content: postData.content,
          user_id: postData.user_id
        },
        defaults: postData
      });

      if (created) {
        console.log(`✅ Created post by ${parents.find(p => p.user_id === postData.user_id)?.full_name}`);
      } else {
        console.log(`ℹ️ Post already exists`);
      }
    }

    console.log('\n🎉 Successfully seeded community posts!');
    console.log(`📊 Total posts: ${samplePosts.length}`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding posts:', error);
    process.exit(1);
  }
}

seedPosts();
