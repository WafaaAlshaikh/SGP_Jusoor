const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const ActivityRecommendation = sequelize.define('ActivityRecommendation', {
  recommendation_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: 'Children',
      key: 'child_id'
    }
  },
  parent_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: 'Users',
      key: 'user_id'
    }
  },
  activity_type: {
    type: DataTypes.ENUM(
      'motor_skills',
      'social_skills', 
      'cognitive_skills',
      'communication_skills',
      'sensory_activities',
      'daily_living_skills'
    ),
    allowNull: false
  },
  title_ar: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  title_en: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  description_ar: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  description_en: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  materials_ar: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  materials_en: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  duration_minutes: {
    type: DataTypes.INTEGER,
    defaultValue: 10
  },
  difficulty_level: {
    type: DataTypes.ENUM('beginner', 'intermediate', 'advanced'),
    defaultValue: 'beginner'
  },
  ai_generated: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  based_on_document: {
    type: DataTypes.STRING(500),
    allowNull: true
  },
  document_analysis_summary: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  target_skills_ar: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  target_skills_en: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('suggested', 'in_progress', 'completed', 'skipped'),
    defaultValue: 'suggested'
  },
  completed_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  parent_rating: {
    type: DataTypes.INTEGER,
    allowNull: true,
    validate: { min: 1, max: 5 }
  },
  child_engagement: {
    type: DataTypes.ENUM('low', 'medium', 'high'),
    allowNull: true
  }
}, {
  tableName: 'activity_recommendations',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = ActivityRecommendation;