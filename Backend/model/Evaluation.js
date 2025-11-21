// في ملف Evaluation.js - تحديث النموذج
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Child = require('./Child');
const Specialist = require('./Specialist');

const Evaluation = sequelize.define('Evaluation', {
  evaluation_id: { 
    type: DataTypes.INTEGER, 
    primaryKey: true, 
    autoIncrement: true 
  },
  child_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: false
  },
  specialist_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: false
  },
  evaluation_type: { 
    type: DataTypes.ENUM('Initial', 'Mid', 'Final', 'Follow-up'), 
    defaultValue: 'Initial' 
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  progress_score: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: true
  },
  attachment: {
    type: DataTypes.STRING(500),
    allowNull: true
  },
  // ✅ الحقول الجديدة
  analyzed_sessions: {
    type: DataTypes.JSON, // ['Speech', 'Occupational'] - أنواع الجلسات المطلوبة
    allowNull: true
  },
  ai_analysis: {
    type: DataTypes.TEXT, // التحليل النصي من الـ AI
    allowNull: true
  },
  auto_scheduled: {
    type: DataTypes.BOOLEAN, // هل تم الجدولة التلقائية؟
    defaultValue: false
  },
  created_at: { 
    type: DataTypes.DATE, 
    defaultValue: DataTypes.NOW 
  }
}, {
  tableName: 'Evaluations',
  timestamps: false
});

Evaluation.belongsTo(Child, { foreignKey: 'child_id' });
Evaluation.belongsTo(Specialist, { foreignKey: 'specialist_id' });

module.exports = Evaluation;