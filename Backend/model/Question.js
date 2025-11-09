const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Question = sequelize.define('Question', {
  question_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  category: {
    type: DataTypes.ENUM(
      'Attention & Focus',
      'Social Interaction', 
      'Communication',
      'Behavior Patterns',
      'Motor Skills',
      'Academic Performance',
      'Daily Living Skills'
    ),
    allowNull: false
  },
  question_text: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  question_type: {
    type: DataTypes.ENUM('Multiple Choice', 'Scale', 'Yes/No', 'Text'),
    defaultValue: 'Multiple Choice'
  },
  options: {
    type: DataTypes.JSON,
    allowNull: true // {options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Always']}
  },
  weight: {
    type: DataTypes.DECIMAL(3, 2),
    defaultValue: 1.0
  },
  target_conditions: {
    type: DataTypes.JSON,
    allowNull: true // ['ADHD', 'ASD', 'Speech Delay']
  },
  next_question_logic: {
    type: DataTypes.JSON,
    allowNull: true 
  },
  min_age: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  max_age: {
    type: DataTypes.INTEGER,
    defaultValue: 18
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
}, {
  tableName: 'Questions',
  timestamps: true
});

module.exports = Question;