const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const CommunityPost = sequelize.define('CommunityPost', {
  post_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true
  },
  user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: 'Users',
      key: 'user_id'
    }
  },
  content: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  likes_count: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  comments_count: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'CommunityPosts',
  timestamps: false
});

module.exports = CommunityPost;
