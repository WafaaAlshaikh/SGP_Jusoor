const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Questionnaire = sequelize.define('Questionnaire', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  
  // Foreign Keys
  parent_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: 'Users',
      key: 'user_id'
    }
  },
  
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true, // قد يكون الاستبيان قبل تسجيل الطفل
    references: {
      model: 'Children',
      key: 'child_id'
    }
  },
  
  // Assessment Info
  assessment_date: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  
  status: {
    type: DataTypes.ENUM('in_progress', 'completed', 'expired'),
    defaultValue: 'in_progress'
  },
  
  current_section: {
    type: DataTypes.STRING,
    defaultValue: 'demographics' // demographics, general_screening, conditional
  },
  
  // Demographics Data (JSON)
  demographics: {
    type: DataTypes.JSON,
    defaultValue: {}
  },
  
  // General Screening Answers (JSON)
  general_answers: {
    type: DataTypes.JSON,
    defaultValue: {}
  },
  
  // Conditional Section Answers (JSON)
  conditional_answers: {
    type: DataTypes.JSON,
    defaultValue: {
      ASD: {},
      ADHD: {},
      Speech: {},
      Down: {}
    }
  },
  
  // Scores
  scores: {
    type: DataTypes.JSON,
    defaultValue: {
      ASD: { general: 0, conditional: 0, total: 0, percentage: 0 },
      ADHD: { general: 0, conditional: 0, total: 0, percentage: 0 },
      Speech: { general: 0, conditional: 0, total: 0, percentage: 0 },
      Down: { general: 0, conditional: 0, total: 0, percentage: 0 }
    }
  },
  
  // Results
  primary_concern: {
    type: DataTypes.ENUM('ASD', 'ADHD', 'Speech', 'Down', 'None'),
    allowNull: true
  },
  
  risk_level: {
    type: DataTypes.ENUM('very_low', 'low', 'medium', 'high', 'very_high'),
    allowNull: true
  },
  
  urgency_level: {
    type: DataTypes.ENUM('low_concern', 'monitor', 'soon', 'immediate'),
    allowNull: true
  },
  
  // Recommendations
  recommendations: {
    type: DataTypes.JSON,
    allowNull: true
  },
  
  // Metadata
  time_taken_seconds: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  
  total_questions_asked: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  
  notes: {
    type: DataTypes.TEXT,
    allowNull: true
  }
  
}, {
  tableName: 'Questionnaires',
  timestamps: true
});

module.exports = Questionnaire;