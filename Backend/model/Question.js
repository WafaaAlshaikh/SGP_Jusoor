const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Question = sequelize.define('Question', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  questionnaire_id: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  question_text: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  question_type: {
    type: DataTypes.ENUM('yes_no', 'scale', 'multiple_choice', 'performance'),
    defaultValue: 'yes_no'
  },
  options: DataTypes.JSON,
  risk_score: DataTypes.INTEGER,
  category: DataTypes.STRING,
  order: DataTypes.INTEGER,
  is_gateway: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  gateway_target: DataTypes.STRING
});

module.exports = Question;
