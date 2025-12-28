// models/SystemSettings.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const SystemSettings = sequelize.define('SystemSettings', {
  setting_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  setting_key: {
    type: DataTypes.STRING(100),
    unique: true,
    allowNull: false
  },
  setting_value: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  setting_type: {
    type: DataTypes.ENUM('string', 'number', 'boolean', 'json', 'array'),
    defaultValue: 'string'
  },
  category: {
    type: DataTypes.STRING(50),
    defaultValue: 'general'
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  is_editable: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  updated_by: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'SystemSettings',
  timestamps: false
});

module.exports = SystemSettings;    