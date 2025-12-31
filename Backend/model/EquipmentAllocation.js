const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const EquipmentAllocation = sequelize.define('EquipmentAllocation', {
  allocation_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  inventory_item_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  need_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  allocation_mode: {
    type: DataTypes.ENUM('auto', 'manual'),
    defaultValue: 'manual'
  },
  allocated_by_user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  usage_type: {
    type: DataTypes.ENUM('child', 'internal'),
    allowNull: false
  },
  internal_department: {
    type: DataTypes.STRING(80),
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('pending_receipt', 'delivered', 'cancelled'),
    defaultValue: 'pending_receipt'
  },
  delivery_notes: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  parent_confirmed_at: {
    type: DataTypes.DATE,
    allowNull: true
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
  tableName: 'EquipmentAllocations',
  timestamps: false
});

module.exports = EquipmentAllocation;
