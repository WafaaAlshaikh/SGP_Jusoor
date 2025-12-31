const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const ChildEquipmentNeed = sequelize.define('ChildEquipmentNeed', {
  need_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  category_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  equipment_type: {
    type: DataTypes.STRING(120),
    allowNull: true
  },
  equipment_name: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  quantity_needed: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1
  },
  severity: {
    type: DataTypes.ENUM('low', 'medium', 'high'),
    defaultValue: 'medium'
  },
  reason: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  source: {
    type: DataTypes.ENUM('ai', 'specialist_manual', 'manager_manual'),
    defaultValue: 'specialist_manual'
  },
  created_from_evaluation_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  priority_score: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0
  },
  status: {
    type: DataTypes.ENUM('open', 'matched', 'allocated', 'delivered', 'cancelled'),
    defaultValue: 'open'
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'ChildEquipmentNeeds',
  timestamps: false
});

module.exports = ChildEquipmentNeed;
