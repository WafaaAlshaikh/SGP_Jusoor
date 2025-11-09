const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const AISpecialistInsight = sequelize.define('AISpecialistInsight', {
  insight_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  specialist_id: { type: DataTypes.INTEGER, allowNull: false },
  child_id: { type: DataTypes.INTEGER },
  type: { type: DataTypes.ENUM('Content Suggestion', 'Feedback Analysis', 'Sentiment Analysis'), defaultValue: 'Content Suggestion' },
  text: { type: DataTypes.TEXT, allowNull: false },
  sentiment: { type: DataTypes.ENUM('Positive', 'Neutral', 'Negative'), defaultValue: 'Neutral' },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW }
});

module.exports = AISpecialistInsight;