const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const AIRecommendation = sequelize.define('AIRecommendation', {
  recommendation_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  child_id: { type: DataTypes.INTEGER, allowNull: false },
  type: { type: DataTypes.ENUM('Daily Tip', 'Progress Alert'), defaultValue: 'Daily Tip' },
  text: { type: DataTypes.TEXT, allowNull: false },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW }
});

module.exports = AIRecommendation;