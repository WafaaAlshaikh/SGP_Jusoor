// models/QuestionnaireResponse.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const QuestionnaireResponse = sequelize.define('QuestionnaireResponse', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  parent_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  // إزالة child_id لأنو ما بنعرف الطفل
  child_age: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  child_gender: {
    type: DataTypes.ENUM('male', 'female'),
    allowNull: true
  },
  questionnaire_type: {
    type: DataTypes.ENUM('ASD', 'ADHD', 'COMBINED'),
    allowNull: false
  },
  responses: DataTypes.JSON, // {question_id: answer, ...}
  scores: DataTypes.JSON, // {asd_score: 5, adhd_score: 3, ...}
  result: DataTypes.JSON, // {risk_level: 'high', recommendations: []}
  screening_path: DataTypes.JSON, // المسار الذي سلكه المستخدم
  is_anonymous: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
});

module.exports = QuestionnaireResponse;