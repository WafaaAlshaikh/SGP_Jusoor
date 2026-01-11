const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const TempActivityAnalysis = sequelize.define('TempActivityAnalysis', {
  analysis_id: {
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
  document_data: {
    type: DataTypes.JSON,
    allowNull: true
  },
  extracted_text: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('uploaded', 'analyzing', 'completed', 'failed'),
    defaultValue: 'uploaded'
  },
  expires_at: {
    type: DataTypes.DATE,
    defaultValue: () => new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 ساعة
  }
}, {
  tableName: 'temp_activity_analysis',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = TempActivityAnalysis;