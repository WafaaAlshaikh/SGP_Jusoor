const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const EquipmentItemHistory = sequelize.define('EquipmentItemHistory', {
  history_id: {
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
  event_type: {
    type: DataTypes.STRING(60),
    allowNull: false
  },
  related_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  actor_user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  details: {
    type: DataTypes.JSON,
    allowNull: true
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'EquipmentItemHistory',
  timestamps: false
});

module.exports = EquipmentItemHistory;
