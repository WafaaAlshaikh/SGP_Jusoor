const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const ReportMessage = sequelize.define('ReportMessage', {
  message_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  report_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  sender_type: {
    type: DataTypes.ENUM('user', 'manager', 'admin'),
    allowNull: false
  },
  sender_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  message: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'ReportMessages',
  timestamps: false
});

module.exports = ReportMessage;
