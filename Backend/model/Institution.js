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
  },
  services_offered: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  conditions_supported: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  rating: {
    type: DataTypes.DECIMAL(3, 2),
    allowNull: true,
    defaultValue: 0.0
  },
  price_range: {
    type: DataTypes.STRING(50),
    allowNull: true
  },
  capacity: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  available_slots: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  approval_status: {
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected', 'Suspended'),
    defaultValue: 'Pending'
  },
  rejection_reason: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  contact_email: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  contact_phone: {
    type: DataTypes.STRING(20),
    allowNull: true
  },
  license_number: {
    type: DataTypes.STRING(50),
    allowNull: true
  },
  established_year: {
    type: DataTypes.INTEGER,
    allowNull: true
  }

}, {
  tableName: 'Institutions',
  timestamps: false
});

module.exports = Institution;