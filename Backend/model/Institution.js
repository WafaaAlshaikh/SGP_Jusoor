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
    allowNull: true,
    comment: 'Comma-separated services like: Speech Therapy, Occupational Therapy, etc.'
  },
  conditions_supported: {
    type: DataTypes.TEXT,
    allowNull: true,
    comment: 'Comma-separated conditions like: Autism, ADHD, Down Syndrome, etc.'
  },
  rating: {
    type: DataTypes.DECIMAL(3, 2),
    allowNull: true,
    defaultValue: 0.0,
    validate: {
      min: 0.0,
      max: 5.0
    }
  },
  price_range: {
    type: DataTypes.STRING(50),
    allowNull: true,
    comment: 'e.g., "50-100 JD" or "Free-500 JD"'
  },
  capacity: {
    type: DataTypes.INTEGER,
    allowNull: true,
    comment: 'Maximum number of children the institution can handle'
  },
  available_slots: {
    type: DataTypes.INTEGER,
    allowNull: true,
    comment: 'Current available slots'
  }

}, {
  tableName: 'Institutions',
  timestamps: false
});

module.exports = Institution;