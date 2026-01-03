const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const ImpactPost = sequelize.define('ImpactPost', {
  post_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  campaign_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  equipment_campaign_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  need_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  type: {
    type: DataTypes.ENUM('success_story', 'update', 'video', 'tip', 'thank_you'),
    allowNull: false,
    defaultValue: 'update'
  },
  title: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  content: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  media_urls: {
    type: DataTypes.JSON,
    allowNull: true
  },
  cover_url: {
    type: DataTypes.STRING(500),
    allowNull: true
  },
  is_published: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true
  },
  published_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  created_by_user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
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
  tableName: 'ImpactPosts',
  timestamps: false,
  indexes: [
    { fields: ['institution_id'] },
    { fields: ['campaign_id'] },
    { fields: ['equipment_campaign_id'] },
    { fields: ['need_id'] },
    { fields: ['is_published'] },
    { fields: ['published_at'] }
  ]
});

module.exports = ImpactPost;
