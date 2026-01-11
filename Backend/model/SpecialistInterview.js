const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const SpecialistRegistrationRequest = require('./SpecialistRegistrationRequest');

const SpecialistInterview = sequelize.define('SpecialistInterview', {
  interview_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  request_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: SpecialistRegistrationRequest,
      key: 'request_id'
    }
  },
  interview_type: {
    type: DataTypes.ENUM('Online', 'Onsite'),
    allowNull: false
  },
  interview_date: {
    type: DataTypes.DATE,
    allowNull: false
  },
  location: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  meeting_link: {
    type: DataTypes.STRING(500),
    allowNull: true
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('Scheduled', 'Completed', 'Cancelled'),
    defaultValue: 'Scheduled'
  },
  created_by_manager_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
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
  tableName: 'SpecialistInterviews',
  timestamps: false
});

SpecialistInterview.belongsTo(SpecialistRegistrationRequest, { 
  foreignKey: 'request_id',
  as: 'registrationRequest'
});

module.exports = SpecialistInterview;