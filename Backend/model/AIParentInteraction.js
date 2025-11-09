const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const AIParentInteraction = sequelize.define('AIParentInteraction', {
  interaction_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  parent_id: { type: DataTypes.INTEGER, allowNull: false },
  child_id: { type: DataTypes.INTEGER },
  question_text: { type: DataTypes.TEXT, allowNull: false },
  answer_text: DataTypes.TEXT,
  recommendation_type: { 
    type: DataTypes.ENUM('Article', 'Video', 'Activity', 'Institution'),
    defaultValue: 'Article'
  },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW }
});

module.exports = AIParentInteraction;