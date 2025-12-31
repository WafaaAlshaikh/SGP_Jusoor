const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const EquipmentDonationCampaign = sequelize.define('EquipmentDonationCampaign', {
  campaign_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  institution_id: {
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
  quantity_fulfilled: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0
  },
  status: {
    type: DataTypes.ENUM('open', 'partially_fulfilled', 'fulfilled', 'closed'),
    allowNull: false,
    defaultValue: 'open'
  },
  priority_score_snapshot: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0
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
  tableName: 'EquipmentDonationCampaigns',
  timestamps: false,
  indexes: [
    { fields: ['institution_id'] },
    { unique: true, fields: ['need_id'] },
    { fields: ['status'] }
  ]
});

module.exports = EquipmentDonationCampaign;
