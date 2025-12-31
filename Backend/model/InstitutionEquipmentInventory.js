const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const InstitutionEquipmentInventory = sequelize.define('InstitutionEquipmentInventory', {
  inventory_item_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  category_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  equipment_name: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  equipment_type: {
    type: DataTypes.STRING(120),
    allowNull: true
  },
  condition: {
    type: DataTypes.ENUM('new', 'used_good', 'used_fair', 'needs_repair'),
    defaultValue: 'used_good'
  },
  quantity_available: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1
  },
  quantity_reserved: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0
  },
  usage_type: {
    type: DataTypes.ENUM('available', 'reserved', 'assigned', 'internal', 'out_of_service'),
    defaultValue: 'available'
  },
  internal_department: {
    type: DataTypes.STRING(80),
    allowNull: true
  },
  source_donation_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  notes: {
    type: DataTypes.TEXT,
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
  tableName: 'InstitutionEquipmentInventory',
  timestamps: false
});

module.exports = InstitutionEquipmentInventory;
