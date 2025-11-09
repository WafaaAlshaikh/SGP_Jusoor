const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Comment = sequelize.define('Comment', {
  comment_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true
  },
  post_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
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
  tableName: 'Comments',
  timestamps: false
});

module.exports = Comment;