const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Institution = sequelize.define('Institution', {
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true
  },
  name: {
    type: DataTypes.STRING(100),
    allowNull: false
  },
  description: DataTypes.TEXT,
  location: DataTypes.STRING(255),
  website: DataTypes.STRING(100),
  contact_info: DataTypes.STRING(100),
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  location_lat: {
    type: DataTypes.DECIMAL(10, 8),
    allowNull: true
  },
  location_lng: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: true
  },
  location_address: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  city: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  region: {
    type: DataTypes.STRING(100),
    allowNull: true
  }

}, {
  tableName: 'Institutions',
  timestamps: false
});

module.exports = Institution;