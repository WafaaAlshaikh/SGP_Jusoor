const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Post = sequelize.define('Post', {
  post_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true
  },
  user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  content: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  original_content: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  language: {
    type: DataTypes.STRING(10),
    defaultValue: 'en'
  },
  is_repost: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  original_post_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  media_url: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  media_type: {
    type: DataTypes.ENUM('image', 'video', 'document'),
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('active', 'deleted'),
    defaultValue: 'active'
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
  tableName: 'Posts',
  timestamps: false
});

module.exports = Post;