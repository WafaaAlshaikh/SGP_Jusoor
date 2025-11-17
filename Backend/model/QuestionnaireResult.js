const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const QuestionnaireResult = sequelize.define('QuestionnaireResult', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  
  questionnaire_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    unique: true,
    references: {
      model: 'Questionnaires',
      key: 'id'
    }
  },
  
  // Detailed Scores
  asd_score: {
    type: DataTypes.JSON,
    defaultValue: {
      general: 0,
      conditional: 0,
      total: 0,
      max: 58,
      percentage: 0,
      risk_level: 'low',
      key_findings: [],
      positive_signs: []
    }
  },
  
  adhd_score: {
    type: DataTypes.JSON,
    defaultValue: {
      general: 0,
      conditional: 0,
      total: 0,
      max: 57,
      percentage: 0,
      risk_level: 'low',
      inattention_count: 0,
      hyperactivity_count: 0,
      type: null // predominantly_inattentive, hyperactive, combined
    }
  },
  
  speech_score: {
    type: DataTypes.JSON,
    defaultValue: {
      general: 0,
      conditional: 0,
      total: 0,
      max: 57,
      percentage: 0,
      risk_level: 'low',
      breakdown: {
        receptive: 0,
        expressive: 0,
        articulation: 0,
        pragmatic: 0
      }
    }
  },
  
  down_score: {
    type: DataTypes.JSON,
    defaultValue: {
      general: 0,
      conditional: 0,
      total: 0,
      max: 45,
      percentage: 0,
      risk_level: 'very_low',
      physical_signs_count: 0,
      medical_diagnosis: null
    }
  },
  
  // Primary Findings
  primary_concern: {
    type: DataTypes.STRING,
    allowNull: true
  },
  
  secondary_concern: {
    type: DataTypes.STRING,
    allowNull: true
  },
  
  confidence_level: {
    type: DataTypes.STRING,
    allowNull: true
  },
  
  // Red Flags & Positive Indicators
  red_flags: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  
  positive_indicators: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  
  // Recommendations
  immediate_actions: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  
  follow_up_actions: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  
  home_strategies: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  
  specialist_referrals: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  
  // Report
  report_pdf_url: {
    type: DataTypes.STRING,
    allowNull: true
  },
  
  shared_with_specialist: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  
  specialist_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true,
    references: {
      model: 'Specialists',
      key: 'specialist_id'
    }
  }
  
}, {
  tableName: 'QuestionnaireResults',
  timestamps: true
});

module.exports = QuestionnaireResult;
