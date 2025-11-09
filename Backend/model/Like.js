const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Like = sequelize.define('Like', {
  like_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true
  },
  post_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  comment_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'Likes',
  timestamps: false
});

module.exports = Like;