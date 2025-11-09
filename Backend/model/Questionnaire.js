const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const Child = require('./Child');

const Questionnaire = sequelize.define('Questionnaire', {
  questionnaire_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  parent_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true 
  },
  title: {
    type: DataTypes.STRING(255),
    allowNull: false
  },
  type: {
    type: DataTypes.ENUM('Initial Screening', 'Follow Up', 'Specialized'),
    defaultValue: 'Initial Screening'
  },
  status: {
    type: DataTypes.ENUM('In Progress', 'Completed', 'Analyzed'),
    defaultValue: 'In Progress'
  },
  responses: {
    type: DataTypes.JSON,
    allowNull: true
  },
  results: {
    type: DataTypes.JSON,
    allowNull: true
  },
  ai_analysis: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  risk_level: {
    type: DataTypes.ENUM('Low', 'Medium', 'High'),
    allowNull: true
  },
  suggested_conditions: {
    type: DataTypes.JSON,
    allowNull: true
  },
  recommendations: {
    type: DataTypes.JSON,
    allowNull: true
  },
  completed_at: {
    type: DataTypes.DATE,
    allowNull: true
  }
}, {
  tableName: 'Questionnaires',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

Questionnaire.belongsTo(User, { foreignKey: 'parent_id' });
Questionnaire.belongsTo(Child, { foreignKey: 'child_id' });

module.exports = Questionnaire; 