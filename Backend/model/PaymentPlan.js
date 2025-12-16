// models/PaymentPlan.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const PaymentPlan = sequelize.define('PaymentPlan', {
  plan_id: {
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
    allowNull: false
  },
  financial_assistance_request_id: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  total_amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false
  },
  down_payment: {
    type: DataTypes.DECIMAL(12, 2),
    defaultValue: 0
  },
  remaining_amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false
  },
  installment_count: {
    type: DataTypes.INTEGER,
    defaultValue: 1,
    validate: {
      min: 1,
      max: 12
    }
  },
  installment_amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false
  },
  payment_frequency: {
    type: DataTypes.ENUM('weekly', 'biweekly', 'monthly'),
    defaultValue: 'monthly'
  },
  start_date: {
    type: DataTypes.DATE,
    allowNull: false
  },
  status: {
    type: DataTypes.ENUM(
      'active',
      'completed',
      'defaulted',
      'cancelled',
      'on_hold'
    ),
    defaultValue: 'active'
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true
  }
}, {
  tableName: 'PaymentPlans',
  timestamps: true
});

module.exports = PaymentPlan;