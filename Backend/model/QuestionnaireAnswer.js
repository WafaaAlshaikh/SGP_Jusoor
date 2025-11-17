const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const QuestionnaireAnswer = sequelize.define('QuestionnaireAnswer', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  
  questionnaire_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'Questionnaires',
      key: 'id'
    }
  },
  
  // Question Info
  question_id: {
    type: DataTypes.STRING, // مثل: "Q1", "Q5", "ASD1"
    allowNull: false
  },
  
  section: {
    type: DataTypes.STRING, // demographics, general_screening, ASD_deep, etc.
    allowNull: false
  },
  
  category: {
    type: DataTypes.STRING, // social_communication, language, attention, etc.
    allowNull: true
  },
  
  // Answer Data
  answer_value: {
    type: DataTypes.STRING, // القيمة المختارة
    allowNull: true
  },
  
  answer_values: {
    type: DataTypes.JSON, // للأسئلة متعددة الخيارات
    allowNull: true
  },
  
  answer_text: {
    type: DataTypes.TEXT, // للإجابات النصية
    allowNull: true
  },
  
  // Scoring
  score: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },
  
  weight: {
    type: DataTypes.FLOAT,
    defaultValue: 1.0
  },
  
  // Metadata
  answered_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
  
}, {
  tableName: 'QuestionnaireAnswers',
  timestamps: true
});

module.exports = QuestionnaireAnswer;