// models/AuditLog.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const AuditLog = sequelize.define('AuditLog', {
  log_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  admin_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  action_type: {
  type: DataTypes.STRING(50),
  allowNull: false
},

  target_type: {
    type: DataTypes.STRING(50),
    allowNull: false
  },
  target_id: {
  type: DataTypes.INTEGER,
  allowNull: true
},
  details: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  ip_address: {
    type: DataTypes.STRING(45),
    allowNull: true
  },
  user_agent: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'AuditLogs',
  timestamps: false,
  indexes: [
    { fields: ['admin_id'] },
    { fields: ['action_type'] },
    { fields: ['target_type', 'target_id'] },
    { fields: ['created_at'] }
  ]
});

module.exports = AuditLog;